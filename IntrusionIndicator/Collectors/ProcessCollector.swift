import Foundation

struct ProcessCollector: SignalCollector {
    private let runner = ShellCommandRunner()

    func collect() async throws -> PartialSignalSnapshot {
        var partial = PartialSignalSnapshot()

        do {
            let processResult = try runner.run("/bin/ps", arguments: ["-axo", "pid=,comm="])
            partial.processes = Self.parseProcessList(processResult.standardOutput)
        } catch {
            partial.limitedVisibilityReasons.append("Unable to inspect running processes: \(error.localizedDescription)")
        }

        do {
            let launchctlResult = try runner.run("/bin/launchctl", arguments: ["list"])
            partial.launchAgents = Self.parseLaunchAgents(launchctlResult.standardOutput)
        } catch {
            partial.limitedVisibilityReasons.append("Unable to inspect launch agents: \(error.localizedDescription)")
        }

        return partial
    }

    static func parseProcessList(_ output: String) -> [ObservedProcess] {
        output
            .split(separator: "\n")
            .compactMap { line -> ObservedProcess? in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return nil }
                let components = trimmed.split(maxSplits: 1, whereSeparator: \.isWhitespace)
                guard components.count == 2, let pid = Int(components[0]) else { return nil }
                let path = String(components[1]).trimmingCharacters(in: .whitespaces)
                let command = URL(fileURLWithPath: path).lastPathComponent
                return ObservedProcess(pid: pid, command: command, executablePath: path)
            }
    }

    static func parseLaunchAgents(_ output: String) -> [LaunchAgentObservation] {
        output
            .split(separator: "\n")
            .compactMap { line -> LaunchAgentObservation? in
                let parts = line.split(separator: "\t").map(String.init)
                guard let label = parts.last, !label.isEmpty else {
                    return nil
                }
                let status = parts.dropLast().joined(separator: "\t")
                return LaunchAgentObservation(label: label, status: status)
            }
    }
}
