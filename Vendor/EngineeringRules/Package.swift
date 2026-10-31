// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "SwiftRules",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "swift-rules", targets: ["SwiftRules"])],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", exact: "604.0.0"),
    ],
    targets: [
        .target(name: "IndexStoreBridge", linkerSettings: [.linkedLibrary("dl", .when(platforms: [.linux]))]),
        .target(name: "SwiftRulesCore", dependencies: [
            .product(name: "SwiftSyntax", package: "swift-syntax"),
            .product(name: "SwiftParser", package: "swift-syntax"),
            .product(name: "SwiftParserDiagnostics", package: "swift-syntax"),
            .product(name: "SwiftOperators", package: "swift-syntax"),
        ]),
        .executableTarget(name: "SwiftRules", dependencies: ["SwiftRulesCore", "IndexStoreBridge"]),
    ],
    swiftLanguageModes: [.v6]
)
