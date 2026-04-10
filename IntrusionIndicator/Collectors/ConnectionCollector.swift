import Foundation

struct ConnectionCollector: SignalCollector {
    private let runner = ShellCommandRunner()

    func collect() async throws -> PartialSignalSnapshot {
        var partial = PartialSignalSnapshot()

        do {
            let result = try runner.run("/usr/sbin/lsof", arguments: ["-nP", "-iTCP", "-sTCP:ESTABLISHED"])
            partial.activeConnections = Self.parseEstablishedConnections(result.standardOutput)
        } catch let CommandError.nonZeroExit(code, standardError) where code == 1 {
            let errorText = standardError.trimmingCharacters(in: .whitespacesAndNewlines)
            if !errorText.isEmpty {
                partial.limitedVisibilityReasons.append("Active connection inspection returned no usable data: \(errorText)")
            }
        } catch {
            partial.limitedVisibilityReasons.append("Unable to inspect active connections: \(error.localizedDescription)")
        }

        return partial
    }

    static func parseEstablishedConnections(_ output: String) -> [ActiveConnection] {
        output
            .split(separator: "\n")
            .dropFirst()
            .compactMap { line -> ActiveConnection? in
                let normalized = line.replacingOccurrences(of: "\t", with: " ")
                let columns = normalized.split(whereSeparator: \.isWhitespace)
                guard columns.count >= 9 else { return nil }

                let processName = String(columns[0])
                let pid = Int(columns[1])
                let name = String(columns[8...].joined(separator: " "))
                guard let parsed = parseEndpointPair(name) else { return nil }

                return ActiveConnection(
                    processName: processName,
                    pid: pid,
                    localAddress: parsed.localAddress,
                    localPort: parsed.localPort,
                    remoteAddress: parsed.remoteAddress,
                    remotePort: parsed.remotePort,
                    state: parsed.state
                )
            }
    }

    private static func parseEndpointPair(_ raw: String) -> (localAddress: String, localPort: Int, remoteAddress: String, remotePort: Int, state: String)? {
        let trimmed = raw.replacingOccurrences(of: " (ESTABLISHED)", with: "")
        let pieces = trimmed.components(separatedBy: "->")
        guard pieces.count == 2 else { return nil }
        guard let local = parseEndpoint(pieces[0]), let remote = parseEndpoint(pieces[1]) else {
            return nil
        }
        return (local.address, local.port, remote.address, remote.port, "ESTABLISHED")
    }

    private static func parseEndpoint(_ raw: String) -> (address: String, port: Int)? {
        guard let index = raw.lastIndex(of: ":") else { return nil }
        let address = String(raw[..<index])
        let portString = String(raw[raw.index(after: index)...])
        guard let port = Int(portString) else { return nil }
        return (address, port)
    }
}
