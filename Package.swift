// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "NangaCore",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "NangaCore",
            targets: ["NangaCore"]
        ),
        .executable(
            name: "context-anchor",
            targets: ["ContextAnchorCLI"]
        )
    ],
    targets: [
        .target(
            name: "NangaCore",
            path: "nanga",
            sources: [
                "Core/ScopeResolution/FileDiscoveryService.swift",
                "Core/SignalExtraction/SkillMemoryInput.swift",
                "Core/SignalExtraction/SkillMemoryEntry.swift",
                "Core/SignalExtraction/SkillMemoryOutput.swift",
                "Core/SignalExtraction/SkillMemoryOptimizer.swift",
                "Features/TaskInput/TaskDraft.swift",
                "Features/SignalPanel/SignalItem.swift",
                "Features/ScopePanel/ScopeModels.swift"
            ]
        ),
        .testTarget(
            name: "NangaCoreTests",
            dependencies: ["NangaCore"],
            path: "nangaTests"
        ),
        .executableTarget(
            name: "ContextAnchorCLI",
            dependencies: ["NangaCore"],
            path: "SkillCLI"
        )
    ]
)
