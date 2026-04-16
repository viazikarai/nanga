import Foundation

struct NangaProject: Identifiable, Equatable, Codable {
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case repositoryName
        case rootFolder
        case selectedAgentRuntimeID
        case selectedAgentModelID
        case isAgentSelectionLocked
        case agentSession
        case currentIteration
        case iterationHistory
    }

    let id: UUID
    var name: String
    var repositoryName: String
    var rootFolder: ProjectFolderReference?
    var selectedAgentRuntimeID: String
    var selectedAgentModelID: String
    var isAgentSelectionLocked: Bool
    var agentSession: AgentSession?
    var currentIteration: IterationState
    var iterationHistory: [IterationRecord]

    static let sample = NangaProject(
        id: UUID(),
        name: "Nanga",
        repositoryName: "nanga",
        rootFolder: nil,
        selectedAgentRuntimeID: "codex",
        selectedAgentModelID: "",
        isAgentSelectionLocked: false,
        agentSession: nil,
        currentIteration: IterationState.sample,
        iterationHistory: [
            IterationRecord(
                label: "Define the first Nanga shell",
                savedAt: .now.addingTimeInterval(-3_600),
                summary: "Saved the first product-shaped iteration frame.",
                carriedForwardItems: ["task intent", "signal scaffolding", "scope surfaces"],
                scopedFiles: ["nanga/Features/RunLoop/ContentView.swift", "nanga/Features/RunLoop/NangaAppModel.swift"]
            )
        ]
    )

    init(
        id: UUID,
        name: String,
        repositoryName: String,
        rootFolder: ProjectFolderReference?,
        selectedAgentRuntimeID: String,
        selectedAgentModelID: String,
        isAgentSelectionLocked: Bool,
        agentSession: AgentSession?,
        currentIteration: IterationState,
        iterationHistory: [IterationRecord]
    ) {
        self.id = id
        self.name = name
        self.repositoryName = repositoryName
        self.rootFolder = rootFolder
        self.selectedAgentRuntimeID = selectedAgentRuntimeID
        self.selectedAgentModelID = selectedAgentModelID
        self.isAgentSelectionLocked = isAgentSelectionLocked
        self.agentSession = agentSession
        self.currentIteration = currentIteration
        self.iterationHistory = iterationHistory
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        repositoryName = try container.decode(String.self, forKey: .repositoryName)
        rootFolder = try container.decodeIfPresent(ProjectFolderReference.self, forKey: .rootFolder)
        selectedAgentRuntimeID = try container.decodeIfPresent(String.self, forKey: .selectedAgentRuntimeID) ?? "codex"
        selectedAgentModelID = try container.decodeIfPresent(String.self, forKey: .selectedAgentModelID) ?? ""
        isAgentSelectionLocked = try container.decodeIfPresent(Bool.self, forKey: .isAgentSelectionLocked) ?? false
        agentSession = try container.decodeIfPresent(AgentSession.self, forKey: .agentSession)
        currentIteration = try container.decode(IterationState.self, forKey: .currentIteration)
        iterationHistory = try container.decode([IterationRecord].self, forKey: .iterationHistory)
    }

    func minimizedForPersistence() -> NangaProject {
        var project = self
        project.currentIteration = currentIteration.minimizedForPersistence()
        project.iterationHistory = iterationHistory
            .map { $0.minimizedForPersistence() }
            .prefix(12)
            .map { $0 }
        return project
    }
}
