// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "Chio",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "Chio", targets: ["Chio"]),
        .executable(name: "chio-dashboard", targets: ["ChioDashboard"]),
        .executable(name: "chio-maps", targets: ["ChioMaps"]),
    ],
    dependencies: [
        // Qualification candidate: merged #58/#59 plus the callback-scope fix (#60).
        .package(
            url: "https://github.com/SwiftTUI/swift-tui.git",
            revision: "16c8368746765e6fa9543c9d4d0e822cd84f3bc3"
        ),
        // Swift Markdown 0.9.0. A revision pin also permits its conditional
        // Windows build flags without modifying the upstream package.
        .package(
            url: "https://github.com/swiftlang/swift-markdown.git",
            revision: "25cb61d3482054b09ae76ca4f281b1bfe7fe5a43"
        ),
        // Tree-sitter 0.26.13: the last release with an upstream SwiftPM manifest.
        .package(
            url: "https://github.com/tree-sitter/tree-sitter.git",
            revision: "d97971e24500218865c05ed1febdee2acf41bae1"
        ),
        // Swift grammar 0.7.4, including generated C sources (no generator needed).
        .package(
            url: "https://github.com/alex-pinkus/tree-sitter-swift.git",
            revision: "82bb3a533e0801fd2bbaa11dc49676e10bf41948"
        ),
    ],
    targets: [
        .executableTarget(
            name: "RouteReadability",
            dependencies: ["Chio", .product(name: "SwiftTUI", package: "swift-tui")],
            path: "Spikes/MapRouting",
            exclude: ["README.md"],
            resources: [.copy("Fixtures")]
        ),
        // Private POSIX bridge; no additional public library product.
        .target(name: "ChioFileSystem"),
        .target(
            name: "Chio",
            dependencies: [
                "ChioFileSystem",
                .product(name: "SwiftTUIViews", package: "swift-tui"),
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "TreeSitter", package: "tree-sitter"),
                .product(name: "TreeSitterSwift", package: "tree-sitter-swift"),
            ],
            exclude: [
                "README.md",
                "Composition/README.md",
                "DurationText/README.md",
                "FilePicker/README.md",
                "Forms/README.md",
                "HistoryChart/README.md",
                "InstrumentReadout/README.md",
                "KeyHint/README.md",
                "KeyHints/README.md",
                "KeyboardHelp/README.md",
                "Maps/README.md",
                "Markdown/README.md",
                "MeasurementGauge/README.md",
                "Pagination/README.md",
                "SearchableChecklist/README.md",
                "SearchableList/README.md",
                "Sparkline/README.md",
            ]
        ),
        .executableTarget(
            name: "ChioDashboard",
            dependencies: [
                "Chio",
                .product(name: "SwiftTUI", package: "swift-tui"),
            ],
            path: "Examples/AgentDashboard",
            exclude: ["README.md"]
        ),
        .testTarget(
            name: "ChioTests",
            dependencies: [
                "Chio",
                .product(name: "SwiftTUIRuntime", package: "swift-tui"),
            ]
        ),
        .testTarget(
            name: "ChioMapTests",
            dependencies: [
                "ChioMaps",
                "Chio",
                .product(name: "SwiftTUIRuntime", package: "swift-tui"),
            ]
        ),
        .executableTarget(
            name: "ChioMaps",
            dependencies: [
                "Chio",
                .product(name: "SwiftTUI", package: "swift-tui"),
            ],
            path: "Examples/Maps",
            exclude: ["README.md"],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(
            name: "ChioDashboardTests",
            dependencies: [
                "ChioDashboard",
                .product(name: "SwiftTUIRuntime", package: "swift-tui"),
            ]
        ),
    ]
)
