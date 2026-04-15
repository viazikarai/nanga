import Foundation

struct AgentModel: Identifiable, Equatable {
    let id: String
    var displayName: String
}

enum AgentConnectionStatus: Equatable {
    case connected
    case available
    case unavailable

    var label: String {
        switch self {
        case .connected: "Connected"
        case .available: "Available"
        case .unavailable: "Unavailable"
        }
    }
}

struct AgentConnection: Identifiable, Equatable {
    var id: String { runtimeID }
    var runtimeID: String
    var runtimeName: String
    var status: AgentConnectionStatus
    var detail: String
    var models: [AgentModel]

    var canExecute: Bool {
        status != .unavailable
    }
}

protocol AgentRuntime {
    var id: String { get }
    var displayName: String { get }
    var models: [AgentModel] { get }

    func detectConnection(at rootURL: URL?) -> AgentConnection
    func execute(_ package: ExecutionPackage, in rootURL: URL, model: AgentModel?) async throws -> ExecutionResult
}

struct AgentRuntimeRegistry {
    let runtimes: [any AgentRuntime]

    init(runtimes: [any AgentRuntime] = [CodexRuntime(), ClaudeCodeRuntime(), CursorRuntime()]) {
        self.runtimes = runtimes
    }

    func detectConnections(at rootURL: URL?) -> [AgentConnection] {
        runtimes.map { $0.detectConnection(at: rootURL) }
    }

    func runtime(for id: String) -> (any AgentRuntime)? {
        runtimes.first { $0.id == id }
    }
}

struct CodexRuntime: AgentRuntime {
    let id = "codex"
    let displayName = "Codex"
    let models = [
        AgentModel(id: "gpt-5-codex", displayName: "GPT-5 Codex"),
        AgentModel(id: "gpt-5.4", displayName: "GPT-5.4")
    ]

    func detectConnection(at rootURL: URL?) -> AgentConnection {
        guard CLIWorkspaceDetector.commandExists("codex") else {
            return AgentConnection(
                runtimeID: id,
                runtimeName: displayName,
                status: .unavailable,
                detail: "Codex CLI was not found on this machine.",
                models: models
            )
        }

        guard CLIWorkspaceDetector.codexIsLoggedIn() else {
            return AgentConnection(
                runtimeID: id,
                runtimeName: displayName,
                status: .available,
                detail: "Codex CLI is installed, but login is required before Nanga can execute against the project.",
                models: models
            )
        }

        guard let rootURL else {
            return AgentConnection(
                runtimeID: id,
                runtimeName: displayName,
                status: .available,
                detail: "Codex is authenticated. Open a project folder to attach it.",
                models: models
            )
        }

        let markers = CLIWorkspaceDetector.detectWorkspaceMarkers(
            at: rootURL,
            workspaceMarkers: [".codex", "AGENTS.md", ".git"]
        )

        let detail = markers.isEmpty
            ? "Codex is authenticated and ready for this folder."
            : "Codex is authenticated. Workspace markers: \(markers.joined(separator: ", "))"

        return AgentConnection(
            runtimeID: id,
            runtimeName: displayName,
            status: .connected,
            detail: detail,
            models: models
        )
    }

    func execute(_ package: ExecutionPackage, in rootURL: URL, model: AgentModel?) async throws -> ExecutionResult {
        try await CodexCLIExecutor.execute(
            package,
            runtimeName: displayName,
            model: model,
            rootURL: rootURL
        )
    }
}

struct ClaudeCodeRuntime: AgentRuntime {
    let id = "claude-code"
    let displayName = "Claude Code"
    let models = [
        AgentModel(id: "sonnet", displayName: "Sonnet"),
        AgentModel(id: "opus", displayName: "Opus")
    ]

    func detectConnection(at rootURL: URL?) -> AgentConnection {
        CLIWorkspaceDetector.connection(
            runtimeID: id,
            runtimeName: displayName,
            command: "claude",
            rootURL: rootURL,
            workspaceMarkers: [".claude", "AGENTS.md", ".git"],
            models: models
        )
    }

    func execute(_ package: ExecutionPackage, in rootURL: URL, model: AgentModel?) async throws -> ExecutionResult {
        MockRuntimeExecutor.execute(
            package,
            runtimeName: displayName,
            modelName: model?.displayName
        )
    }
}

struct CursorRuntime: AgentRuntime {
    let id = "cursor"
    let displayName = "Cursor"
    let models = [
        AgentModel(id: "cursor-auto", displayName: "Auto"),
        AgentModel(id: "cursor-sonnet", displayName: "Sonnet")
    ]

    func detectConnection(at rootURL: URL?) -> AgentConnection {
        CLIWorkspaceDetector.connection(
            runtimeID: id,
            runtimeName: displayName,
            command: "cursor",
            rootURL: rootURL,
            workspaceMarkers: [".cursor", ".vscode", ".git"],
            models: models
        )
    }

    func execute(_ package: ExecutionPackage, in rootURL: URL, model: AgentModel?) async throws -> ExecutionResult {
        MockRuntimeExecutor.execute(
            package,
            runtimeName: displayName,
            modelName: model?.displayName
        )
    }
}

private enum CLIWorkspaceDetector {
    static func connection(
        runtimeID: String,
        runtimeName: String,
        command: String,
        rootURL: URL?,
        workspaceMarkers: [String],
        models: [AgentModel]
    ) -> AgentConnection {
        guard commandExists(command) else {
            return AgentConnection(
                runtimeID: runtimeID,
                runtimeName: runtimeName,
                status: .unavailable,
                detail: "\(runtimeName) CLI was not found on this machine.",
                models: models
            )
        }

        guard let rootURL else {
            return AgentConnection(
                runtimeID: runtimeID,
                runtimeName: runtimeName,
                status: .available,
                detail: "\(runtimeName) is installed. Open a project to attach it.",
                models: models
            )
        }

        let fileManager = FileManager.default
        let markers = detectWorkspaceMarkers(at: rootURL, workspaceMarkers: workspaceMarkers)

        if markers.isEmpty {
            return AgentConnection(
                runtimeID: runtimeID,
                runtimeName: runtimeName,
                status: .available,
                detail: "\(runtimeName) is installed. No explicit workspace marker was detected in this folder.",
                models: models
            )
        }

        return AgentConnection(
            runtimeID: runtimeID,
            runtimeName: runtimeName,
            status: .connected,
            detail: "Detected workspace markers: \(markers.joined(separator: ", "))",
            models: models
        )
    }

    static func commandExists(_ command: String) -> Bool {
        commandOutput(arguments: ["which", command]) != nil
    }

    static func codexIsLoggedIn() -> Bool {
        guard let output = commandOutput(arguments: ["codex", "login", "status"]) else {
            return false
        }

        return output.localizedCaseInsensitiveContains("logged in")
    }

    static func detectWorkspaceMarkers(at rootURL: URL, workspaceMarkers: [String]) -> [String] {
        let fileManager = FileManager.default
        return workspaceMarkers.filter { marker in
            fileManager.fileExists(atPath: rootURL.appending(path: marker).path(percentEncoded: false))
        }
    }

    static func commandOutput(arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/env")
        process.arguments = arguments
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                return nil
            }

            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }
}

private enum MockRuntimeExecutor {
    static func execute(
        _ package: ExecutionPackage,
        runtimeName: String,
        modelName: String?
    ) -> ExecutionResult {
        let selectedModel = modelName ?? "default model"
        let scopedPaths = package.scopedFiles.map(\.path)
        let trimmedCount = package.scopedFiles.filter(\.wasTrimmed).count

        var refreshedSignal = package.signal.map { signal in
            SignalItem(kind: signal.kind, title: signal.title)
        }

        refreshedSignal.append(
            SignalItem(
                kind: .decision,
                title: "\(runtimeName) prepared a bounded execution package using \(selectedModel)."
            )
        )

        if let firstFile = scopedPaths.first {
            refreshedSignal.append(
                SignalItem(
                    kind: .changedArtifact,
                    title: "Primary scoped handoff file: \(firstFile)"
                )
            )
        }

        if trimmedCount > 0 {
            refreshedSignal.append(
                SignalItem(
                    kind: .constraint,
                    title: "Compacted \(trimmedCount) large file contexts before agent handoff."
                )
            )
        }

        return ExecutionResult(
            headline: "\(runtimeName) package staged",
            detail: "\(runtimeName) received \(package.fileCount) scoped files for '\(package.task.title)' using \(selectedModel).",
            refreshedSignal: refreshedSignal,
            carriedForwardItems: package.carryForwardItems
        )
    }
}

private enum CodexCLIExecutor {
    static func execute(
        _ package: ExecutionPackage,
        runtimeName: String,
        model: AgentModel?,
        rootURL: URL
    ) async throws -> ExecutionResult {
        let outputURL = URL.temporaryDirectory.appending(path: "nanga-codex-last-message-\(UUID().uuidString).txt")
        let prompt = buildPrompt(from: package)

        defer {
            try? FileManager.default.removeItem(at: outputURL)
        }

        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/env")

        var arguments = [
            "codex",
            "exec",
            "--cd", rootURL.path(percentEncoded: false),
            "--sandbox", "workspace-write",
            "--full-auto",
            "--ephemeral",
            "--output-last-message", outputURL.path(percentEncoded: false),
            "-"
        ]

        if let model {
            arguments.insert(contentsOf: ["--model", model.id], at: 2)
        }

        process.arguments = arguments

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        stdinPipe.fileHandleForWriting.write(Data(prompt.utf8))
        try? stdinPipe.fileHandleForWriting.close()

        let stdoutData = try await stdoutPipe.fileHandleForReading.readToEnd() ?? Data()
        let stderrData = try await stderrPipe.fileHandleForReading.readToEnd() ?? Data()
        process.waitUntilExit()

        let stdout = String(decoding: stdoutData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        let stderr = String(decoding: stderrData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)

        guard process.terminationStatus == 0 else {
            let failureDetail = [stderr, stdout]
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
            throw CodexRuntimeError.executionFailed(failureDetail.isEmpty ? "Codex CLI exited with status \(process.terminationStatus)." : failureDetail)
        }

        let message = (try? String(contentsOf: outputURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines))
            .flatMap { $0.isEmpty ? nil : $0 }
            ?? stdout

        var refreshedSignal = package.signal.map { signal in
            SignalItem(kind: signal.kind, title: signal.title)
        }

        refreshedSignal.append(
            SignalItem(
                kind: .decision,
                title: "\(runtimeName) executed inside \(package.repositoryName) with \(package.fileCount) scoped files."
            )
        )

        if let firstFile = package.scopedFiles.first?.path {
            refreshedSignal.append(
                SignalItem(
                    kind: .changedArtifact,
                    title: "Primary scoped execution file: \(firstFile)"
                )
            )
        }

        return ExecutionResult(
            headline: "\(runtimeName) execution complete",
            detail: message.isEmpty ? "Codex completed without a final message." : message,
            refreshedSignal: refreshedSignal,
            carriedForwardItems: package.carryForwardItems
        )
    }

    private static func buildPrompt(from package: ExecutionPackage) -> String {
        let signalLines = package.signal.map { "- [\($0.kind.rawValue)] \($0.title)" }.joined(separator: "\n")
        let carryForwardLines = package.carryForwardItems.map { "- \($0)" }.joined(separator: "\n")
        let constraintLines = package.constraints.map { "- \($0)" }.joined(separator: "\n")
        let fileBlocks = package.scopedFiles.map { file in
            """
            ### \(file.path)
            lines: \(file.lineCount)
            trimmed: \(file.wasTrimmed ? "yes" : "no")
            ```text
            \(file.content)
            ```
            """
        }.joined(separator: "\n\n")

        return """
        You are connected through Nanga, a scoped agent execution layer.

        Repository: \(package.repositoryName)
        Project root: \(package.projectRootPath)

        Task title: \(package.task.title)
        Task detail: \(package.task.detail)

        Signal:
        \(signalLines.isEmpty ? "- none" : signalLines)

        Carry-forward state:
        \(carryForwardLines.isEmpty ? "- none" : carryForwardLines)

        Constraints:
        \(constraintLines.isEmpty ? "- none" : constraintLines)

        Scoped files:
        \(fileBlocks.isEmpty ? "No files were provided." : fileBlocks)

        Work only within the scoped task and files unless you must explain why the scope is insufficient.
        End with a concise summary of what you changed or what blocked execution.
        """
    }
}

private enum CodexRuntimeError: LocalizedError {
    case executionFailed(String)

    var errorDescription: String? {
        switch self {
        case .executionFailed(let detail):
            detail
        }
    }
}
