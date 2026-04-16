import Foundation
import Testing
@testable import nanga

struct nangaTests {

    @Test func carryForwardSummaryReflectsSignalAndScopeCounts() async throws {
        let state = IterationState(
            task: TaskDraft(title: "Task", detail: "Detail"),
            signal: [
                SignalItem(kind: .taskIntent, title: "Intent"),
                SignalItem(kind: .constraint, title: "Constraint")
            ],
            scope: ScopeSnapshot(
                surfaces: [.taskInput, .signalPanel],
                folders: ["nanga"],
                files: ["A.swift", "B.swift", "C.swift"]
            ),
            execution: ExecutionSummary(
                status: .ready,
                headline: "Ready",
                detail: "Not yet executed"
            ),
            savedState: SavedIterationState(
                summary: "Saved",
                carriedForwardItems: ["task intent"]
            ),
            candidateFiles: []
        )

        #expect(state.carryForwardSummary == "Saving 2 signal items and 3 scoped files for the next iteration.")
    }

    @Test func taskDraftRequiresTitleAndDetailForExecution() async throws {
        let emptyTask = TaskDraft(title: "   ", detail: "Build the task surface")
        let readyTask = TaskDraft(title: "Build task input", detail: "Make the current task editable in the shell")

        #expect(emptyTask.isReadyForExecution == false)
        #expect(readyTask.isReadyForExecution)
    }

    @Test func projectStoreRoundTripsProjectState() async throws {
        let baseDirectoryURL = URL.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let store = ProjectStore(baseDirectoryURL: baseDirectoryURL)

        var project = NangaProject.sample
        project.currentIteration.task.title = "Persist iteration state"
        project.currentIteration.task.detail = "Save project-backed state between launches"

        try store.saveProject(project)
        let loadedProject = try store.loadProject()

        #expect(loadedProject == project)
    }

    @MainActor
    @Test func importingProjectRootUpdatesPersistedProjectScope() async throws {
        let baseDirectoryURL = URL.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let projectURL = URL.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)

        let appModel = NangaAppModel(
            selectedProject: NangaProject(
                id: UUID(),
                name: "Nanga",
                repositoryName: "nanga",
                rootFolder: nil,
                selectedAgentRuntimeID: "codex",
                selectedAgentModelID: "",
                isAgentSelectionLocked: false,
                agentSession: nil,
                currentIteration: IterationState.sample,
                iterationHistory: []
            ),
            projectStore: ProjectStore(baseDirectoryURL: baseDirectoryURL),
            fileDiscoveryService: FileDiscoveryService(),
            executionPackageBuilder: ExecutionPackageBuilder(),
            agentRuntimeRegistry: AgentRuntimeRegistry(runtimes: [SuccessRuntime()])
        )

        appModel.importProjectRoot(from: projectURL)

        let persistedProject = try ProjectStore(baseDirectoryURL: baseDirectoryURL).loadProject()

        #expect(persistedProject.rootFolder?.path == projectURL.path(percentEncoded: false))
        #expect(persistedProject.currentIteration.scope.folders.contains(projectURL.path(percentEncoded: false)))
    }

    @Test func discoveryFindsTaskRelevantFiles() async throws {
        let rootURL = URL.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)

        try "struct ContentView {}".write(
            to: rootURL.appending(path: "ContentView.swift"),
            atomically: true,
            encoding: .utf8
        )
        try "final class ProjectStore {}".write(
            to: rootURL.appending(path: "ProjectStore.swift"),
            atomically: true,
            encoding: .utf8
        )

        let service = FileDiscoveryService()
        let candidates = try service.discoverCandidates(
            in: rootURL,
            task: TaskDraft(title: "Update content view", detail: "Modernize the main view"),
            previousSelections: []
        )

        #expect(candidates.contains { $0.path == "ContentView.swift" })
    }

    @Test func discoveryExplainsAndAutoSelectsHighestSignalFile() async throws {
        let rootURL = URL.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)

        try "struct TaskInputPanel {}".write(
            to: rootURL.appending(path: "TaskInputPanel.swift"),
            atomically: true,
            encoding: .utf8
        )
        try "Project notes without matching keywords".write(
            to: rootURL.appending(path: "Notes.md"),
            atomically: true,
            encoding: .utf8
        )

        let service = FileDiscoveryService()
        let candidates = try service.discoverCandidates(
            in: rootURL,
            task: TaskDraft(title: "Improve task input panel", detail: "Tighten input scope behavior"),
            previousSelections: []
        )

        let signalCandidate = try #require(candidates.first { $0.path == "TaskInputPanel.swift" })
        let fallbackCandidate = try #require(candidates.first { $0.path == "Notes.md" })

        #expect(signalCandidate.isSelected)
        #expect(signalCandidate.reason.contains("filename:"))
        #expect(signalCandidate.reason.contains("auto-selected: highest signal for this task"))
        #expect(fallbackCandidate.isSelected == false)
    }

    @Test func discoveryUsesDeterministicFallbackWhenNoTermsMatch() async throws {
        let rootURL = URL.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)

        try "struct Alpha {}".write(
            to: rootURL.appending(path: "Alpha.swift"),
            atomically: true,
            encoding: .utf8
        )
        try "struct Beta {}".write(
            to: rootURL.appending(path: "Beta.swift"),
            atomically: true,
            encoding: .utf8
        )

        let service = FileDiscoveryService()
        let candidates = try service.discoverCandidates(
            in: rootURL,
            task: TaskDraft(title: "quuxxyzz", detail: "plmoknijb"),
            previousSelections: []
        )

        #expect(!candidates.isEmpty)

        let selectedFallbacks = candidates.filter(\.isSelected)
        #expect(!selectedFallbacks.isEmpty)
        #expect(selectedFallbacks.allSatisfy { $0.reason.contains("auto-selected fallback") })
        #expect(selectedFallbacks.allSatisfy { $0.reason.contains("Fallback candidate from the approved folder") })
    }

    @MainActor
    @Test func runIterationRefreshesStateAndSavesHistory() async throws {
        let baseDirectoryURL = URL.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let rootURL = URL.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: rootURL.appending(path: "nanga", directoryHint: .isDirectory),
            withIntermediateDirectories: true
        )

        try "import SwiftUI\nstruct ContentView {}"
            .write(to: rootURL.appending(path: "nanga/ContentView.swift"), atomically: true, encoding: .utf8)
        try "import Foundation\nstruct ProjectStore {}"
            .write(to: rootURL.appending(path: "nanga/ProjectStore.swift"), atomically: true, encoding: .utf8)

        let appModel = NangaAppModel(
            selectedProject: makeProject(
                rootURL: rootURL,
                runtimeID: SuccessRuntime().id,
                candidateFiles: [
                    CandidateFile(path: "nanga/ContentView.swift", reason: "Relevant", score: 12, isSelected: true),
                    CandidateFile(path: "nanga/ProjectStore.swift", reason: "Not selected", score: 8, isSelected: false)
                ]
            ),
            projectStore: ProjectStore(baseDirectoryURL: baseDirectoryURL),
            fileDiscoveryService: FileDiscoveryService(),
            executionPackageBuilder: ExecutionPackageBuilder(),
            agentRuntimeRegistry: AgentRuntimeRegistry(runtimes: [SuccessRuntime()])
        )

        await appModel.runIteration()

        let iteration = appModel.currentIteration
        let history = appModel.iterationHistory

        #expect(iteration.execution.status == .refreshed)
        #expect(iteration.scope.files == ["nanga/ContentView.swift"])
        #expect(!iteration.savedState.carriedForwardItems.isEmpty)
        #expect(history.count == 1)
        #expect(appModel.selectedAgentSessionID == "test-thread")
    }

    @Test func agentConnectionBlocksExecutionWhenLoginIsRequired() async throws {
        let connection = AgentConnection(
            runtimeID: "codex",
            runtimeName: "Codex",
            status: .available,
            isCLIInstalled: true,
            authenticationStatus: .loginRequired,
            workspaceMarkers: [],
            detail: "Login required.",
            models: []
        )

        #expect(connection.canExecute == false)
    }

    @MainActor
    @Test func runIterationCapturesLastRuntimeError() async throws {
        let baseDirectoryURL = URL.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let rootURL = URL.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: rootURL.appending(path: "nanga", directoryHint: .isDirectory),
            withIntermediateDirectories: true
        )
        try "struct ContentView {}"
            .write(to: rootURL.appending(path: "nanga/ContentView.swift"), atomically: true, encoding: .utf8)

        let appModel = NangaAppModel(
            selectedProject: makeProject(
                rootURL: rootURL,
                runtimeID: FailureRuntime().id,
                candidateFiles: [
                    CandidateFile(path: "nanga/ContentView.swift", reason: "Relevant", score: 12, isSelected: true)
                ]
            ),
            projectStore: ProjectStore(baseDirectoryURL: baseDirectoryURL),
            fileDiscoveryService: FileDiscoveryService(),
            executionPackageBuilder: ExecutionPackageBuilder(),
            agentRuntimeRegistry: AgentRuntimeRegistry(runtimes: [FailureRuntime()])
        )

        await appModel.runIteration()

        #expect(appModel.currentIteration.execution.status == .failed)
        #expect(appModel.lastRuntimeError == "simulated runtime failure")
    }
}

private enum TestRuntimeFailure: LocalizedError {
    case simulatedFailure

    var errorDescription: String? {
        switch self {
        case .simulatedFailure:
            "simulated runtime failure"
        }
    }
}

private struct SuccessRuntime: AgentRuntime {
    let id = "test-runtime"
    let displayName = "Test Runtime"
    let models = [AgentModel(id: "test-model", displayName: "Test Model")]

    func detectConnection(at rootURL: URL?) -> AgentConnection {
        AgentConnection(
            runtimeID: id,
            runtimeName: displayName,
            status: .available,
            isCLIInstalled: true,
            authenticationStatus: .notRequired,
            workspaceMarkers: [],
            detail: "Test runtime available.",
            models: models
        )
    }

    func connect(
        in rootURL: URL,
        model: AgentModel?,
        eventHandler: @escaping @Sendable (AgentRuntimeEvent) -> Void
    ) async throws -> AgentSession? {
        AgentSession(runtimeID: id, threadID: "test-thread")
    }

    func execute(
        _ package: ExecutionPackage,
        sessionID: String?,
        in rootURL: URL,
        model: AgentModel?,
        eventHandler: @escaping @Sendable (AgentRuntimeEvent) -> Void
    ) async throws -> ExecutionResult {
        ExecutionResult(
            headline: "\(displayName) execution complete",
            detail: "Executed \(package.fileCount) scoped files.",
            refreshedSignal: package.signal.map { signal in
                SignalItem(kind: signal.kind, title: signal.title)
            },
            carriedForwardItems: package.carryForwardItems,
            sessionID: sessionID ?? "test-thread"
        )
    }
}

private struct FailureRuntime: AgentRuntime {
    let id = "failing-runtime"
    let displayName = "Failing Runtime"
    let models = [AgentModel(id: "test-model", displayName: "Test Model")]

    func detectConnection(at rootURL: URL?) -> AgentConnection {
        AgentConnection(
            runtimeID: id,
            runtimeName: displayName,
            status: .available,
            isCLIInstalled: true,
            authenticationStatus: .notRequired,
            workspaceMarkers: [],
            detail: "Failing runtime available.",
            models: models
        )
    }

    func execute(
        _ package: ExecutionPackage,
        sessionID: String?,
        in rootURL: URL,
        model: AgentModel?,
        eventHandler: @escaping @Sendable (AgentRuntimeEvent) -> Void
    ) async throws -> ExecutionResult {
        throw TestRuntimeFailure.simulatedFailure
    }
}

private func makeProject(rootURL: URL, runtimeID: String, candidateFiles: [CandidateFile]) -> NangaProject {
    NangaProject(
        id: UUID(),
        name: "Nanga",
        repositoryName: "nanga",
        rootFolder: ProjectFolderReference(path: rootURL.path(percentEncoded: false), bookmarkData: nil),
        selectedAgentRuntimeID: runtimeID,
        selectedAgentModelID: "",
        isAgentSelectionLocked: true,
        agentSession: nil,
        currentIteration: IterationState(
            task: TaskDraft(title: "Refresh signal", detail: "Run the current iteration"),
            signal: [],
            scope: ScopeSnapshot(
                surfaces: [.projectRoot, .taskInput, .scopePanel],
                folders: [rootURL.path(percentEncoded: false)],
                files: []
            ),
            execution: ExecutionSummary(
                status: .ready,
                headline: "Ready",
                detail: "Waiting to run"
            ),
            savedState: SavedIterationState(
                summary: "Saved",
                carriedForwardItems: []
            ),
            candidateFiles: candidateFiles
        ),
        iterationHistory: []
    )
}
