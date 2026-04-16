import Foundation

struct ExecutionPackageBuilder {
    private let maxCharactersPerFile: Int

    init(maxCharactersPerFile: Int = 4_000) {
        self.maxCharactersPerFile = maxCharactersPerFile
    }

    func build(
        project: NangaProject,
        rootURL: URL,
        selectedFiles: [String],
        carryForwardItems: [String]
    ) throws -> ExecutionPackage {
        let scopedFiles = try selectedFiles.map { relativePath in
            try buildScopedFileContext(relativePath: relativePath, rootURL: rootURL)
        }

        let signal = buildSignal(from: project.currentIteration.signal, task: project.currentIteration.task, rootPath: project.rootFolder?.path)
        let constraints = buildConstraints(rootPath: project.rootFolder?.path, selectedFiles: selectedFiles, scopedFiles: scopedFiles)

        return ExecutionPackage(
            repositoryName: project.repositoryName,
            projectRootPath: rootURL.path(percentEncoded: false),
            task: project.currentIteration.task,
            signal: signal,
            scopedFiles: scopedFiles,
            carryForwardItems: carryForwardItems,
            constraints: constraints
        )
    }

    private func buildScopedFileContext(relativePath: String, rootURL: URL) throws -> ScopedFileContext {
        let fileURL = rootURL.appending(path: relativePath)
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let trimmedContent = trimContent(content)

        return ScopedFileContext(
            path: relativePath,
            content: trimmedContent.text,
            lineCount: content.split(separator: "\n", omittingEmptySubsequences: false).count,
            wasTrimmed: trimmedContent.wasTrimmed
        )
    }

    private func buildSignal(from currentSignal: [SignalItem], task: TaskDraft, rootPath: String?) -> [ExecutionSignal] {
        if !currentSignal.isEmpty {
            return currentSignal.map { ExecutionSignal(kind: $0.kind, title: $0.title) }
        }

        var fallbackSignal: [ExecutionSignal] = [
            ExecutionSignal(kind: .taskIntent, title: task.title),
            ExecutionSignal(kind: .decision, title: task.detail)
        ]

        if let rootPath {
            fallbackSignal.append(
                ExecutionSignal(kind: .constraint, title: "Project root anchored at \(rootPath)")
            )
        }

        return fallbackSignal
    }

    private func buildConstraints(rootPath: String?, selectedFiles: [String], scopedFiles: [ScopedFileContext]) -> [String] {
        var constraints = [
            "Stay inside the active task and selected scope.",
            "Use the scoped files as the primary execution context.",
            "Ignore unrelated project surfaces unless the scope is refreshed."
        ]

        if let rootPath {
            constraints.append("Project root: \(rootPath)")
        }

        constraints.append("Scoped file count: \(selectedFiles.count)")

        if scopedFiles.contains(where: \.wasTrimmed) {
            constraints.append("Some file contexts were compacted before handoff.")
        }

        return constraints
    }

    private func trimContent(_ content: String) -> (text: String, wasTrimmed: Bool) {
        guard content.count > maxCharactersPerFile else {
            return (content, false)
        }

        let endIndex = content.index(content.startIndex, offsetBy: maxCharactersPerFile)
        let trimmed = String(content[..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        return ("\(trimmed)\n\n[truncated by Nanga for scoped handoff]", true)
    }
}
