import Foundation

// minimal task contract consumed by the skill optimizer.
public struct TaskDraft: Equatable, Codable {
    // short title for the current turn goal.
    public var title: String
    // explicit execution intent for the current turn.
    public var detail: String

    // skill execution requires both title and intent.
    public var isReadyForExecution: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public init(title: String, detail: String) {
        self.title = title
        self.detail = detail
    }

    // trim carry-forward fields before persistence or reuse.
    public func minimizedForPersistence() -> TaskDraft {
        TaskDraft(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            detail: detail.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}
