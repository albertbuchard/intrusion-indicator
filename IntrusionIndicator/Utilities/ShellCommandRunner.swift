import Foundation

struct CommandResult: Sendable {
    var standardOutput: String
    var standardError: String
    var exitCode: Int32
}

enum CommandError: Error {
    case launchFailed(String)
    case nonZeroExit(code: Int32, standardError: String)
}

struct ShellCommandRunner: Sendable {
    func run(_ executable: String, arguments: [String]) throws -> CommandResult {
        let session = CommandDiagnostics.currentScanSession()
        let start = DispatchTime.now()
        CommandDiagnostics.logCommandStart(
            executable: executable,
            arguments: arguments,
            session: session
        )

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            let duration = durationMs(since: start)
            CommandDiagnostics.logCommandFailure(
                executable: executable,
                arguments: arguments,
                durationMs: duration,
                error: error,
                session: session
            )
            throw CommandError.launchFailed(error.localizedDescription)
        }

        process.waitUntilExit()

        let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
        let result = CommandResult(
            standardOutput: String(decoding: outputData, as: UTF8.self),
            standardError: String(decoding: errorData, as: UTF8.self),
            exitCode: process.terminationStatus
        )

        let durationMs = durationMs(since: start)
        CommandDiagnostics.logCommandResult(
            executable: executable,
            arguments: arguments,
            exitCode: result.exitCode,
            durationMs: durationMs,
            outputBytes: outputData.count,
            errorBytes: errorData.count,
            session: session
        )

        guard result.exitCode == 0 else {
            throw CommandError.nonZeroExit(code: result.exitCode, standardError: result.standardError)
        }

        return result
    }

    private func durationMs(since start: DispatchTime) -> Int64 {
        let end = DispatchTime.now()
        let elapsed = end.uptimeNanoseconds - start.uptimeNanoseconds
        return Int64(elapsed / 1_000_000)
    }
}
