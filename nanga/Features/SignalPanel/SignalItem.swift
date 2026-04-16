import Foundation

struct SignalItem: Identifiable, Equatable, Codable {
    enum Kind: String, Equatable, Codable {
        case taskIntent = "Task Intent"
        case relevantFile = "Relevant File"
        case constraint = "Constraint"
        case unfinishedWork = "Unfinished Work"
        case changedArtifact = "Changed Artifact"
        case decision = "Decision"
    }

    let id: UUID
    var kind: Kind
    var title: String

    init(id: UUID = UUID(), kind: Kind, title: String) {
        self.id = id
        self.kind = kind
        self.title = title
    }

    func minimizedForPersistence() -> SignalItem {
        SignalItem(
            kind: kind,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}
