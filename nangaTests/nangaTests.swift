//
//  nangaTests.swift
//  nangaTests
//
//  Created by Nawal 🫧💗🛼 on 06/04/2026.
//

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

    @Test func importingProjectRootUpdatesPersistedProjectScope() async throws {
        let baseDirectoryURL = URL.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let projectURL = URL.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)

        let appModel = await MainActor.run {
            NangaAppModel(
                selectedProject: NangaProject(
                    id: UUID(),
                    name: "Nanga",
                    repositoryName: "nanga",
                    rootFolder: nil,
                    currentIteration: IterationState.sample,
                    iterationHistory: []
                ),
                projectStore: ProjectStore(baseDirectoryURL: baseDirectoryURL)
            )
        }

        await MainActor.run {
            appModel.importProjectRoot(from: projectURL)
        }

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

    @Test func runIterationRefreshesStateAndSavesHistory() async throws {
        let baseDirectoryURL = URL.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let appModel = await MainActor.run {
            NangaAppModel(
                selectedProject: NangaProject(
                    id: UUID(),
                    name: "Nanga",
                    repositoryName: "nanga",
                    rootFolder: ProjectFolderReference(path: "/tmp/nanga", bookmarkData: nil),
                    currentIteration: IterationState(
                        task: TaskDraft(title: "Refresh signal", detail: "Run the current iteration"),
                        signal: [],
                        scope: ScopeSnapshot(
                            surfaces: [.projectRoot, .taskInput, .scopePanel],
                            folders: ["/tmp/nanga"],
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
                        candidateFiles: [
                            CandidateFile(path: "nanga/ContentView.swift", reason: "Relevant", score: 12, isSelected: true),
                            CandidateFile(path: "nanga/ProjectStore.swift", reason: "Not selected", score: 8, isSelected: false)
                        ]
                    ),
                    iterationHistory: []
                ),
                projectStore: ProjectStore(baseDirectoryURL: baseDirectoryURL)
            )
        }

        await MainActor.run {
            appModel.runIteration()
        }

        let iteration = await MainActor.run { appModel.currentIteration }
        let history = await MainActor.run { appModel.iterationHistory }

        #expect(iteration.execution.status == .refreshed)
        #expect(iteration.scope.files == ["nanga/ContentView.swift"])
        #expect(!iteration.savedState.carriedForwardItems.isEmpty)
        #expect(history.count == 1)
    }
}
