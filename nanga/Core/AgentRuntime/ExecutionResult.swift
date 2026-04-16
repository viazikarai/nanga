import Foundation

struct ExecutionResult: Equatable {
    var headline: String
    var detail: String
    var refreshedSignal: [SignalItem]
    var carriedForwardItems: [String]
    var sessionID: String?
}
