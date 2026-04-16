import Foundation
import Testing
@testable import NangaCore

// skill-focused regression tests.
struct nangaTests {

    // both task fields are required for execution readiness.
    @Test func taskDraftRequiresTitleAndDetailForExecution() async throws {
        let emptyTask = TaskDraft(title: "   ", detail: "Build the task surface")
        let readyTask = TaskDraft(title: "Build task input", detail: "Make the current task editable in the shell")

        #expect(emptyTask.isReadyForExecution == false)
        #expect(readyTask.isReadyForExecution)
    }

    // relevance scoring should surface matching files.
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

    // matched candidates should include reasons and auto-selection.
    @Test func discoveryExplainsAndAutoSelectsHighestSignalFile() async throws {
        let rootURL = URL.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)

        try "struct Task_Input_Panel {}".write(
            to: rootURL.appending(path: "task_input_panel.swift"),
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

        let signalCandidate = try #require(candidates.first { $0.path == "task_input_panel.swift" })
        let fallbackCandidate = try #require(candidates.first { $0.path == "Notes.md" })

        #expect(signalCandidate.isSelected)
        #expect(signalCandidate.reason.contains("filename:"))
        #expect(signalCandidate.reason.contains("auto-selected: highest signal for this task"))
        #expect(fallbackCandidate.isSelected == false)
    }

    // fallback behavior should remain deterministic when tokens do not match.
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

    // optimizer should return bounded signal, scope, and prompt output.
    @Test func skillMemoryOptimizerBuildsBoundedPromptAndScope() async throws {
        let rootURL = URL.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)

        try "struct SkillMemoryOptimizer {}".write(
            to: rootURL.appending(path: "SkillMemoryOptimizer.swift"),
            atomically: true,
            encoding: .utf8
        )
        try "notes without direct relevance".write(
            to: rootURL.appending(path: "Scratch.md"),
            atomically: true,
            encoding: .utf8
        )

        let optimizer = SkillMemoryOptimizer(fileDiscoveryService: FileDiscoveryService())
        let output = try optimizer.optimize(
            SkillMemoryInput(
                task: TaskDraft(
                    title: "Improve skill memory optimizer",
                    detail: "Keep only critical context and defer weaker observations"
                ),
                rootURL: rootURL,
                previousScopeFiles: [],
                recentNotes: [
                    "carry forward only constraints that change decisions",
                    "drop repetitive status chatter"
                ],
                signalBudget: 6,
                scopeBudget: 2,
                tokenBudget: 120
            )
        )

        #expect(!output.signal.isEmpty)
        #expect(output.signal.count <= 6)
        #expect(!output.selectedScopeFiles.isEmpty)
        #expect(output.selectedScopeFiles.contains("SkillMemoryOptimizer.swift"))
        #expect(output.compactPrompt.contains("Keep:"))
        #expect(output.compactPrompt.contains("Scope:"))
        #expect(output.keep.reduce(0) { $0 + $1.estimatedTokens } <= 120)
    }

    // tight token budgets should force defer/drop decisions.
    @Test func skillMemoryOptimizerDefersWhenTokenBudgetIsTight() async throws {
        let rootURL = URL.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)

        try "struct ScopePanel {}".write(
            to: rootURL.appending(path: "ScopePanel.swift"),
            atomically: true,
            encoding: .utf8
        )

        let optimizer = SkillMemoryOptimizer(fileDiscoveryService: FileDiscoveryService())
        let output = try optimizer.optimize(
            SkillMemoryInput(
                task: TaskDraft(
                    title: "Stabilize scope panel memory",
                    detail: "Preserve hard constraints and defer low-impact observations"
                ),
                rootURL: rootURL,
                previousScopeFiles: [],
                recentNotes: [
                    "observation one",
                    "observation two",
                    "observation three"
                ],
                signalBudget: 8,
                scopeBudget: 2,
                tokenBudget: 24
            )
        )

        #expect(!output.keep.isEmpty)
        #expect(output.keep.reduce(0) { $0 + $1.estimatedTokens } <= 24)
        #expect(!output.deferred.isEmpty || !output.drop.isEmpty)
    }
}
