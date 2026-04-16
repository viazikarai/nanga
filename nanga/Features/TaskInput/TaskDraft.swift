import Foundation

struct TaskDraft: Equatable, Codable {
    var title: String
    var detail: String

    var isReadyForExecution: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func minimizedForPersistence() -> TaskDraft {
        TaskDraft(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            detail: detail.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}
