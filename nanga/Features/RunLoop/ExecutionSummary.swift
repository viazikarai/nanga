import Foundation

struct ExecutionSummary: Equatable, Codable {
    enum Status: String, Equatable, Codable {
        case ready = "Ready"
        case running = "Running"
        case refreshed = "Refreshed"
        case failed = "Failed"
    }

    var status: Status
    var headline: String
    var detail: String

    func minimizedForPersistence() -> ExecutionSummary {
        ExecutionSummary(
            status: status,
            headline: headline,
            detail: detail.isEmpty ? detail : "Stored compact execution status."
        )
    }
}

struct SavedIterationState: Equatable, Codable {
    var summary: String
    var carriedForwardItems: [String]

    func minimizedForPersistence() -> SavedIterationState {
        SavedIterationState(
            summary: summary,
            carriedForwardItems: carriedForwardItems.uniquePrefix(6)
        )
    }
}
