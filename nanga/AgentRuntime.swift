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

struct AgentSession: Equatable, Codable {
    var runtimeID: String
    var threadID: String
}

struct AgentRuntimeEvent: Equatable, Sendable {
    enum Kind: String, Equatable, Sendable {
        case status
        case threadStarted
        case message
        case error
    }

    var kind: Kind
    var message: String
}

protocol AgentRuntime {
    var id: String { get }
    var displayName: String { get }
    var models: [AgentModel] { get }

    func detectConnection(at rootURL: URL?) -> AgentConnection
    func connect(
        in rootURL: URL,
        model: AgentModel?,
        eventHandler: @escaping @Sendable (AgentRuntimeEvent) -> Void
    ) async throws -> AgentSession?
    func execute(
        _ package: ExecutionPackage,
        sessionID: String?,
        in rootURL: URL,
        model: AgentModel?,
        eventHandler: @escaping @Sendable (AgentRuntimeEvent) -> Void
    ) async throws -> ExecutionResult
}

extension AgentRuntime {
    func connect(
        in rootURL: URL,
        model: AgentModel?,
        eventHandler: @escaping @Sendable (AgentRuntimeEvent) -> Void
    ) async throws -> AgentSession? {
        nil
    }
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

        guard let loginStatus = CLIWorkspaceDetector.codexLoginStatus() else {
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
                detail: "\(loginStatus). Open a project folder to attach it.",
                models: models
            )
        }

        let markers = CLIWorkspaceDetector.detectWorkspaceMarkers(
            at: rootURL,
            workspaceMarkers: [".codex", "AGENTS.md", ".git"]
        )

        let detail = markers.isEmpty
            ? "\(loginStatus). Codex is ready to attach to this folder."
            : "\(loginStatus). Ready to attach in this folder. Workspace markers: \(markers.joined(separator: ", "))"

        return AgentConnection(
            runtimeID: id,
            runtimeName: displayName,
            status: .available,
            detail: detail,
            models: models
        )
    }

    func connect(
        in rootURL: URL,
        model: AgentModel?,
        eventHandler: @escaping @Sendable (AgentRuntimeEvent) -> Void
    ) async throws -> AgentSession? {
        try await CodexCLIExecutor.connect(
            rootURL: rootURL,
            model: model,
            eventHandler: eventHandler
        )
    }

    func execute(
        _ package: ExecutionPackage,
        sessionID: String?,
        in rootURL: URL,
        model: AgentModel?,
        eventHandler: @escaping @Sendable (AgentRuntimeEvent) -> Void
    ) async throws -> ExecutionResult {
        try await CodexCLIExecutor.execute(
            package,
            runtimeName: displayName,
            sessionID: sessionID,
            model: model,
            rootURL: rootURL,
            eventHandler: eventHandler
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

    func execute(
        _ package: ExecutionPackage,
        sessionID: String?,
        in rootURL: URL,
        model: AgentModel?,
        eventHandler: @escaping @Sendable (AgentRuntimeEvent) -> Void
    ) async throws -> ExecutionResult {
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

    func execute(
        _ package: ExecutionPackage,
        sessionID: String?,
        in rootURL: URL,
        model: AgentModel?,
        eventHandler: @escaping @Sendable (AgentRuntimeEvent) -> Void
    ) async throws -> ExecutionResult {
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
        resolvedCommandURL(command) != nil
    }

    static func codexLoginStatus() -> String? {
        guard let output = commandOutput(arguments: ["codex", "login", "status"]),
              output.localizedCaseInsensitiveContains("logged in") else {
            return nil
        }

        return output
    }

    static func detectWorkspaceMarkers(at rootURL: URL, workspaceMarkers: [String]) -> [String] {
        let fileManager = FileManager.default
        return workspaceMarkers.filter { marker in
            fileManager.fileExists(atPath: rootURL.appending(path: marker).path(percentEncoded: false))
        }
    }

    static func commandOutput(arguments: [String]) -> String? {
        guard !arguments.isEmpty else { return nil }

        let process = Process()
        let executableURL: URL
        let processArguments: [String]

        if let commandURL = resolvedCommandURL(arguments[0]) {
            executableURL = commandURL
            processArguments = Array(arguments.dropFirst())
        } else {
            executableURL = URL(filePath: "/usr/bin/env")
            processArguments = arguments
        }

        process.executableURL = executableURL
        process.arguments = processArguments
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

    static func resolvedCommandURL(_ command: String) -> URL? {
        if command.contains("/") {
            let url = URL(filePath: command)
            return FileManager.default.isExecutableFile(atPath: url.path(percentEncoded: false)) ? url : nil
        }

        let searchPaths = (
            ProcessInfo.processInfo.environment["PATH"]?.split(separator: ":").map(String.init) ?? []
        ) + [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin",
            NSHomeDirectory() + "/.local/bin",
            NSHomeDirectory() + "/bin"
        ]

        let uniquePaths = Array(NSOrderedSet(array: searchPaths)) as? [String] ?? searchPaths
        for directory in uniquePaths {
            let candidate = URL(filePath: directory).appending(path: command)
            if FileManager.default.isExecutableFile(atPath: candidate.path(percentEncoded: false)) {
                return candidate
            }
        }

        return nil
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
            carriedForwardItems: package.carryForwardItems,
            sessionID: nil
        )
    }
}

private enum CodexCLIExecutor {
    static func connect(
        rootURL: URL,
        model: AgentModel?,
        eventHandler: @escaping @Sendable (AgentRuntimeEvent) -> Void
    ) async throws -> AgentSession {
        let result = try await runCodexCommand(
            prompt: """
            Nanga is attaching to this workspace. Reply with CONNECTED and nothing else.
            """,
            sessionID: nil,
            model: model,
            rootURL: rootURL,
            eventHandler: eventHandler
        )

        guard let threadID = result.threadID else {
            throw CodexRuntimeError.executionFailed("Codex did not return a thread identifier.")
        }

        return AgentSession(runtimeID: "codex", threadID: threadID)
    }

    static func execute(
        _ package: ExecutionPackage,
        runtimeName: String,
        sessionID: String?,
        model: AgentModel?,
        rootURL: URL,
        eventHandler: @escaping @Sendable (AgentRuntimeEvent) -> Void
    ) async throws -> ExecutionResult {
        let prompt = buildPrompt(from: package)
        let runResult = try await runCodexCommand(
            prompt: prompt,
            sessionID: sessionID,
            model: model,
            rootURL: rootURL,
            eventHandler: eventHandler
        )
        let message = runResult.message

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
            carriedForwardItems: package.carryForwardItems,
            sessionID: runResult.threadID
        )
    }

    private static func runCodexCommand(
        prompt: String,
        sessionID: String?,
        model: AgentModel?,
        rootURL: URL,
        eventHandler: @escaping @Sendable (AgentRuntimeEvent) -> Void
    ) async throws -> (threadID: String?, message: String) {
        let process = Process()
        guard let codexURL = CLIWorkspaceDetector.resolvedCommandURL("codex") else {
            throw CodexRuntimeError.executionFailed("Codex CLI was not found on this machine.")
        }
        process.executableURL = codexURL
        process.currentDirectoryURL = rootURL

        if let sessionID {
            process.arguments = ["exec", "resume", sessionID]
        } else {
            process.arguments = [
                "exec",
                "--cd", rootURL.path(percentEncoded: false),
                "--sandbox", "workspace-write",
                "--full-auto"
            ]
        }
        process.arguments?.append(contentsOf: ["--json", "-"])

        if let model {
            process.arguments?.insert(contentsOf: ["--model", model.id], at: 1)
        }

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        stdinPipe.fileHandleForWriting.write(Data(prompt.utf8))
        try? stdinPipe.fileHandleForWriting.close()

        async let stdout = collectLines(
            from: stdoutPipe.fileHandleForReading,
            eventHandler: eventHandler
        )
        async let stderrOutput = collectStderr(from: stderrPipe.fileHandleForReading, eventHandler: eventHandler)
        await waitForExit(of: process)

        let stdoutOutput = try await stdout
        let stderrText = try await stderrOutput
        let stderr = stderrText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard process.terminationStatus == 0 else {
            let failureDetail = [stderr, stdoutOutput.trimmingCharacters(in: .whitespacesAndNewlines)]
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
            throw CodexRuntimeError.executionFailed(failureDetail.isEmpty ? "Codex CLI exited with status \(process.terminationStatus)." : failureDetail)
        }

        let parsed = parseJSONL(stdoutOutput)
        let message = parsed.message ?? stdoutOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        return (parsed.threadID, message)
    }

    private static func collectLines(
        from handle: FileHandle,
        eventHandler: @escaping @Sendable (AgentRuntimeEvent) -> Void
    ) async throws -> String {
        var output = ""

        for try await line in handle.bytes.lines {
            output.append(line)
            output.append("\n")

            if let event = parseEvent(line) {
                eventHandler(event)
            }
        }

        return output
    }

    private static func collectStderr(
        from handle: FileHandle,
        eventHandler: @escaping @Sendable (AgentRuntimeEvent) -> Void
    ) async throws -> String {
        var output = ""

        for try await line in handle.bytes.lines {
            output.append(line)
            output.append("\n")

            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                eventHandler(AgentRuntimeEvent(kind: .error, message: trimmed))
            }
        }

        return output
    }

    private static func waitForExit(of process: Process) async {
        await withCheckedContinuation { continuation in
            process.terminationHandler = { _ in
                continuation.resume()
            }
        }
    }

    private static func parseEvent(_ line: String) -> AgentRuntimeEvent? {
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = object["type"] as? String else {
            return nil
        }

        switch type {
        case "thread.started":
            if let threadID = object["thread_id"] as? String {
                return AgentRuntimeEvent(kind: .threadStarted, message: "Attached to Codex thread \(threadID)")
            }
        case "turn.started":
            return AgentRuntimeEvent(kind: .status, message: "Codex turn started")
        case "item.completed":
            if let item = object["item"] as? [String: Any],
               let text = item["text"] as? String,
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return AgentRuntimeEvent(kind: .message, message: text.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        case "error":
            if let message = object["message"] as? String {
                return AgentRuntimeEvent(kind: .error, message: message)
            }
        default:
            break
        }

        return nil
    }

    private static func parseJSONL(_ output: String) -> (threadID: String?, message: String?) {
        var threadID: String?
        var message: String?

        for line in output.split(separator: "\n") {
            guard let data = line.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = object["type"] as? String else {
                continue
            }

            if type == "thread.started" {
                threadID = object["thread_id"] as? String
            }

            if type == "item.completed",
               let item = object["item"] as? [String: Any],
               let text = item["text"] as? String,
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                message = text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return (threadID, message)
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
