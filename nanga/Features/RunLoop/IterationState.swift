import Foundation

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
                "nanga/Features/RunLoop/ContentView.swift",
                "nanga/Features/RunLoop/NangaAppModel.swift"
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
            CandidateFile(path: "nanga/Features/RunLoop/ContentView.swift", reason: "The visible shell lives here.", score: 12, isSelected: true),
            CandidateFile(path: "nanga/Features/RunLoop/NangaAppModel.swift", reason: "Iteration state is defined here.", score: 11, isSelected: true)
        ]
    )

    func minimizedForPersistence() -> IterationState {
        IterationState(
            task: task.minimizedForPersistence(),
            signal: Array(signal.prefix(8)).map { $0.minimizedForPersistence() },
            scope: scope.minimizedForPersistence(),
            execution: execution.minimizedForPersistence(),
            savedState: savedState.minimizedForPersistence(),
            candidateFiles: []
        )
    }
}
