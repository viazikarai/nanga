import Foundation

struct ProjectStore {
    let baseDirectoryURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        baseDirectoryURL: URL = URL.applicationSupportDirectory.appending(path: "Nanga", directoryHint: .isDirectory),
        fileManager: FileManager = .default
    ) {
        self.baseDirectoryURL = baseDirectoryURL
        self.fileManager = fileManager

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder

        self.decoder = JSONDecoder()
    }

    var projectFileURL: URL {
        baseDirectoryURL
            .appending(path: "Projects", directoryHint: .isDirectory)
            .appending(path: "current-project.json")
    }

    func loadProject() throws -> NangaProject {
        let data = try Data(contentsOf: projectFileURL)
        return try decoder.decode(NangaProject.self, from: data)
    }

    func saveProject(_ project: NangaProject) throws {
        let data = try encoder.encode(project)
        let directoryURL = projectFileURL.deletingLastPathComponent()

        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try data.write(to: projectFileURL, options: .atomic)
    }
}
