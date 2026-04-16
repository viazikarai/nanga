import Foundation

// deterministic file discovery + scoring for bounded scope selection.
public struct FileDiscoveryService {
    private let fileManager: FileManager
    private let allowedExtensions: Set<String>
    private let maxCandidates: Int
    private let maxAutoSelected: Int
    private let maxContentCharacters: Int
    private let pathScoreMultiplier: Int
    private let filenameScoreMultiplier: Int
    private let contentScoreMultiplier: Int
    private let previousSelectionBoost: Int

    public init(
        fileManager: FileManager = .default,
        allowedExtensions: Set<String> = ["swift", "md", "txt", "json", "yml", "yaml"],
        maxCandidates: Int = 12,
        maxAutoSelected: Int = 4,
        maxContentCharacters: Int = 8_000,
        pathScoreMultiplier: Int = 4,
        filenameScoreMultiplier: Int = 6,
        contentScoreMultiplier: Int = 2,
        previousSelectionBoost: Int = 4
    ) {
        self.fileManager = fileManager
        self.allowedExtensions = allowedExtensions
        self.maxCandidates = maxCandidates
        self.maxAutoSelected = maxAutoSelected
        self.maxContentCharacters = maxContentCharacters
        self.pathScoreMultiplier = pathScoreMultiplier
        self.filenameScoreMultiplier = filenameScoreMultiplier
        self.contentScoreMultiplier = contentScoreMultiplier
        self.previousSelectionBoost = previousSelectionBoost
    }

    // scan approved root and return ranked candidate files.
    public func discoverCandidates(in rootURL: URL, task: TaskDraft, previousSelections: [String]) throws -> [CandidateFile] {
        let titleTokens = tokenize(task.title)
        let detailTokens = tokenize(task.detail)
        let tokenWeights = buildTokenWeights(titleTokens: titleTokens, detailTokens: detailTokens)
        let rootPath = rootURL.standardizedFileURL.path(percentEncoded: false)
        let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )

        var matches: [CandidateFile] = []

        while let fileURL = enumerator?.nextObject() as? URL {
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true else { continue }
            if values.isSymbolicLink == true { continue }

            let standardizedFilePath = fileURL.standardizedFileURL.path(percentEncoded: false)
            guard standardizedFilePath.hasPrefix(rootPath) else { continue }

            let ext = fileURL.pathExtension.lowercased()
            guard allowedExtensions.contains(ext) else { continue }

            let relativePath = relativePath(from: fileURL, rootURL: rootURL)
            let pathTokens = Set(tokenize(relativePath))
            let filenameTokens = Set(tokenize(URL(filePath: relativePath).lastPathComponent))
            let contentTokens = Set(tokenize(readSearchableContent(from: fileURL)))

            let pathMatches = weightedMatches(pathTokens, using: tokenWeights)
            let filenameMatches = weightedMatches(filenameTokens, using: tokenWeights)
            let contentMatches = weightedMatches(contentTokens, using: tokenWeights)
            let wasPreviouslySelected = previousSelections.contains(relativePath)

            let score = pathMatches.weightedScore * pathScoreMultiplier
                + filenameMatches.weightedScore * filenameScoreMultiplier
                + contentMatches.weightedScore * contentScoreMultiplier
                + (wasPreviouslySelected ? previousSelectionBoost : 0)

            let reason = buildReason(
                pathMatches: pathMatches.tokens,
                filenameMatches: filenameMatches.tokens,
                contentMatches: contentMatches.tokens,
                wasPreviouslySelected: wasPreviouslySelected,
                score: score
            )

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

    // weight title tokens higher than detail tokens.
    private func buildTokenWeights(titleTokens: [String], detailTokens: [String]) -> [String: Int] {
        var weights: [String: Int] = [:]

        for token in titleTokens {
            weights[token] = max(weights[token] ?? 0, 3)
        }

        for token in detailTokens {
            weights[token] = max(weights[token] ?? 0, 2)
        }

        return weights
    }

    // find overlap between discovered tokens and task tokens.
    private func weightedMatches(_ candidateTokens: Set<String>, using tokenWeights: [String: Int]) -> (tokens: [String], weightedScore: Int) {
        var matchedTokens: [String] = []
        var weightedScore = 0

        for token in candidateTokens.sorted() {
            guard let weight = tokenWeights[token] else { continue }
            matchedTokens.append(token)
            weightedScore += weight
        }

        return (matchedTokens, weightedScore)
    }

    // build human-readable scoring reasons for each candidate.
    private func buildReason(
        pathMatches: [String],
        filenameMatches: [String],
        contentMatches: [String],
        wasPreviouslySelected: Bool,
        score: Int
    ) -> String {
        var reasonParts: [String] = []

        if !filenameMatches.isEmpty {
            reasonParts.append("filename: \(filenameMatches.joined(separator: ", "))")
        }

        if !pathMatches.isEmpty {
            reasonParts.append("path: \(pathMatches.joined(separator: ", "))")
        }

        if !contentMatches.isEmpty {
            reasonParts.append("content: \(contentMatches.joined(separator: ", "))")
        }

        if wasPreviouslySelected {
            reasonParts.append("carried from previous scope")
        }

        if reasonParts.isEmpty || score == 0 {
            return "Fallback candidate from the approved folder because no direct task-term match was found."
        }

        return reasonParts.joined(separator: " | ")
    }

    // tokenize input text into simple alphanumeric terms.
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

    // read a bounded content slice for scoring context.
    private func readSearchableContent(from fileURL: URL) -> String {
        guard let data = try? Data(contentsOf: fileURL),
              let content = String(data: data.prefix(maxContentCharacters), encoding: .utf8) else {
            return ""
        }

        return content
    }

    // auto-select top candidates to produce a fast default scope.
    private func autoSelectScope(from matches: [CandidateFile]) -> [CandidateFile] {
        guard !matches.isEmpty else { return [] }

        let positiveMatches = matches.filter { $0.score > 0 }
        let selectedSeed = positiveMatches.isEmpty
            ? Array(matches.prefix(min(maxAutoSelected, 2)))
            : Array(positiveMatches.prefix(maxAutoSelected))
        let selectedPaths = Set(selectedSeed.map(\.path))

        return matches.map { candidate in
            let isSelected = selectedPaths.contains(candidate.path)
            let selectionSuffix: String
            if isSelected {
                selectionSuffix = candidate.score > 0
                    ? " | auto-selected: highest signal for this task"
                    : " | auto-selected fallback: no direct task-term match"
            } else {
                selectionSuffix = ""
            }

            return CandidateFile(
                id: candidate.id,
                path: candidate.path,
                reason: "\(candidate.reason)\(selectionSuffix)",
                score: candidate.score,
                isSelected: isSelected
            )
        }
    }

    // convert absolute file path to root-relative path.
    private func relativePath(from fileURL: URL, rootURL: URL) -> String {
        let rootPath = rootURL.path(percentEncoded: false)
        let filePath = fileURL.path(percentEncoded: false)
        guard filePath.hasPrefix(rootPath) else { return fileURL.lastPathComponent }

        return String(filePath.dropFirst(rootPath.count))
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}
