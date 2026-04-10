import Foundation

struct SocketCollector: SignalCollector {
    private let runner = ShellCommandRunner()

    func collect() async throws -> PartialSignalSnapshot {
        var partial = PartialSignalSnapshot()

        do {
            let result = try runner.run("/usr/sbin/lsof", arguments: ["-nP", "-iTCP", "-sTCP:LISTEN"])
            partial.listeningSockets = Self.parseListeningSockets(result.standardOutput)
        } catch let CommandError.nonZeroExit(code, standardError) where code == 1 {
            let errorText = standardError.trimmingCharacters(in: .whitespacesAndNewlines)
            if !errorText.isEmpty {
                partial.limitedVisibilityReasons.append("Listening socket inspection returned no usable data: \(errorText)")
            }
        } catch {
            partial.limitedVisibilityReasons.append("Unable to inspect listening sockets: \(error.localizedDescription)")
        }

        return partial
    }

    static func parseListeningSockets(_ output: String) -> [ListeningSocket] {
        output
            .split(separator: "\n")
            .dropFirst()
            .compactMap { line -> ListeningSocket? in
                let normalized = line.replacingOccurrences(of: "\t", with: " ")
                let columns = normalized.split(whereSeparator: \.isWhitespace)
                guard columns.count >= 9 else { return nil }

                let processName = String(columns[0])
                let pid = Int(columns[1])
                let name = String(columns[8...].joined(separator: " "))
                guard let port = portFromName(name) else { return nil }

                let address = name.components(separatedBy: ":").dropLast().joined(separator: ":")
                return ListeningSocket(
                    processName: processName,
                    pid: pid,
                    localAddress: address.isEmpty ? "*" : address,
                    localPort: port,
                    rawName: name
                )
            }
    }

    private static func portFromName(_ name: String) -> Int? {
        guard let portComponent = name.split(separator: ":").last else {
            return nil
        }
        let cleaned = portComponent.replacingOccurrences(of: " (LISTEN)", with: "")
        return Int(cleaned)
    }
}
