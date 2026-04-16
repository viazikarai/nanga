// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    // package identity can stay stable while the install surface uses context-anchor.
    name: "NangaCore",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        // reusable core library for integrations and tests.
        .library(
            name: "NangaCore",
            targets: ["NangaCore"]
        ),
        // user-facing install/run surface.
        .executable(
            name: "context-anchor",
            targets: ["ContextAnchorCLI"]
        )
    ],
    targets: [
        // skill core only; ui/app surfaces were removed intentionally.
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
        // thin cli wrapper around the core optimizer.
        .executableTarget(
            name: "ContextAnchorCLI",
            dependencies: ["NangaCore"],
            path: "SkillCLI"
        )
    ]
)
