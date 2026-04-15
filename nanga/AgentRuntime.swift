import Foundation

protocol AgentRuntime {
    func execute(_ package: ExecutionPackage) async throws -> ExecutionResult
}

struct MockAgentRuntime: AgentRuntime {
    func execute(_ package: ExecutionPackage) async throws -> ExecutionResult {
        let scopedPaths = package.scopedFiles.map(\.path)
        let trimmedCount = package.scopedFiles.filter(\.wasTrimmed).count

        var refreshedSignal = package.signal.map { signal in
            SignalItem(kind: signal.kind, title: signal.title)
        }

        refreshedSignal.append(
            SignalItem(
                kind: .decision,
                title: "Prepared a bounded execution package for \(package.fileCount) scoped files."
            )
        )

        if let firstFile = scopedPaths.first {
            refreshedSignal.append(
                SignalItem(
                    kind: .changedArtifact,
                    title: "Primary scoped file handed to the runtime: \(firstFile)"
                )
            )
        }

        if trimmedCount > 0 {
            refreshedSignal.append(
                SignalItem(
                    kind: .constraint,
                    title: "Compacted \(trimmedCount) large file contexts before runtime handoff."
                )
            )
        }

        return ExecutionResult(
            headline: "Execution package ready for agent handoff",
            detail: "Mock runtime received \(package.fileCount) scoped files for '\(package.task.title)'.",
            refreshedSignal: refreshedSignal,
            carriedForwardItems: package.carryForwardItems
        )
    }
}
