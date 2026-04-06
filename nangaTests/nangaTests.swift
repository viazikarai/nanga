//
//  nangaTests.swift
//  nangaTests
//
//  Created by Nawal 🫧💗🛼 on 06/04/2026.
//

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
            )
        )

        #expect(state.carryForwardSummary == "Saving 2 signal items and 3 scoped files for the next iteration.")
    }

}
