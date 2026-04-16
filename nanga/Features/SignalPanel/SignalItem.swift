import Foundation

// typed signal item used by the memory optimizer.
public struct SignalItem: Identifiable, Equatable, Codable {
    // canonical signal categories surfaced by the skill.
    public enum Kind: String, Equatable, Codable {
        case taskIntent = "Task Intent"
        case relevantFile = "Relevant File"
        case constraint = "Constraint"
        case unfinishedWork = "Unfinished Work"
        case changedArtifact = "Changed Artifact"
        case decision = "Decision"
    }

    // stable identity for lists and merges.
    public let id: UUID
    // signal class used for sorting and formatting.
    public var kind: Kind
    // human-readable signal text.
    public var title: String

    public init(id: UUID = UUID(), kind: Kind, title: String) {
        self.id = id
        self.kind = kind
        self.title = title
    }

    // trim text before carry-forward persistence.
    public func minimizedForPersistence() -> SignalItem {
        SignalItem(
            kind: kind,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}
