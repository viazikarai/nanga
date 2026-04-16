import Foundation

struct CandidateFile: Identifiable, Equatable, Codable {
    let id: UUID
    var path: String
    var reason: String
    var score: Int
    var isSelected: Bool

    init(
        id: UUID = UUID(),
        path: String,
        reason: String,
        score: Int,
        isSelected: Bool
    ) {
        self.id = id
        self.path = path
        self.reason = reason
        self.score = score
        self.isSelected = isSelected
    }
}

struct ScopeSnapshot: Equatable, Codable {
    var surfaces: [ScopeSurface]
    var folders: [String]
    var files: [String]

    func minimizedForPersistence() -> ScopeSnapshot {
        ScopeSnapshot(
            surfaces: surfaces,
            folders: [],
            files: Array(files.prefix(12))
        )
    }
}

enum ScopeSurface: String, CaseIterable, Identifiable, Codable {
    case projectRoot = "Project Root"
    case taskInput = "Task Input"
    case signalPanel = "Signal Panel"
    case scopePanel = "Scope Panel"
    case executionResult = "Execution Result"
    case savedIterationState = "Saved Iteration State"
    case iterationHistory = "Iteration History"

    var id: String { rawValue }
}
