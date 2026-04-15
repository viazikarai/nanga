import Foundation

struct FileDiscoveryService {
    private let fileManager: FileManager
    private let allowedExtensions: Set<String>
    private let maxCandidates: Int
    private let maxAutoSelected: Int
    private let maxContentCharacters: Int

    init(
        fileManager: FileManager = .default,
        allowedExtensions: Set<String> = ["swift", "md", "txt", "json", "yml", "yaml"],
        maxCandidates: Int = 12,
        maxAutoSelected: Int = 4,
        maxContentCharacters: Int = 8_000
    ) {
        self.fileManager = fileManager
        self.allowedExtensions = allowedExtensions
        self.maxCandidates = maxCandidates
        self.maxAutoSelected = maxAutoSelected
        self.maxContentCharacters = maxContentCharacters
    }

    func discoverCandidates(in rootURL: URL, task: TaskDraft, previousSelections: [String]) throws -> [CandidateFile] {
        let tokens = tokenize("\(task.title) \(task.detail)")
        let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )

        var matches: [CandidateFile] = []

        while let fileURL = enumerator?.nextObject() as? URL {
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else { continue }

            let ext = fileURL.pathExtension.lowercased()
            guard allowedExtensions.contains(ext) else { continue }

            let relativePath = relativePath(from: fileURL, rootURL: rootURL)
            let pathTokens = tokenize(relativePath)
            let contentTokens = tokenize(readSearchableContent(from: fileURL))

            let sharedPathTokens = Set(tokens).intersection(pathTokens)
            let sharedContentTokens = Set(tokens).intersection(contentTokens)
            let previousBoost = previousSelections.contains(relativePath) ? 3 : 0
            let score = sharedPathTokens.count * 5
                + sharedContentTokens.count * 3
                + filenameBoost(for: relativePath, using: tokens)
                + previousBoost

            guard score > 0 || matches.count < 6 else { continue }

            let reason: String
            let matchedTokens = Array(sharedPathTokens.union(sharedContentTokens)).sorted()
            if matchedTokens.isEmpty {
                reason = "Added as a fallback candidate from the project root."
            } else {
                reason = "Nanga matched task terms: \(matchedTokens.joined(separator: ", "))"
            }

            matches.append(
                CandidateFile(
                    path: relativePath,
                    reason: reason,
                    score: score,
                    isSelected: false
                )
            )
        }

        let sortedMatches = matches
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.path < rhs.path
                }
                return lhs.score > rhs.score
            }

        let limitedMatches = Array(sortedMatches.prefix(maxCandidates))
        return autoSelectScope(from: limitedMatches)
    }

    private func filenameBoost(for path: String, using tokens: [String]) -> Int {
        let lastComponent = URL(filePath: path).lastPathComponent.lowercased()
        return tokens.reduce(into: 0) { partialResult, token in
            if lastComponent.contains(token) {
                partialResult += 2
            }
        }
    }

    private func tokenize(_ string: String) -> [String] {
        let rawParts = string
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)

        let stopWords: Set<String> = [
            "the", "and", "for", "with", "into", "from", "this", "that",
            "make", "build", "show", "state", "current", "iteration"
        ]

        return rawParts
            .filter { $0.count > 2 && !stopWords.contains($0) }
    }

    private func readSearchableContent(from fileURL: URL) -> String {
        guard let data = try? Data(contentsOf: fileURL),
              let content = String(data: data.prefix(maxContentCharacters), encoding: .utf8) else {
            return ""
        }

        return content
    }

    private func autoSelectScope(from matches: [CandidateFile]) -> [CandidateFile] {
        guard !matches.isEmpty else { return [] }

        let selectedPaths = Set(matches.prefix(maxAutoSelected).map(\.path))
        return matches.map { candidate in
            CandidateFile(
                id: candidate.id,
                path: candidate.path,
                reason: candidate.reason,
                score: candidate.score,
                isSelected: selectedPaths.contains(candidate.path)
            )
        }
    }

    private func relativePath(from fileURL: URL, rootURL: URL) -> String {
        let rootPath = rootURL.path(percentEncoded: false)
        let filePath = fileURL.path(percentEncoded: false)
        guard filePath.hasPrefix(rootPath) else { return fileURL.lastPathComponent }

        return String(filePath.dropFirst(rootPath.count))
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}
