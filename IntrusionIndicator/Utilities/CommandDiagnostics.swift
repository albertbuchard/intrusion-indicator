import Foundation
import os.log

struct CommandDiagnostics {
    private static let loggerSubsystem = "com.albertbuchard.IntrusionIndicator"

    #if DEBUG
    private static let logger = Logger(subsystem: loggerSubsystem, category: "commands")
    @TaskLocal
    static var scanSessionID: String?
    #endif

    static var isEnabled: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    static func withScanSession<T>(_ session: String, operation: () async throws -> T) async rethrows -> T {
        #if DEBUG
        return try await $scanSessionID.withValue(session, operation: operation)
        #else
        return try await operation()
        #endif
    }

    static func currentScanSession() -> String? {
        #if DEBUG
        scanSessionID
        #else
        nil
        #endif
    }

    static func commandLine(executable: String, arguments: [String]) -> String {
        let escapedArguments = arguments.map { argument in
            if argument.contains(" ") || argument.contains("\"") {
                return "\"\(argument.replacingOccurrences(of: "\"", with: "\\\""))\""
            }
            return argument
        }
        return ([executable] + escapedArguments).joined(separator: " ")
    }

    static func logCommandStart(executable: String, arguments: [String], session: String?) {
        #if DEBUG
        let commandLine = commandLine(executable: executable, arguments: arguments)
        let sessionTag = session ?? "unscoped"
        logger.debug("[scan-session:\(sessionTag, privacy: .public)] START \(commandLine, privacy: .public)")
        #endif
    }

    static func logCommandResult(
        executable: String,
        arguments: [String],
        exitCode: Int32,
        durationMs: Int64,
        outputBytes: Int,
        errorBytes: Int,
        session: String?
    ) {
        #if DEBUG
        let commandLine = commandLine(executable: executable, arguments: arguments)
        let sessionTag = session ?? "unscoped"
        logger.debug(
            "[scan-session:\(sessionTag, privacy: .public)] END \(commandLine, privacy: .public) " +
            "exit=\(exitCode, privacy: .public) " +
            "durationMs=\(durationMs, privacy: .public) " +
            "out=\(outputBytes, privacy: .public)B " +
            "err=\(errorBytes, privacy: .public)B"
        )
        #endif
    }

    static func logCommandFailure(
        executable: String,
        arguments: [String],
        durationMs: Int64?,
        error: Error,
        session: String?
    ) {
        #if DEBUG
        let commandLine = commandLine(executable: executable, arguments: arguments)
        let sessionTag = session ?? "unscoped"
        if let durationMs {
            logger.error(
                "[scan-session:\(sessionTag, privacy: .public)] FAIL \(commandLine, privacy: .public) " +
                "durationMs=\(durationMs, privacy: .public) " +
                "error=\(error.localizedDescription, privacy: .public)"
            )
        } else {
            logger.error(
                "[scan-session:\(sessionTag, privacy: .public)] FAIL \(commandLine, privacy: .public) " +
                "error=\(error.localizedDescription, privacy: .public)"
            )
        }
        #endif
    }
}
