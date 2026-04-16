import Foundation

// deterministic pipeline that turns task + notes into bounded memory.
public struct SkillMemoryOptimizer {
    // existing file discovery logic used for scoped relevance ranking.
    private let fileDiscoveryService: FileDiscoveryService

    public init(fileDiscoveryService: FileDiscoveryService = FileDiscoveryService()) {
        self.fileDiscoveryService = fileDiscoveryService
    }

    // main entry point for a single skill-memory optimization pass.
    public func optimize(_ input: SkillMemoryInput) throws -> SkillMemoryOutput {
        // discover and rank files from the approved root.
        let candidates = try fileDiscoveryService.discoverCandidates(
            in: input.rootURL,
            task: input.task,
            previousSelections: input.previousScopeFiles
        )
        // lock scope to a bounded file list.
        let selectedScopeFiles = buildSelectedScopeFiles(from: candidates, fallback: input.previousScopeFiles, budget: input.scopeBudget)
        // derive panel-friendly signal from task + scope.
        let signal = buildSignal(
            task: input.task,
            rootPath: input.rootURL.path(percentEncoded: false),
            selectedScopeFiles: selectedScopeFiles,
            candidates: candidates,
            budget: input.signalBudget
        )
        // normalize signal/notes into scored memory entries.
        let entries = buildMemoryEntries(from: signal, notes: input.recentNotes)
        // enforce token budget and classify entries.
        let partitioned = partitionMemory(entries, tokenBudget: input.tokenBudget)
        // compile the bounded text payload for the next model turn.
        let prompt = buildCompactPrompt(
            task: input.task,
            selectedScopeFiles: selectedScopeFiles,
            keep: partitioned.keep,
            deferred: partitioned.defer
        )

        return SkillMemoryOutput(
            signal: signal,
            candidateFiles: candidates,
            selectedScopeFiles: selectedScopeFiles,
            keep: partitioned.keep,
            deferred: partitioned.defer,
            drop: partitioned.drop,
            compactPrompt: prompt
        )
    }

    // choose selected scope files from auto-selected candidates, then fallback.
    private func buildSelectedScopeFiles(from candidates: [CandidateFile], fallback: [String], budget: Int) -> [String] {
        let selected = candidates
            .filter(\.isSelected)
            .map(\.path)
        if !selected.isEmpty {
            return Array(selected.prefix(budget))
        }

        if !fallback.isEmpty {
            return Array(fallback.prefix(budget))
        }

        return Array(candidates.prefix(budget).map(\.path))
    }

    // derive bounded signal directly from current task + scoped files.
    private func buildSignal(
        task: TaskDraft,
        rootPath: String,
        selectedScopeFiles: [String],
        candidates: [CandidateFile],
        budget: Int
    ) -> [SignalItem] {
        var signal: [SignalItem] = []
        let title = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let detail = task.detail.trimmingCharacters(in: .whitespacesAndNewlines)

        if !title.isEmpty {
            signal.append(SignalItem(kind: .taskIntent, title: title))
        }

        if !detail.isEmpty {
            signal.append(SignalItem(kind: .decision, title: detail))
        }

        signal.append(SignalItem(kind: .constraint, title: "Approved root: \(rootPath)"))

        for path in selectedScopeFiles.prefix(3) {
            signal.append(SignalItem(kind: .relevantFile, title: path))
        }

        if let firstUnselected = candidates.first(where: { !$0.isSelected }) {
            signal.append(SignalItem(kind: .unfinishedWork, title: "Candidate left outside scope: \(firstUnselected.path)"))
        }

        if signal.isEmpty {
            signal.append(SignalItem(kind: .unfinishedWork, title: "Add task intent to begin a scoped run."))
        }

        return Array(signal.prefix(budget))
    }

    // map signal and notes into sorted, scored memory entries.
    private func buildMemoryEntries(from signal: [SignalItem], notes: [String]) -> [SkillMemoryEntry] {
        var entries = signal.map { signal in
            SkillMemoryEntry(
                kind: mapKind(signal.kind),
                title: signal.title,
                score: baseScore(for: signal.kind),
                estimatedTokens: estimateTokens(signal.title)
            )
        }

        let normalizedNotes = normalizeNotes(notes)
        for (index, note) in normalizedNotes.enumerated() {
            let score = max(30, 58 - (index * 4))
            entries.append(
                SkillMemoryEntry(
                    kind: .observation,
                    title: note,
                    score: score,
                    estimatedTokens: estimateTokens(note)
                )
            )
        }

        return entries.sorted { lhs, rhs in
            if lhs.score == rhs.score {
                if lhs.kind == rhs.kind {
                    return lhs.title < rhs.title
                }
                return lhs.kind.rawValue < rhs.kind.rawValue
            }
            return lhs.score > rhs.score
        }
    }

    // classify entries into keep/defer/drop using a strict token budget.
    private func partitionMemory(
        _ entries: [SkillMemoryEntry],
        tokenBudget: Int
    ) -> (keep: [SkillMemoryEntry], defer: [SkillMemoryEntry], drop: [SkillMemoryEntry]) {
        var keep: [SkillMemoryEntry] = []
        var deferred: [SkillMemoryEntry] = []
        var drop: [SkillMemoryEntry] = []
        var usedTokens = 0

        for entry in entries {
            if usedTokens + entry.estimatedTokens <= tokenBudget {
                keep.append(entry)
                usedTokens += entry.estimatedTokens
                continue
            }

            if entry.score >= 55 {
                deferred.append(entry)
            } else {
                drop.append(entry)
            }
        }

        if keep.isEmpty {
            if let fittingEntry = entries.first(where: { $0.estimatedTokens <= tokenBudget }) {
                keep = [fittingEntry]
                deferred = entries.filter { $0 != fittingEntry }
            } else if let smallestEntry = entries.min(by: { lhs, rhs in
                if lhs.estimatedTokens == rhs.estimatedTokens {
                    return lhs.score > rhs.score
                }
                return lhs.estimatedTokens < rhs.estimatedTokens
            }) {
                var clippedEntry = smallestEntry
                clippedEntry.estimatedTokens = tokenBudget
                keep = [clippedEntry]
                deferred = entries.filter { $0 != smallestEntry }
            }
            drop = []
        }

        return (keep, deferred, drop)
    }

    // format a compact next-turn prompt that small-context models can consume.
    private func buildCompactPrompt(
        task: TaskDraft,
        selectedScopeFiles: [String],
        keep: [SkillMemoryEntry],
        deferred: [SkillMemoryEntry]
    ) -> String {
        let keepLines = keep
            .map { "- [\($0.kind.rawValue)] \($0.title)" }
            .joined(separator: "\n")
        let deferredLines = deferred
            .prefix(4)
            .map { "- [\($0.kind.rawValue)] \($0.title)" }
            .joined(separator: "\n")
        let scopeLines = selectedScopeFiles.map { "- \($0)" }.joined(separator: "\n")

        return """
        Task: \(task.title)
        Intent: \(task.detail)

        Keep:
        \(keepLines.isEmpty ? "- none" : keepLines)

        Deferred:
        \(deferredLines.isEmpty ? "- none" : deferredLines)

        Scope:
        \(scopeLines.isEmpty ? "- none" : scopeLines)

        Work only from Keep + Scope. Pull Deferred only if blocked.
        """
    }

    // trim, dedupe, and preserve stable note order.
    private func normalizeNotes(_ notes: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []

        for note in notes {
            let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard !seen.contains(trimmed) else { continue }
            seen.insert(trimmed)
            result.append(trimmed)
        }

        return result
    }

    // translate generic signal kinds into skill-memory categories.
    private func mapKind(_ signalKind: SignalItem.Kind) -> SkillMemoryEntry.Kind {
        switch signalKind {
        case .taskIntent:
            .goal
        case .decision:
            .decision
        case .constraint:
            .constraint
        case .relevantFile, .changedArtifact:
            .relevantFile
        case .unfinishedWork:
            .unresolved
        }
    }

    // assign deterministic base scores to each signal kind.
    private func baseScore(for signalKind: SignalItem.Kind) -> Int {
        switch signalKind {
        case .taskIntent:
            100
        case .constraint:
            96
        case .decision:
            88
        case .relevantFile:
            76
        case .changedArtifact:
            68
        case .unfinishedWork:
            48
        }
    }

    // rough word-based token estimator for stable budgeting.
    private func estimateTokens(_ text: String) -> Int {
        let words = text.split { $0.isWhitespace || $0.isNewline }.count
        return max(8, (words * 2) + 6)
    }
}
