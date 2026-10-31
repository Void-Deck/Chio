import Foundation
import Dispatch
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

struct ProcessRunner {
    struct Output {
        let status: Int32
        let text: String
    }
    static func run(executable: URL, arguments: [String], environment: [String: String]? = nil, directory: URL) throws -> Output {
        let process = Process()
        let output = Pipe()
        process.executableURL = executable
        process.arguments = arguments
        process.currentDirectoryURL = directory
        process.environment = environment
        process.standardOutput = output
        process.standardError = FileHandle.standardError
        try process.run()
        let timeout = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        timeout.schedule(deadline: .now() + 120)
        timeout.setEventHandler {
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        }
        timeout.resume()
        defer { timeout.cancel() }
        var data = Data()
        while true {
            let chunk = output.fileHandleForReading.availableData
            if chunk.isEmpty { break }
            let isWithinOutputBound = chunk.count <= 16 * 1024 * 1024 - data.count
            guard isWithinOutputBound else {
                if process.isRunning { kill(process.processIdentifier, SIGKILL) }
                process.waitUntilExit()
                throw ToolFailure.invalid("Tool output exceeds 16 MiB")
            }
            data.append(chunk)
        }
        process.waitUntilExit()
        guard process.terminationReason == .exit else { throw ToolFailure.invalid("Tool terminated by a signal or exceeded its 120-second limit") }
        guard let text = String(data: data, encoding: .utf8) else { throw ToolFailure.invalid("Invalid UTF-8 output from \(executable.lastPathComponent)") }
        return Output(status: process.terminationStatus, text: text)
    }
}
