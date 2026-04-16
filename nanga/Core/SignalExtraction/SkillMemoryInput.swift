import Foundation

// input contract for one memory-optimization pass.
public struct SkillMemoryInput: Equatable {
    // current task title + intent.
    public var task: TaskDraft
    // user-approved root used for scoped discovery.
    public var rootURL: URL
    // previously selected scope files from the last turn.
    public var previousScopeFiles: [String]
    // recent notes or outputs that may contain carry-forward signal.
    public var recentNotes: [String]
    // maximum number of signal items to keep in the output.
    public var signalBudget: Int
    // maximum number of scope files to keep in the output.
    public var scopeBudget: Int
    // estimated token budget for the keep bucket.
    public var tokenBudget: Int

    public init(
        task: TaskDraft,
        rootURL: URL,
        previousScopeFiles: [String] = [],
        recentNotes: [String] = [],
        signalBudget: Int = 8,
        scopeBudget: Int = 4,
        tokenBudget: Int = 700
    ) {
        // keep the input deterministic and bounded.
        self.task = task
        self.rootURL = rootURL
        self.previousScopeFiles = previousScopeFiles
        self.recentNotes = recentNotes
        self.signalBudget = max(1, signalBudget)
        self.scopeBudget = max(1, scopeBudget)
        self.tokenBudget = max(1, tokenBudget)
    }
}
