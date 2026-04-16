import Foundation

private enum TerminalCommandLauncher {
    static func openCodexLoginAssisted(workingRootURL: URL?) throws {
        let workingPath = (workingRootURL ?? URL(filePath: NSHomeDirectory())).path(percentEncoded: false)
        let shellCommand = """
        cd \(shellSingleQuoted(workingPath));
        if codex login status 2>/dev/null | grep -qi "logged in"; then
            echo "Codex is already logged in."
        else
            echo "Starting Codex device login..."
            codex login --device-auth
            if [ $? -ne 0 ]; then
                echo "Device auth failed (403 can happen). Trying standard login..."
                codex login
                if [ $? -ne 0 ]; then
                    echo "Codex login failed. You can use API key login:"
                    echo "printenv OPENAI_API_KEY | codex login --with-api-key"
                fi
            fi
        fi
        echo "When login succeeds, return to Nanga and press Verify Login."
        """
        let script = """
        tell application "Terminal"
            activate
            do script "\(appleScriptEscaped(shellCommand))"
        end tell
        """

        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorText = String(decoding: errorData, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw TerminalCommandError.launchFailed(
                errorText.isEmpty ? "Terminal command exited with status \(process.terminationStatus)." : errorText
            )
        }
    }

    private static func shellSingleQuoted(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escaped)'"
    }

    private static func appleScriptEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}

private enum TerminalCommandError: LocalizedError {
    case launchFailed(String)

    var errorDescription: String? {
        switch self {
        case .launchFailed(let detail):
            detail
        }
    }
}
