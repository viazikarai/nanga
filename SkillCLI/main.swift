import Foundation
import NangaCore

// cli args for one skill-memory optimization run.
private struct SkillCLIInput {
    var rootPath: String
    var taskTitle: String
    var taskIntent: String
    var previousScopeFiles: [String]
    var notes: [String]
    var signalBudget: Int
    var scopeBudget: Int
    var tokenBudget: Int

    static func parse(arguments: [String]) throws -> SkillCLIInput {
        var rootPath: String?
        var taskTitle: String?
        var taskIntent: String?
        var previousScopeFiles: [String] = []
        var notes: [String] = []
        var signalBudget = 8
        var scopeBudget = 4
        var tokenBudget = 700

        var index = 0
        while index < arguments.count {
            let argument = arguments[index]

            func value(after position: Int) throws -> String {
                guard position + 1 < arguments.count else {
                    throw SkillCLIError.invalidArguments("missing value for \(argument)")
                }
                return arguments[position + 1]
            }

            switch argument {
            case "--root":
                rootPath = try value(after: index)
                index += 2
            case "--task":
                taskTitle = try value(after: index)
                index += 2
            case "--intent":
                taskIntent = try value(after: index)
                index += 2
            case "--scope-file":
                previousScopeFiles.append(try value(after: index))
                index += 2
            case "--note":
                notes.append(try value(after: index))
                index += 2
            case "--signal-budget":
                signalBudget = try parseInt(value(after: index), name: "--signal-budget")
                index += 2
            case "--scope-budget":
                scopeBudget = try parseInt(value(after: index), name: "--scope-budget")
                index += 2
            case "--token-budget":
                tokenBudget = try parseInt(value(after: index), name: "--token-budget")
                index += 2
            case "--help", "-h":
                throw SkillCLIError.helpRequested
            default:
                throw SkillCLIError.invalidArguments("unknown argument: \(argument)")
            }
        }

        guard let rootPath else {
            throw SkillCLIError.invalidArguments("missing --root")
        }
        guard let taskTitle else {
            throw SkillCLIError.invalidArguments("missing --task")
        }
        guard let taskIntent else {
            throw SkillCLIError.invalidArguments("missing --intent")
        }

        return SkillCLIInput(
            rootPath: rootPath,
            taskTitle: taskTitle,
            taskIntent: taskIntent,
            previousScopeFiles: previousScopeFiles,
            notes: notes,
            signalBudget: signalBudget,
            scopeBudget: scopeBudget,
            tokenBudget: tokenBudget
        )
    }

    private static func parseInt(_ raw: String, name: String) throws -> Int {
        guard let value = Int(raw), value > 0 else {
            throw SkillCLIError.invalidArguments("invalid value for \(name): \(raw)")
        }
        return value
    }
}

// user-facing cli failures.
private enum SkillCLIError: LocalizedError {
    case invalidArguments(String)
    case helpRequested

    var errorDescription: String? {
        switch self {
        case .invalidArguments(let detail):
            detail
        case .helpRequested:
            nil
        }
    }
}

// stable text rendering for keep/defer/drop sections.
private enum SkillCLIPrinter {
    static func render(_ output: SkillMemoryOutput) {
        print("signal:")
        for item in output.signal {
            print("- [\(item.kind.rawValue)] \(item.title)")
        }

        print("\nscope:")
        if output.selectedScopeFiles.isEmpty {
            print("- none")
        } else {
            for path in output.selectedScopeFiles {
                print("- \(path)")
            }
        }

        print("\nkeep:")
        printEntries(output.keep)

        print("\ndefer:")
        printEntries(output.deferred)

        print("\ndrop:")
        printEntries(output.drop)

        print("\ncompact_prompt:")
        print(output.compactPrompt)
    }

    private static func printEntries(_ entries: [SkillMemoryEntry]) {
        if entries.isEmpty {
            print("- none")
            return
        }

        for entry in entries {
            print("- [\(entry.kind.rawValue)] s\(entry.score) t\(entry.estimatedTokens): \(entry.title)")
        }
    }

    static func usage() -> String {
        """
        usage:
          nanga-skill --root <path> --task <title> --intent <detail> [options]

        options:
          --scope-file <relative-path>   include previous scope file (repeatable)
          --note <text>                  add recent note/observation (repeatable)
          --signal-budget <int>          default: 8
          --scope-budget <int>           default: 4
          --token-budget <int>           default: 700
          --help                         show this message
        """
    }
}

do {
    // parse cli input first.
    let input = try SkillCLIInput.parse(arguments: Array(CommandLine.arguments.dropFirst()))
    let optimizer = SkillMemoryOptimizer(fileDiscoveryService: FileDiscoveryService())

    // run the deterministic optimization pipeline.
    let output = try optimizer.optimize(
        SkillMemoryInput(
            task: TaskDraft(title: input.taskTitle, detail: input.taskIntent),
            rootURL: URL(filePath: input.rootPath, directoryHint: .isDirectory),
            previousScopeFiles: input.previousScopeFiles,
            recentNotes: input.notes,
            signalBudget: input.signalBudget,
            scopeBudget: input.scopeBudget,
            tokenBudget: input.tokenBudget
        )
    )

    // print structured sections for terminal use.
    SkillCLIPrinter.render(output)
} catch let error as SkillCLIError {
    switch error {
    case .helpRequested:
        print(SkillCLIPrinter.usage())
        exit(0)
    case .invalidArguments(let detail):
        fputs("error: \(detail)\n\n", stderr)
        fputs("\(SkillCLIPrinter.usage())\n", stderr)
        exit(2)
    }
} catch {
    fputs("error: \(error.localizedDescription)\n", stderr)
    exit(1)
}
