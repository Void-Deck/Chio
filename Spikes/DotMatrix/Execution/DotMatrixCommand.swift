import SwiftTUI

package struct DotMatrixCommand {
    @OptionGroup package var swiftTUIOptions: SwiftTUIOptions

    package init() {}
}

extension DotMatrixCommand: AsyncParsableCommand {
    @MainActor
    package mutating func run() async throws {
        let application = try MatrixStudyApplication(scene: MatrixScene())
        try await WebHostCLIRunner.run(application, configuration: swiftTUIOptions.runtimeConfiguration())
    }
}
