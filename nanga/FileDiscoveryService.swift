import Foundation

struct FileDiscoveryService {
    private let fileManager: FileManager
    private let allowedExtensions: Set<String>
    private let maxCandidates: Int

    init(
        fileManager: FileManager = .default,
        allowedExtensions: Set<String> = ["swift", "md", "txt", "json", "yml", "yaml"],
        maxCandidates: Int = 12
    ) {
        self.fileManager = fileManager
        self.allowedExtensions = allowedExtensions
        self.maxCandidates = maxCandidates
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

            let sharedTokens = Set(tokens).intersection(pathTokens)
            let previousBoost = previousSelections.contains(relativePath) ? 3 : 0
            let score = sharedTokens.count * 4 + filenameBoost(for: relativePath, using: tokens) + previousBoost

            guard score > 0 || matches.count < 6 else { continue }

            let reason: String
            if sharedTokens.isEmpty {
                reason = "Added as a fallback candidate from the project root."
            } else {
                reason = "Matched task terms: \(sharedTokens.sorted().joined(separator: ", "))"
            }

            matches.append(
                CandidateFile(
                    path: relativePath,
                    reason: reason,
                    score: score,
                    isSelected: sharedTokens.count > 0 || previousSelections.contains(relativePath)
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
        if limitedMatches.contains(where: \.isSelected) {
            return limitedMatches
        }

        guard let first = limitedMatches.first else { return [] }
        var adjustedMatches = limitedMatches
        adjustedMatches[0] = CandidateFile(
            id: first.id,
            path: first.path,
            reason: first.reason,
            score: first.score,
            isSelected: true
        )
        return adjustedMatches
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

    private func relativePath(from fileURL: URL, rootURL: URL) -> String {
        let rootPath = rootURL.path(percentEncoded: false)
        let filePath = fileURL.path(percentEncoded: false)
        guard filePath.hasPrefix(rootPath) else { return fileURL.lastPathComponent }

        return String(filePath.dropFirst(rootPath.count))
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}
