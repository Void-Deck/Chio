import SwiftTUI

package struct DotMatrixCommand {
    @Option(help: "Starting theme: default, light or btop.")
    var theme: MatrixTheme = .default

    @Flag(help: "Explore a larger RGB matrix in a native two-axis scroll view.")
    var viewport = false

    @OptionGroup package var swiftTUIOptions: SwiftTUIOptions

    package init() {}
}

extension DotMatrixCommand: AsyncParsableCommand {
    @MainActor
    package mutating func run() async throws {
        let application = try MatrixApplication(scene: MatrixScene(), theme: theme, isViewport: viewport)
        try await WebHostCLIRunner.run(application, configuration: swiftTUIOptions.runtimeConfiguration())
    }
}
