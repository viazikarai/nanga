import Foundation

struct CodexLoginVerificationSignal: Equatable {
    enum Tone: Equatable {
        case success
        case warning
        case neutral
    }

    var title: String
    var detail: String
    var tone: Tone
}
