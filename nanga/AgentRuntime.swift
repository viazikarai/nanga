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
        CLIWorkspaceDetector.connection(
            runtimeID: id,
            runtimeName: displayName,
            command: "codex",
            rootURL: rootURL,
            workspaceMarkers: [".codex", "AGENTS.md", ".git"],
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
        let markers = workspaceMarkers.filter { marker in
            fileManager.fileExists(atPath: rootURL.appending(path: marker).path(percentEncoded: false))
        }

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
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/env")
        process.arguments = ["which", command]
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
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
