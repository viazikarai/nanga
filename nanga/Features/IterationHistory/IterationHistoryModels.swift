import Foundation

struct IterationRecord: Identifiable, Equatable, Codable {
    let id: UUID
    var label: String
    var savedAt: Date
    var summary: String
    var carriedForwardItems: [String]
    var scopedFiles: [String]

    init(
        id: UUID = UUID(),
        label: String,
        savedAt: Date,
        summary: String,
        carriedForwardItems: [String],
        scopedFiles: [String]
    ) {
        self.id = id
        self.label = label
        self.savedAt = savedAt
        self.summary = summary
        self.carriedForwardItems = carriedForwardItems
        self.scopedFiles = scopedFiles
    }

    enum CodingKeys: String, CodingKey {
        case id
        case label
        case savedAt
        case summary
        case carriedForwardItems
        case scopedFiles
        case snapshot
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        label = try container.decode(String.self, forKey: .label)
        savedAt = try container.decode(Date.self, forKey: .savedAt)

        if container.contains(.summary) {
            summary = try container.decode(String.self, forKey: .summary)
            carriedForwardItems = try container.decodeIfPresent([String].self, forKey: .carriedForwardItems) ?? []
            scopedFiles = try container.decodeIfPresent([String].self, forKey: .scopedFiles) ?? []
            return
        }

        let snapshot = try container.decode(IterationSnapshot.self, forKey: .snapshot)
        summary = snapshot.savedState.summary
        carriedForwardItems = snapshot.savedState.carriedForwardItems
        scopedFiles = Array(snapshot.scope.files.prefix(5))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(label, forKey: .label)
        try container.encode(savedAt, forKey: .savedAt)
        try container.encode(summary, forKey: .summary)
        try container.encode(carriedForwardItems, forKey: .carriedForwardItems)
        try container.encode(scopedFiles, forKey: .scopedFiles)
    }

    func minimizedForPersistence() -> IterationRecord {
        IterationRecord(
            id: id,
            label: label,
            savedAt: savedAt,
            summary: summary,
            carriedForwardItems: carriedForwardItems.uniquePrefix(6),
            scopedFiles: Array(scopedFiles.prefix(5))
        )
    }
}

struct IterationSnapshot: Equatable, Codable {
    var task: TaskDraft
    var signal: [SignalItem]
    var scope: ScopeSnapshot
    var execution: ExecutionSummary
    var savedState: SavedIterationState
    var candidateFiles: [CandidateFile]
}

private extension Array where Element == String {
    func uniquePrefix(_ maxCount: Int) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for value in self {
            guard !value.isEmpty, !seen.contains(value) else { continue }
            seen.insert(value)
            result.append(value)
            if result.count == maxCount {
                break
            }
        }

        return result
    }
}
