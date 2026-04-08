import Foundation
import Observation

@Observable
@MainActor
final class NangaAppModel {
    @ObservationIgnored private let projectStore: ProjectStore
    @ObservationIgnored private var activeProjectRootURL: URL?
    @ObservationIgnored private let fileDiscoveryService: FileDiscoveryService

    var selectedProject: NangaProject
    var persistenceStatus: String

    init(
        selectedProject: NangaProject? = nil,
        projectStore: ProjectStore = ProjectStore(),
        fileDiscoveryService: FileDiscoveryService = FileDiscoveryService()
    ) {
        self.projectStore = projectStore
        self.fileDiscoveryService = fileDiscoveryService

        if let selectedProject {
            self.selectedProject = selectedProject
            self.persistenceStatus = "Loaded project from injected state."
            restoreProjectRootAccess()
            persistProject()
            return
        }

        if let persistedProject = try? projectStore.loadProject() {
            self.selectedProject = persistedProject
            self.persistenceStatus = "Loaded saved iteration state from disk."
            restoreProjectRootAccess()
        } else {
            self.selectedProject = .sample
            self.persistenceStatus = "Started with a sample project until a saved project exists."
            persistProject()
        }
    }

    var currentIteration: IterationState {
        get { selectedProject.currentIteration }
        set {
            selectedProject.currentIteration = newValue
            syncScopeFromSelections()
            persistProject()
        }
    }

    var currentTaskTitle: String {
        get { currentIteration.task.title }
        set {
            selectedProject.currentIteration.task.title = newValue
            persistProject(statusMessage: "Updated current task title.")
        }
    }

    var currentTaskDetail: String {
        get { currentIteration.task.detail }
        set {
            selectedProject.currentIteration.task.detail = newValue
            persistProject(statusMessage: "Updated current task detail.")
        }
    }

    var projectFilePath: String {
        projectStore.projectFileURL.path(percentEncoded: false)
    }

    var projectRootPath: String {
        selectedProject.rootFolder?.path ?? "No folder selected"
    }

    var hasProjectRoot: Bool {
        selectedProject.rootFolder != nil
    }

    var iterationHistory: [IterationRecord] {
        selectedProject.iterationHistory.sorted { $0.savedAt > $1.savedAt }
    }

    var selectedFileCount: Int {
        currentIteration.candidateFiles.filter(\.isSelected).count
    }

    var canDiscoverCandidateFiles: Bool {
        hasProjectRoot && currentIteration.task.isReadyForExecution
    }

    var canRunIteration: Bool {
        canDiscoverCandidateFiles && selectedFileCount > 0
    }

    func saveIterationCheckpoint() {
        guard currentIteration.task.isReadyForExecution else {
            persistenceStatus = "Checkpoint requires a task title and execution detail."
            return
        }

        let record = IterationRecord(
            label: currentIteration.task.title,
            savedAt: .now,
            snapshot: currentIteration.snapshot
        )

        selectedProject.iterationHistory.insert(record, at: 0)
        selectedProject.iterationHistory = Array(selectedProject.iterationHistory.prefix(20))
        persistProject(statusMessage: "Saved iteration checkpoint to history.")
    }

    func importProjectRoot(from url: URL) {
        stopAccessingCurrentProjectRootIfNeeded()

        let folderReference = ProjectFolderReference.make(from: url)
        selectedProject.rootFolder = folderReference
        selectedProject.name = url.lastPathComponent
        selectedProject.repositoryName = url.lastPathComponent

        if !selectedProject.currentIteration.scope.folders.contains(folderReference.path) {
            selectedProject.currentIteration.scope.folders.insert(folderReference.path, at: 0)
        }

        let bookmarkMessage = folderReference.bookmarkData == nil
            ? " Folder path saved without a security-scoped bookmark."
            : ""

        activeProjectRootURL = folderReference.resolvedURL
        _ = activeProjectRootURL?.startAccessingSecurityScopedResource()
        persistProject(statusMessage: "Opened project folder and saved it into project state.\(bookmarkMessage)")
    }

    func discoverCandidateFiles() {
        guard canDiscoverCandidateFiles else {
            persistenceStatus = "Open a project folder and complete the task before discovering files."
            return
        }

        guard let rootURL = activeProjectRootURL ?? selectedProject.rootFolder?.resolvedURL else {
            persistenceStatus = "Project root could not be resolved."
            return
        }

        do {
            let candidates = try fileDiscoveryService.discoverCandidates(
                in: rootURL,
                task: currentIteration.task,
                previousSelections: currentIteration.scope.files
            )

            selectedProject.currentIteration.candidateFiles = candidates
            syncScopeFromSelections()
            refreshSignalFromCurrentState(
                headline: "Candidate files discovered",
                detail: "Nanga proposed files based on the task and project root."
            )
            persistProject(statusMessage: "Discovered candidate files from the project root.")
        } catch {
            persistenceStatus = "Failed to discover files: \(error.localizedDescription)"
        }
    }

    func setCandidateFileSelection(id: UUID, isSelected: Bool) {
        guard let index = selectedProject.currentIteration.candidateFiles.firstIndex(where: { $0.id == id }) else {
            return
        }

        selectedProject.currentIteration.candidateFiles[index].isSelected = isSelected
        syncScopeFromSelections()
        refreshSignalFromCurrentState(
            headline: "Scope adjusted",
            detail: "Selected files were updated for the current iteration."
        )
        persistProject(statusMessage: "Updated selected files in scope.")
    }

    func runIteration() {
        guard canRunIteration else {
            persistenceStatus = "Run requires a project root, a complete task, and at least one selected file."
            return
        }

        selectedProject.currentIteration.execution = ExecutionSummary(
            status: .running,
            headline: "Running scoped iteration",
            detail: "Preparing task, selected signal, and scoped files for execution."
        )

        let selectedFiles = selectedProject.currentIteration.scope.files
        let resultDetail = "Prepared \(selectedFiles.count) files for the task '\(selectedProject.currentIteration.task.title)'."
        refreshSignalFromCurrentState(
            headline: "Execution package refreshed",
            detail: resultDetail
        )

        selectedProject.currentIteration.savedState = SavedIterationState(
            summary: "Saved a refreshed iteration frame ready for the next loop.",
            carriedForwardItems: buildCarryForwardItems()
        )
        selectedProject.currentIteration.execution = ExecutionSummary(
            status: .refreshed,
            headline: "Iteration refreshed",
            detail: "Nanga refreshed signal and saved the next iteration state from the current scoped frame."
        )
        saveIterationCheckpoint()
        persistProject(statusMessage: "Ran the iteration loop and saved the next iteration state.")
    }

    private func buildCarryForwardItems() -> [String] {
        var items = ["task intent", "selected signal", "scoped files"]

        if hasProjectRoot {
            items.append("project root")
        }

        if let first = currentIteration.scope.files.first {
            items.append(first)
        }

        return Array(NSOrderedSet(array: items)) as? [String] ?? items
    }

    private func refreshSignalFromCurrentState(headline: String, detail: String) {
        var refreshedSignal: [SignalItem] = [
            SignalItem(kind: .taskIntent, title: currentIteration.task.title),
            SignalItem(kind: .decision, title: currentIteration.task.detail)
        ]

        if let root = selectedProject.rootFolder?.path {
            refreshedSignal.append(SignalItem(kind: .constraint, title: "Project root anchored at \(root)"))
        }

        for file in selectedProject.currentIteration.scope.files.prefix(3) {
            refreshedSignal.append(SignalItem(kind: .relevantFile, title: file))
        }

        if let firstUnselected = selectedProject.currentIteration.candidateFiles.first(where: { !$0.isSelected }) {
            refreshedSignal.append(SignalItem(kind: .unfinishedWork, title: "Candidate file left out of scope: \(firstUnselected.path)"))
        }

        selectedProject.currentIteration.signal = refreshedSignal
        selectedProject.currentIteration.execution = ExecutionSummary(
            status: .refreshed,
            headline: headline,
            detail: detail
        )
    }

    private func syncScopeFromSelections() {
        selectedProject.currentIteration.scope.files = selectedProject.currentIteration.candidateFiles
            .filter(\.isSelected)
            .map(\.path)
    }

    private func persistProject(statusMessage: String = "Saved project state to disk.") {
        do {
            try projectStore.saveProject(selectedProject)
            persistenceStatus = statusMessage
        } catch {
            persistenceStatus = "Failed to save project state: \(error.localizedDescription)"
        }
    }

    private func restoreProjectRootAccess() {
        guard let rootFolder = selectedProject.rootFolder else { return }

        let resolution = rootFolder.resolveBookmark()
        if let url = resolution.url {
            activeProjectRootURL = url
            _ = url.startAccessingSecurityScopedResource()

            if resolution.didRefreshBookmark {
                let refreshedReference = ProjectFolderReference.make(from: url)
                selectedProject.rootFolder = refreshedReference
                persistProject(statusMessage: "Refreshed saved project folder access.")
            }
        }
    }

    private func stopAccessingCurrentProjectRootIfNeeded() {
        activeProjectRootURL?.stopAccessingSecurityScopedResource()
        activeProjectRootURL = nil
    }

    deinit {
        activeProjectRootURL?.stopAccessingSecurityScopedResource()
    }
}

struct NangaProject: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var repositoryName: String
    var rootFolder: ProjectFolderReference?
    var currentIteration: IterationState
    var iterationHistory: [IterationRecord]

    static let sample = NangaProject(
        id: UUID(),
        name: "Nanga",
        repositoryName: "nanga",
        rootFolder: nil,
        currentIteration: IterationState.sample,
        iterationHistory: [
            IterationRecord(
                label: "Define the first Nanga shell",
                savedAt: .now.addingTimeInterval(-3_600),
                snapshot: IterationSnapshot(
                    task: TaskDraft(
                        title: "Define the first Nanga shell",
                        detail: "Establish task, signal, scope, result, and saved-state surfaces."
                    ),
                    signal: [
                        SignalItem(kind: .taskIntent, title: "Iteration loop is the core unit"),
                        SignalItem(kind: .constraint, title: "Must feel frictionless for developers")
                    ],
                    scope: ScopeSnapshot(
                        surfaces: [.projectRoot, .taskInput, .signalPanel, .scopePanel, .savedIterationState, .iterationHistory],
                        folders: ["nanga"],
                        files: ["nanga/ContentView.swift", "nanga/NangaAppModel.swift"]
                    ),
                    execution: ExecutionSummary(
                        status: .refreshed,
                        headline: "Shell established",
                        detail: "The app now reflects the core iteration frame."
                    ),
                    savedState: SavedIterationState(
                        summary: "Saved the first product-shaped iteration frame.",
                        carriedForwardItems: ["task intent", "signal scaffolding", "scope surfaces"]
                    ),
                    candidateFiles: [
                        CandidateFile(path: "nanga/ContentView.swift", reason: "Task and UI shell are aligned here.", score: 18, isSelected: true),
                        CandidateFile(path: "nanga/NangaAppModel.swift", reason: "Iteration state lives here.", score: 15, isSelected: true)
                    ]
                )
            )
        ]
    )
}

struct IterationState: Equatable, Codable {
    var task: TaskDraft
    var signal: [SignalItem]
    var scope: ScopeSnapshot
    var execution: ExecutionSummary
    var savedState: SavedIterationState
    var candidateFiles: [CandidateFile]

    var carryForwardSummary: String {
        let signalCount = signal.count
        let fileCount = scope.files.count
        return "Saving \(signalCount) signal items and \(fileCount) scoped files for the next iteration."
    }

    var snapshot: IterationSnapshot {
        IterationSnapshot(
            task: task,
            signal: signal,
            scope: scope,
            execution: execution,
            savedState: savedState,
            candidateFiles: candidateFiles
        )
    }

    static let sample = IterationState(
        task: TaskDraft(
            title: "Build the first iteration shell",
            detail: "Show the current task, selected signal, active scope, execution result, and saved next-iteration state."
        ),
        signal: [
            SignalItem(kind: .taskIntent, title: "Iteration loop is the primary product unit"),
            SignalItem(kind: .relevantFile, title: "Current UI is still the default SwiftUI template"),
            SignalItem(kind: .constraint, title: "The app must feel frictionless for developers"),
            SignalItem(kind: .unfinishedWork, title: "Need a shell organized around iteration state, not generic chat")
        ],
        scope: ScopeSnapshot(
            surfaces: [
                .projectRoot,
                .taskInput,
                .signalPanel,
                .scopePanel,
                .executionResult,
                .savedIterationState
            ],
            folders: [],
            files: [
                "nanga/nangaApp.swift",
                "nanga/ContentView.swift",
                "nanga/NangaAppModel.swift"
            ]
        ),
        execution: ExecutionSummary(
            status: .ready,
            headline: "No agent run yet",
            detail: "The app can already show the working frame before execution."
        ),
        savedState: SavedIterationState(
            summary: "Project remembers the current task frame and the scoped context selected for the next step.",
            carriedForwardItems: [
                "task intent",
                "selected signal",
                "scoped files",
                "active constraints"
            ]
        ),
        candidateFiles: [
            CandidateFile(path: "nanga/ContentView.swift", reason: "The visible shell lives here.", score: 12, isSelected: true),
            CandidateFile(path: "nanga/NangaAppModel.swift", reason: "Iteration state is defined here.", score: 11, isSelected: true)
        ]
    )
}

struct TaskDraft: Equatable, Codable {
    var title: String
    var detail: String

    var isReadyForExecution: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct SignalItem: Identifiable, Equatable, Codable {
    enum Kind: String, Equatable, Codable {
        case taskIntent = "Task Intent"
        case relevantFile = "Relevant File"
        case constraint = "Constraint"
        case unfinishedWork = "Unfinished Work"
        case changedArtifact = "Changed Artifact"
        case decision = "Decision"
    }

    let id: UUID
    var kind: Kind
    var title: String

    init(id: UUID = UUID(), kind: Kind, title: String) {
        self.id = id
        self.kind = kind
        self.title = title
    }
}

struct CandidateFile: Identifiable, Equatable, Codable {
    let id: UUID
    var path: String
    var reason: String
    var score: Int
    var isSelected: Bool

    init(
        id: UUID = UUID(),
        path: String,
        reason: String,
        score: Int,
        isSelected: Bool
    ) {
        self.id = id
        self.path = path
        self.reason = reason
        self.score = score
        self.isSelected = isSelected
    }
}

struct ScopeSnapshot: Equatable, Codable {
    var surfaces: [ScopeSurface]
    var folders: [String]
    var files: [String]
}

enum ScopeSurface: String, CaseIterable, Identifiable, Codable {
    case projectRoot = "Project Root"
    case taskInput = "Task Input"
    case signalPanel = "Signal Panel"
    case scopePanel = "Scope Panel"
    case executionResult = "Execution Result"
    case savedIterationState = "Saved Iteration State"
    case iterationHistory = "Iteration History"

    var id: String { rawValue }
}

struct ExecutionSummary: Equatable, Codable {
    enum Status: String, Equatable, Codable {
        case ready = "Ready"
        case running = "Running"
        case refreshed = "Refreshed"
    }

    var status: Status
    var headline: String
    var detail: String
}

struct SavedIterationState: Equatable, Codable {
    var summary: String
    var carriedForwardItems: [String]
}

struct ProjectFolderReference: Equatable, Codable {
    var path: String
    var bookmarkData: Data?

    var resolvedURL: URL {
        URL(filePath: path)
    }

    static func make(from url: URL) -> ProjectFolderReference {
        let bookmarkData = try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        return ProjectFolderReference(
            path: url.path(percentEncoded: false),
            bookmarkData: bookmarkData
        )
    }

    func resolveBookmark() -> BookmarkResolution {
        guard let bookmarkData else {
            return BookmarkResolution(url: resolvedURL, didRefreshBookmark: false)
        }

        var isStale = false
        let url = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        return BookmarkResolution(url: url ?? resolvedURL, didRefreshBookmark: isStale)
    }
}

struct BookmarkResolution {
    var url: URL?
    var didRefreshBookmark: Bool
}

struct IterationRecord: Identifiable, Equatable, Codable {
    let id: UUID
    var label: String
    var savedAt: Date
    var snapshot: IterationSnapshot

    init(
        id: UUID = UUID(),
        label: String,
        savedAt: Date,
        snapshot: IterationSnapshot
    ) {
        self.id = id
        self.label = label
        self.savedAt = savedAt
        self.snapshot = snapshot
    }
}

struct IterationSnapshot: Equatable, Codable {
    var task: TaskDraft
    var signal: [SignalItem]
    var scope: ScopeSnapshot
    var execution: ExecutionSummary
    var savedState: SavedIterationState
    var candidateFiles: [CandidateFile]
}
