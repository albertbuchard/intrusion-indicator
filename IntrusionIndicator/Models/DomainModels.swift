import AppKit
import Foundation

enum Severity: String, Codable, CaseIterable, Comparable, Sendable {
    case green
    case yellow
    case red

    static func < (lhs: Severity, rhs: Severity) -> Bool {
        lhs.rank < rhs.rank
    }

    var rank: Int {
        switch self {
        case .green:
            return 0
        case .yellow:
            return 1
        case .red:
            return 2
        }
    }

    var title: String {
        rawValue.capitalized
    }

    var tintColor: NSColor {
        switch self {
        case .green:
            return NSColor.systemGreen
        case .yellow:
            return NSColor.systemYellow
        case .red:
            return NSColor.systemRed
        }
    }
}

enum RuleCategory: String, Codable, CaseIterable, Sendable {
    case permissions
    case services
    case process
    case network
    case launchAgent
    case visibility
}

enum ConditionType: String, Codable, CaseIterable, Sendable {
    case permissionGrant
    case serviceEnabled
    case processMatch
    case listenerPort
    case activeConnection
    case launchAgentMatch
}

enum PermissionKind: String, Codable, CaseIterable, Sendable {
    case screenRecording
    case microphone
    case camera

    var tccServiceName: String {
        switch self {
        case .screenRecording:
            return "kTCCServiceScreenCapture"
        case .microphone:
            return "kTCCServiceMicrophone"
        case .camera:
            return "kTCCServiceCamera"
        }
    }

    var title: String {
        switch self {
        case .screenRecording:
            return "Screen Recording"
        case .microphone:
            return "Microphone"
        case .camera:
            return "Camera"
        }
    }
}

enum PermissionState: String, Codable, CaseIterable, Sendable {
    case allowed
    case denied
    case unknown
}

enum ConnectionDirection: String, Codable, CaseIterable, Sendable {
    case any
    case outbound
    case inbound
}

struct RuleParameters: Codable, Hashable, Sendable {
    var permissionKinds: [PermissionKind] = []
    var bundleIdentifiers: [String] = []
    var processPatterns: [String] = []
    var launchAgentPatterns: [String] = []
    var ports: [Int] = []
    var endpoints: [String] = []
    var serviceKeys: [String] = []
    var connectionDirection: ConnectionDirection = .any
    var requireTrustedExemption = false
}

struct RuleDefinition: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var enabled: Bool
    var name: String
    var category: RuleCategory
    var severity: Severity
    var conditionType: ConditionType
    var parameters: RuleParameters
    var message: String
    var remediation: String
    var seedSource: String
    var sortOrder: Int
    var lastMatchedAt: Date?
}

struct EvidenceItem: Identifiable, Hashable, Codable, Sendable {
    var id = UUID()
    var label: String
    var value: String
}

struct Finding: Identifiable, Hashable, Codable, Sendable {
    var id = UUID()
    var ruleID: UUID?
    var severity: Severity
    var title: String
    var message: String
    var evidence: [EvidenceItem]
    var matchedAt: Date
    var confidence: Double
    var remediation: String?
}

struct PermissionGrant: Identifiable, Hashable, Codable, Sendable {
    var id = UUID()
    var kind: PermissionKind
    var client: String
    var bundleIdentifier: String?
    var state: PermissionState
    var source: String
}

struct ObservedProcess: Identifiable, Hashable, Codable, Sendable {
    var id: Int { pid }
    var pid: Int
    var command: String
    var executablePath: String
}

struct LaunchAgentObservation: Identifiable, Hashable, Codable, Sendable {
    var id: String { label }
    var label: String
    var status: String
}

struct ListeningSocket: Identifiable, Hashable, Codable, Sendable {
    var id = UUID()
    var processName: String
    var pid: Int?
    var localAddress: String
    var localPort: Int
    var rawName: String
}

struct ActiveConnection: Identifiable, Hashable, Codable, Sendable {
    var id = UUID()
    var processName: String
    var pid: Int?
    var localAddress: String
    var localPort: Int
    var remoteAddress: String
    var remotePort: Int
    var state: String

    var inferredDirection: ConnectionDirection {
        let wellKnownRemotePorts: Set<Int> = [5900, 3389, 5938, 5939]

        if (remotePort < 1024 || wellKnownRemotePorts.contains(remotePort)), localPort > 1024 {
            return .outbound
        }
        if (localPort < 1024 || wellKnownRemotePorts.contains(localPort)), remotePort > 1024 {
            return .inbound
        }
        return .any
    }
}

struct SignalSnapshot: Hashable, Codable, Sendable {
    var collectedAt = Date()
    var serviceStates: [String: Bool] = [:]
    var permissions: [PermissionGrant] = []
    var processes: [ObservedProcess] = []
    var launchAgents: [LaunchAgentObservation] = []
    var listeningSockets: [ListeningSocket] = []
    var activeConnections: [ActiveConnection] = []
    var limitedVisibilityReasons: [String] = []
}

struct PartialSignalSnapshot: Hashable, Codable, Sendable {
    var serviceStates: [String: Bool] = [:]
    var permissions: [PermissionGrant] = []
    var processes: [ObservedProcess] = []
    var launchAgents: [LaunchAgentObservation] = []
    var listeningSockets: [ListeningSocket] = []
    var activeConnections: [ActiveConnection] = []
    var limitedVisibilityReasons: [String] = []

    func merged(into snapshot: inout SignalSnapshot) {
        snapshot.serviceStates.merge(serviceStates) { _, new in new }
        snapshot.permissions.append(contentsOf: permissions)
        snapshot.processes.append(contentsOf: processes)
        snapshot.launchAgents.append(contentsOf: launchAgents)
        snapshot.listeningSockets.append(contentsOf: listeningSockets)
        snapshot.activeConnections.append(contentsOf: activeConnections)
        snapshot.limitedVisibilityReasons.append(contentsOf: limitedVisibilityReasons)
    }
}

struct TrustContext: Hashable, Sendable {
    var trustedBundleIdentifiers: Set<String> = []
    var trustedProcessNames: Set<String> = []
    var trustedEndpoints: [String] = []

    func isTrusted(bundleIdentifier: String?, processName: String?, endpoint: String?) -> Bool {
        if let bundleIdentifier, trustedBundleIdentifiers.contains(bundleIdentifier.lowercased()) {
            return true
        }
        if let processName, trustedProcessNames.contains(processName.lowercased()) {
            return true
        }
        if let endpoint {
            return trustedEndpoints.contains(where: { pattern in
                endpoint.localizedCaseInsensitiveContains(pattern)
            })
        }
        return false
    }
}

struct ScanResult: Sendable {
    var snapshot: SignalSnapshot
    var findings: [Finding]
    var severity: Severity
}
