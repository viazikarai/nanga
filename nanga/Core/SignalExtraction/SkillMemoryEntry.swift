import Foundation

// one normalized memory item used by keep/defer/drop.
public struct SkillMemoryEntry: Equatable {
    // semantic class for downstream formatting and scoring.
    public enum Kind: String, Equatable {
        case goal = "Goal"
        case decision = "Decision"
        case constraint = "Constraint"
        case relevantFile = "Relevant File"
        case observation = "Observation"
        case unresolved = "Unresolved"
    }

    // memory category.
    public var kind: Kind
    // human-readable entry text.
    public var title: String
    // relative importance for sorting and fallback.
    public var score: Int
    // rough token estimate used for budgeting.
    public var estimatedTokens: Int

    public init(kind: Kind, title: String, score: Int, estimatedTokens: Int) {
        // normalize whitespace and guarantee positive token count.
        self.kind = kind
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.score = score
        self.estimatedTokens = max(1, estimatedTokens)
    }
}
