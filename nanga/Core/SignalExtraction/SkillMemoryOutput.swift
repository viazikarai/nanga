import Foundation

// full output for one optimized turn payload.
public struct SkillMemoryOutput: Equatable {
    // filtered signal that should carry into the prompt.
    public var signal: [SignalItem]
    // ranked candidate files discovered from the approved root.
    public var candidateFiles: [CandidateFile]
    // bounded scope that should be handed to the model.
    public var selectedScopeFiles: [String]
    // memory items that fit the token budget.
    public var keep: [SkillMemoryEntry]
    // high-value items that were excluded by budget.
    public var deferred: [SkillMemoryEntry]
    // low-value items discarded for this turn.
    public var drop: [SkillMemoryEntry]
    // compact text payload for the next model turn.
    public var compactPrompt: String

    public init(
        signal: [SignalItem],
        candidateFiles: [CandidateFile],
        selectedScopeFiles: [String],
        keep: [SkillMemoryEntry],
        deferred: [SkillMemoryEntry],
        drop: [SkillMemoryEntry],
        compactPrompt: String
    ) {
        self.signal = signal
        self.candidateFiles = candidateFiles
        self.selectedScopeFiles = selectedScopeFiles
        self.keep = keep
        self.deferred = deferred
        self.drop = drop
        self.compactPrompt = compactPrompt
    }
}
