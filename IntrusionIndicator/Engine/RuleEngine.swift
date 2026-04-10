import Foundation

final class RuleEngine {
    func evaluate(snapshot: SignalSnapshot, rules: [RuleDefinition], trust: TrustContext) -> [Finding] {
        var findings: [Finding] = []
        let now = Date()

        for rule in rules.filter(\.enabled).sorted(by: { $0.sortOrder < $1.sortOrder }) {
            let evidence = evidenceForRule(rule, snapshot: snapshot, trust: trust)
            guard !evidence.isEmpty else { continue }

            findings.append(
                Finding(
                    ruleID: rule.id,
                    severity: rule.severity,
                    title: rule.name,
                    message: rule.message,
                    evidence: evidence,
                    matchedAt: now,
                    confidence: confidence(for: rule),
                    remediation: rule.remediation
                )
            )
        }

        if !snapshot.limitedVisibilityReasons.isEmpty {
            let evidence = snapshot.limitedVisibilityReasons.map { EvidenceItem(label: "Visibility", value: $0) }
            findings.append(
                Finding(
                    ruleID: nil,
                    severity: .yellow,
                    title: "Visibility Is Limited",
                    message: "Some system surfaces could not be inspected. The app is being explicit about uncertainty instead of treating it as safe.",
                    evidence: evidence,
                    matchedAt: now,
                    confidence: 0.55,
                    remediation: "Grant Full Disk Access and keep the app running with normal user permissions."
                )
            )
        }

        return findings.sorted {
            if $0.severity == $1.severity {
                return $0.title < $1.title
            }
            return $0.severity > $1.severity
        }
    }

    func aggregateSeverity(for findings: [Finding]) -> Severity {
        findings.map(\.severity).max() ?? .green
    }

    private func evidenceForRule(_ rule: RuleDefinition, snapshot: SignalSnapshot, trust: TrustContext) -> [EvidenceItem] {
        switch rule.conditionType {
        case .serviceEnabled:
            return snapshot.serviceStates.compactMap { key, value in
                guard rule.parameters.serviceKeys.contains(key), value else { return nil }
                return EvidenceItem(label: "Service", value: key)
            }

        case .permissionGrant:
            let normalizedBundleIdentifiers = Set(rule.parameters.bundleIdentifiers.map { $0.lowercased() })
            return snapshot.permissions.compactMap { permission -> EvidenceItem? in
                guard permission.state == .allowed else { return nil }
                guard rule.parameters.permissionKinds.contains(permission.kind) else { return nil }
                if !normalizedBundleIdentifiers.isEmpty {
                    guard let bundleIdentifier = permission.bundleIdentifier?.lowercased() else { return nil }
                    guard normalizedBundleIdentifiers.contains(bundleIdentifier) else { return nil }
                }
                if rule.parameters.requireTrustedExemption,
                   trust.isTrusted(bundleIdentifier: permission.bundleIdentifier, processName: permission.client, endpoint: nil) {
                    return nil
                }
                return EvidenceItem(label: permission.kind.title, value: permission.client)
            }

        case .processMatch:
            return snapshot.processes.compactMap { process in
                guard match(patterns: rule.parameters.processPatterns, against: process.command) else {
                    return nil
                }
                if rule.parameters.requireTrustedExemption,
                   trust.isTrusted(bundleIdentifier: nil, processName: process.command, endpoint: nil) {
                    return nil
                }
                return EvidenceItem(label: "Process", value: "\(process.command) (\(process.pid))")
            }

        case .launchAgentMatch:
            return snapshot.launchAgents.compactMap { launchAgent in
                guard match(patterns: rule.parameters.launchAgentPatterns, against: launchAgent.label) else {
                    return nil
                }
                return EvidenceItem(label: "Launch Item", value: launchAgent.label)
            }

        case .listenerPort:
            return snapshot.listeningSockets.compactMap { socket in
                guard rule.parameters.ports.contains(socket.localPort) else { return nil }
                if rule.parameters.requireTrustedExemption,
                   trust.isTrusted(bundleIdentifier: nil, processName: socket.processName, endpoint: nil) {
                    return nil
                }
                return EvidenceItem(label: "Listener", value: "\(socket.processName) on \(socket.localPort)")
            }

        case .activeConnection:
            return snapshot.activeConnections.compactMap { connection in
                guard rule.parameters.ports.isEmpty || rule.parameters.ports.contains(connection.remotePort) else {
                    return nil
                }
                guard rule.parameters.endpoints.isEmpty || match(patterns: rule.parameters.endpoints, against: connection.remoteAddress) else {
                    return nil
                }
                guard rule.parameters.processPatterns.isEmpty || match(patterns: rule.parameters.processPatterns, against: connection.processName) else {
                    return nil
                }

                switch rule.parameters.connectionDirection {
                case .any:
                    break
                case .outbound:
                    guard connection.inferredDirection != .inbound else { return nil }
                case .inbound:
                    guard connection.inferredDirection != .outbound else { return nil }
                }

                if rule.parameters.requireTrustedExemption,
                   trust.isTrusted(bundleIdentifier: nil, processName: connection.processName, endpoint: connection.remoteAddress) {
                    return nil
                }
                return EvidenceItem(
                    label: "Connection",
                    value: "\(connection.processName) \(connection.localAddress):\(connection.localPort) -> \(connection.remoteAddress):\(connection.remotePort)"
                )
            }
        }
    }

    private func match(patterns: [String], against candidate: String) -> Bool {
        let lowercased = candidate.lowercased()
        return patterns.contains { pattern in
            lowercased.contains(pattern.lowercased())
        }
    }

    private func confidence(for rule: RuleDefinition) -> Double {
        switch rule.conditionType {
        case .serviceEnabled, .listenerPort:
            return 0.98
        case .permissionGrant:
            return 0.92
        case .processMatch, .activeConnection, .launchAgentMatch:
            return 0.8
        }
    }
}
