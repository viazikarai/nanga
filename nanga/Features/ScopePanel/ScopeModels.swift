import Foundation

// ranked scope candidate generated from approved-root discovery.
public struct CandidateFile: Identifiable, Equatable, Codable {
    // stable identity used by selection controls.
    public let id: UUID
    // relative file path inside the approved root.
    public var path: String
    // human-readable scoring explanation.
    public var reason: String
    // deterministic relevance score.
    public var score: Int
    // selected state for bounded scope handoff.
    public var isSelected: Bool

    public init(
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

// persisted snapshot of selected scope surfaces.
struct ScopeSnapshot: Equatable, Codable {
    var surfaces: [ScopeSurface]
    var folders: [String]
    var files: [String]

    // compact persisted shape to avoid oversized carry-forward state.
    func minimizedForPersistence() -> ScopeSnapshot {
        ScopeSnapshot(
            surfaces: surfaces,
            folders: [],
            files: Array(files.prefix(12))
        )
    }
}

// high-level product surfaces used for scope summaries.
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
