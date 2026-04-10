import Foundation

struct SharingCollector: SignalCollector {
    private let runner = ShellCommandRunner()

    func collect() async throws -> PartialSignalSnapshot {
        var partial = PartialSignalSnapshot()

        do {
            let disabled = try runner.run("/bin/launchctl", arguments: ["print-disabled", "system"])
            partial.serviceStates["screenSharing"] = Self.parseDisabledState(
                output: disabled.standardOutput,
                label: "com.apple.screensharing"
            )
            partial.serviceStates["remoteManagement"] = Self.parseDisabledState(
                output: disabled.standardOutput,
                label: "com.apple.RemoteDesktop.agent"
            )
            partial.serviceStates["remoteLogin"] = Self.parseDisabledState(
                output: disabled.standardOutput,
                label: "com.openssh.sshd"
            )
        } catch {
            partial.limitedVisibilityReasons.append("Unable to inspect sharing services: \(error.localizedDescription)")
        }

        return partial
    }

    static func parseDisabledState(output: String, label: String) -> Bool {
        let normalized = label.replacingOccurrences(of: ".", with: "\\.")
        let pattern = "\"\(normalized)\"\\s*=>\\s*(true|false)"
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)),
            let range = Range(match.range(at: 1), in: output)
        else {
            return false
        }

        let isDisabled = String(output[range]) == "true"
        return !isDisabled
    }
}
