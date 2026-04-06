import Foundation
import Observation

@Observable
@MainActor
final class NangaAppModel {
    var selectedProject: NangaProject

    init(selectedProject: NangaProject = .sample) {
        self.selectedProject = selectedProject
    }

    var currentIteration: IterationState {
        get { selectedProject.currentIteration }
        set { selectedProject.currentIteration = newValue }
    }

    var currentTaskTitle: String {
        get { currentIteration.task.title }
        set { currentIteration.task.title = newValue }
    }

    var currentTaskDetail: String {
        get { currentIteration.task.detail }
        set { currentIteration.task.detail = newValue }
    }
}

struct NangaProject: Identifiable, Equatable {
    let id: UUID
    var name: String
    var repositoryName: String
    var currentIteration: IterationState

    static let sample = NangaProject(
        id: UUID(),
        name: "Nanga",
        repositoryName: "nanga",
        currentIteration: IterationState.sample
    )
}

struct IterationState: Equatable {
    var task: TaskDraft
    var signal: [SignalItem]
    var scope: ScopeSnapshot
    var execution: ExecutionSummary
    var savedState: SavedIterationState

    var carryForwardSummary: String {
        let signalCount = signal.count
        let fileCount = scope.files.count
        return "Saving \(signalCount) signal items and \(fileCount) scoped files for the next iteration."
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
                .taskInput,
                .signalPanel,
                .scopePanel,
                .executionResult,
                .savedIterationState
            ],
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
        )
    )
}

struct TaskDraft: Equatable {
    var title: String
    var detail: String

    var isReadyForExecution: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct SignalItem: Identifiable, Equatable {
    enum Kind: String, Equatable {
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

struct ScopeSnapshot: Equatable {
    var surfaces: [ScopeSurface]
    var files: [String]
}

enum ScopeSurface: String, CaseIterable, Identifiable {
    case taskInput = "Task Input"
    case signalPanel = "Signal Panel"
    case scopePanel = "Scope Panel"
    case executionResult = "Execution Result"
    case savedIterationState = "Saved Iteration State"

    var id: String { rawValue }
}

struct ExecutionSummary: Equatable {
    enum Status: String, Equatable {
        case ready = "Ready"
        case running = "Running"
        case refreshed = "Refreshed"
    }

    var status: Status
    var headline: String
    var detail: String
}

struct SavedIterationState: Equatable {
    var summary: String
    var carriedForwardItems: [String]
}
