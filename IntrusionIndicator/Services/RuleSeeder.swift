import Foundation
import SwiftData

enum RuleSeeder {
    static let customRuleSource = "Custom Rule"

    static func seedIfNeeded(in context: ModelContext) throws {
        let existingRules = try context.fetch(FetchDescriptor<RuleRecord>())
        try seedOrSyncRules(existingRules: existingRules, in: context)
    }

    static func seedOrSyncRules(existingRules: [RuleRecord], in context: ModelContext) throws {
        var existingByID: [UUID: RuleRecord] = [:]
        for existingRule in existingRules {
            existingByID[existingRule.id] = existingRule
        }
        var inserted = false

        for rule in seededRules() {
            guard existingByID[rule.id] == nil else {
                continue
            }
            context.insert(ruleRecord(from: rule))
            inserted = true
        }

        if inserted {
            try context.save()
        }
    }

    private static func ruleRecord(from definition: RuleDefinition) -> RuleRecord {
        RuleRecord(
            id: definition.id,
            enabled: definition.enabled,
            name: definition.name,
            category: definition.category,
            severity: definition.severity,
            conditionType: definition.conditionType,
            parameters: definition.parameters,
            message: definition.message,
            remediation: definition.remediation,
            seedSource: definition.seedSource,
            sortOrder: definition.sortOrder
        )
    }

    static func seededRules() -> [RuleDefinition] {
        [
            RuleDefinition(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000001") ?? UUID(),
                enabled: true,
                name: "Screen Sharing Enabled",
                category: .services,
                severity: .red,
                conditionType: .serviceEnabled,
                parameters: RuleParameters(serviceKeys: ["screenSharing"]),
                message: "Screen Sharing is enabled on this Mac, which exposes a direct path for someone else to view your screen if they can authenticate.",
                remediation: "Turn off Screen Sharing in System Settings > General > Sharing unless you actively need it.",
                seedSource: "User-provided guidance",
                sortOrder: 10
            ),
            RuleDefinition(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000002") ?? UUID(),
                enabled: true,
                name: "Remote Management Enabled",
                category: .services,
                severity: .red,
                conditionType: .serviceEnabled,
                parameters: RuleParameters(serviceKeys: ["remoteManagement"]),
                message: "Apple Remote Management appears to be enabled, which can permit remote observation or control of the Mac.",
                remediation: "Turn off Remote Management unless it is intentionally managed.",
                seedSource: "User-provided guidance",
                sortOrder: 20
            ),
            RuleDefinition(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000009") ?? UUID(),
                enabled: true,
                name: "Remote Login Enabled",
                category: .services,
                severity: .yellow,
                conditionType: .serviceEnabled,
                parameters: RuleParameters(serviceKeys: ["remoteLogin"]),
                message: "SSH-based remote login appears enabled. SSH can be a legitimate admin tool, but it also enables remote interactive access.",
                remediation: "Disable Remote Login in System Settings > General > Sharing unless you actively need shell access from other machines.",
                seedSource: "User-provided guidance",
                sortOrder: 25
            ),
            RuleDefinition(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000003") ?? UUID(),
                enabled: true,
                name: "Untrusted Screen Recording Permission",
                category: .permissions,
                severity: .red,
                conditionType: .permissionGrant,
                parameters: RuleParameters(permissionKinds: [.screenRecording], requireTrustedExemption: true),
                message: "An untrusted app currently has Screen Recording permission. That does not prove live viewing, but it is enough capability to capture your display.",
                remediation: "Review System Settings > Privacy & Security > Screen Recording and revoke anything you do not trust.",
                seedSource: "User-provided guidance",
                sortOrder: 30
            ),
            RuleDefinition(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000004") ?? UUID(),
                enabled: true,
                name: "Untrusted Microphone Permission",
                category: .permissions,
                severity: .yellow,
                conditionType: .permissionGrant,
                parameters: RuleParameters(permissionKinds: [.microphone], requireTrustedExemption: true),
                message: "An untrusted app currently has microphone access. This is a meaningful capture capability and should be reviewed.",
                remediation: "Review microphone permissions and remove unknown apps from the allowlist.",
                seedSource: "User-provided guidance",
                sortOrder: 40
            ),
            RuleDefinition(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000005") ?? UUID(),
                enabled: true,
                name: "Untrusted Camera Permission",
                category: .permissions,
                severity: .yellow,
                conditionType: .permissionGrant,
                parameters: RuleParameters(permissionKinds: [.camera], requireTrustedExemption: true),
                message: "An untrusted app currently has camera access. This is not proof of active spying, but it means the app can capture video.",
                remediation: "Review camera permissions and remove unknown apps from the allowlist.",
                seedSource: "User-provided guidance",
                sortOrder: 45
            ),
            RuleDefinition(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000023") ?? UUID(),
                enabled: true,
                name: "Remote Desktop Server Port Listening",
                category: .network,
                severity: .red,
                conditionType: .listenerPort,
                parameters: RuleParameters(ports: [5900, 3389, 5938], requireTrustedExemption: true),
                message: "A common remote-control server port is listening locally. That is materially stronger evidence than a passive permission grant.",
                remediation: "Stop the service or app behind the listening port if you did not intentionally expose it.",
                seedSource: "User-provided guidance",
                sortOrder: 50
            ),
            RuleDefinition(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000010") ?? UUID(),
                enabled: true,
                name: "SSH Daemon Listening",
                category: .network,
                severity: .yellow,
                conditionType: .listenerPort,
                parameters: RuleParameters(ports: [22], requireTrustedExemption: true),
                message: "The SSH service is exposing a listening TCP 22 socket. SSH can be legitimate but materially increases remote access risk.",
                remediation: "Disable Remote Login if you are not expecting inbound SSH, or restrict it with firewall and key-based controls.",
                seedSource: "User-provided guidance",
                sortOrder: 55
            ),
            RuleDefinition(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000011") ?? UUID(),
                enabled: true,
                name: "Remote Access Port Listening",
                category: .network,
                severity: .yellow,
                conditionType: .listenerPort,
                parameters: RuleParameters(ports: [21114, 21115, 21116, 21117, 21118, 5800, 5801, 7070], requireTrustedExemption: true),
                message: "A listener is active on a port commonly used by remote-access helper apps (AnyDesk, RustDesk, and related tools).",
                remediation: "Verify the owning process in the system monitor and disable any unexpected service.",
                seedSource: "User-provided guidance",
                sortOrder: 58
            ),
            RuleDefinition(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000006") ?? UUID(),
                enabled: true,
                name: "Outbound Remote Access Session",
                category: .network,
                severity: .red,
                conditionType: .activeConnection,
                parameters: RuleParameters(
                    processPatterns: ["screen", "screensharingagent", "teamviewer", "anydesk", "rustdesk", "vnc", "vncserver", "splashtop", "bomgar", "parsec", "remotedesktop", "nomachine", "todesk"],
                    ports: [5900, 3389, 5938, 5939],
                    connectionDirection: .outbound,
                    requireTrustedExemption: true
                ),
                message: "An outbound session on common remote-access ports is active. This may represent active screen or remote support activity.",
                remediation: "Confirm each session is expected, including software and destination. Stop unrecognized sessions immediately.",
                seedSource: "User-provided guidance",
                sortOrder: 60
            ),
            RuleDefinition(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000018") ?? UUID(),
                enabled: true,
                name: "Outbound VNC Viewer Session",
                category: .network,
                severity: .red,
                conditionType: .activeConnection,
                parameters: RuleParameters(
                    processPatterns: ["screen", "screensharingagent", "vnc", "vncserver", "teamviewer", "anydesk", "rustdesk", "parsec", "todesk", "remotedesktop", "remotedesk"],
                    ports: [5900, 3389, 5938, 5939],
                    connectionDirection: .outbound,
                    requireTrustedExemption: true
                ),
                message: "An outbound VNC-style remote access session is active. This is typically user-driven support or screen-sharing activity.",
                remediation: "Stop unknown outbound remote sessions and verify whether the connected peer is authorized.",
                seedSource: "User-provided guidance",
                sortOrder: 61
            ),
            RuleDefinition(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000012") ?? UUID(),
                enabled: true,
                name: "Inbound Remote Access Session",
                category: .network,
                severity: .red,
                conditionType: .activeConnection,
                parameters: RuleParameters(
                    processPatterns: ["screensharingagent", "teamviewer", "anydesk", "rustdesk", "vnc", "vncserver", "splashtop", "bomgar", "parsec", "remotedesktop", "nomachine", "todesk"],
                    ports: [22, 3389, 5900, 5938, 5939],
                    connectionDirection: .inbound,
                    requireTrustedExemption: true
                ),
                message: "An inbound remote-access-style connection is active. This is a stronger signal that another party may be interacting with this machine.",
                remediation: "Terminate unexpected inbound sessions and verify local accounts, firewall policy, and trusted automation tools.",
                seedSource: "User-provided guidance",
                sortOrder: 62
            ),
            RuleDefinition(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000013") ?? UUID(),
                enabled: true,
                name: "Potential Remote Tunnel Session",
                category: .network,
                severity: .yellow,
                conditionType: .activeConnection,
                parameters: RuleParameters(
                    processPatterns: ["ssh", "autossh", "frpc", "frps", "cloudflared", "tailscale", "wireguard-go", "n2n", "tailscaled"],
                    ports: [22, 80, 443, 8080, 3000, 4443],
                    connectionDirection: .outbound,
                    requireTrustedExemption: true
                ),
                message: "An outbound connection from a tunneling or support helper is active. This can indicate traffic being bridged to a remote operator.",
                remediation: "Review the helper process and active sessions; stop/disable services that were not explicitly started by you.",
                seedSource: "User-provided guidance",
                sortOrder: 64
            ),
            RuleDefinition(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000014") ?? UUID(),
                enabled: true,
                name: "Known Remote Control Tool Running",
                category: .process,
                severity: .red,
                conditionType: .processMatch,
                parameters: RuleParameters(
                    processPatterns: [
                        "teamviewer", "anydesk", "screenconnect", "splashtop", "bomgar", "beyondtrust", "logmein", "connectwise", "rescue",
                        "rustdesk", "parsec", "todesk", "vnc", "nomachine", "remotedesktop", "chrome-remote-desktop", "ultravnc", "vncserver", "to-desktop"
                    ]
                ),
                message: "A known remote-control tool is running. This does not automatically mean abuse, but it is strong enough to warrant attention.",
                remediation: "Quit or remove the tool if you did not start it intentionally.",
                seedSource: "User-provided guidance",
                sortOrder: 70
            ),
            RuleDefinition(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000015") ?? UUID(),
                enabled: true,
                name: "Potential Screen Capture Utility Running",
                category: .process,
                severity: .yellow,
                conditionType: .processMatch,
                parameters: RuleParameters(
                    processPatterns: [
                        "obs", "obs64", "camtasia", "screenflick", "screenflow", "snagit", "quicktime", "screencapture", "recordmydesktop", "wirecast", "ffmpeg"
                    ]
                ),
                message: "A process commonly used for local capture/recording is running, which can indicate covert recording if expected behavior is unclear.",
                remediation: "Verify who launched it and whether it is actively recording or streaming.",
                seedSource: "User-provided guidance",
                sortOrder: 75
            ),
            RuleDefinition(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000016") ?? UUID(),
                enabled: true,
                name: "Suspicious Remote Access Pattern",
                category: .launchAgent,
                severity: .yellow,
                conditionType: .launchAgentMatch,
                parameters: RuleParameters(
                    launchAgentPatterns: [
                        "remote", "remoteassist", "screenconnect", "assist", "viewer", "splashtop", "bomgar", "anydesk", "teamviewer", "citrix",
                        "tailscale", "vnc", "remotedesktop", "rustdesk", "parsec", "todesk", "nomachine", "ultravnc", "vncserver", "jumpcloud", "teleport"
                    ]
                ),
                message: "A launch item or background service name matches common remote-access patterns. This is a heuristic warning, not proof of compromise.",
                remediation: "Review the launch item and trust-list it if it is expected in your environment.",
                seedSource: "User-provided guidance",
                sortOrder: 80
            ),
            RuleDefinition(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000019") ?? UUID(),
                enabled: true,
                name: "Radmin/Remote Admin Port Listening",
                category: .network,
                severity: .yellow,
                conditionType: .listenerPort,
                parameters: RuleParameters(ports: [4899], requireTrustedExemption: true),
                message: "A process is listening on TCP 4899, frequently used by legacy remote-administration software.",
                remediation: "Close the owner application and disable any remote-admin module unless it is explicitly required.",
                seedSource: "User-provided guidance",
                sortOrder: 81
            ),
            RuleDefinition(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000017") ?? UUID(),
                enabled: true,
                name: "Legacy VNC Daemon Running",
                category: .process,
                severity: .yellow,
                conditionType: .processMatch,
                parameters: RuleParameters(
                    processPatterns: [
                        "x11vnc", "tightvnc", "vncserver", "xvnc", "turbovnc", "vncs", "vncserver-x11",
                        "vncserver2", "uvnc", "realvnc", "to-desktop"
                    ],
                    requireTrustedExemption: true
                ),
                message: "A legacy VNC daemon process is running. These services can expose live screen access depending on configuration.",
                remediation: "Stop and remove legacy VNC services unless required for intentional remote administration.",
                seedSource: "User-provided guidance",
                sortOrder: 82
            ),
            RuleDefinition(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000020") ?? UUID(),
                enabled: true,
                name: "WebRTC/Webcast Capture Helper Running",
                category: .process,
                severity: .yellow,
                conditionType: .processMatch,
                parameters: RuleParameters(
                    processPatterns: [
                        "obs", "obs64", "camtasia", "screenflick", "screenflow", "xsplit", "snagit",
                        "streamlabs", "ecamm", "wirecast", "ffmpeg", "quicktime"
                    ],
                    requireTrustedExemption: true
                ),
                message: "A desktop capture or streaming helper is active. If unexpected, it could indicate covert recording or camera/screen forwarding.",
                remediation: "Confirm this process is expected and check for active recording/streaming sessions.",
                seedSource: "User-provided guidance",
                sortOrder: 83
            ),
            RuleDefinition(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000021") ?? UUID(),
                enabled: true,
                name: "Potential Remote Tunnel Relay",
                category: .network,
                severity: .yellow,
                conditionType: .activeConnection,
                parameters: RuleParameters(
                    processPatterns: ["cloudflared", "ngrok", "frpc", "frps", "bore", "sshuttle", "ncat", "socat"],
                    ports: [80, 443, 8443, 8080],
                    connectionDirection: .outbound,
                    requireTrustedExemption: true
                ),
                message: "An outbound relay/tunnel-style process has an active connection through common bypass ports.",
                remediation: "Review tunnel processes and endpoints. Keep tunneling tools off unless you intentionally use them.",
                seedSource: "User-provided guidance",
                sortOrder: 84
            ),
            RuleDefinition(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000022") ?? UUID(),
                enabled: true,
                name: "Cloud Access Session Process",
                category: .process,
                severity: .yellow,
                conditionType: .processMatch,
                parameters: RuleParameters(
                    processPatterns: [
                        "rustdesk", "remotedesktop", "splashtop", "todesk", "to-desktop", "parsec", "chrome-remote-desktop",
                        "radmin", "kaseya", "dameware", "logmein", "beyondtrust", "screenconnect"
                    ],
                    requireTrustedExemption: true
                ),
                message: "A process tied to remote-support infrastructure is currently running and may allow live operator access.",
                remediation: "Quarantine unexpected remote-support processes and remove auto-start items.",
                seedSource: "User-provided guidance",
                sortOrder: 85
            )
        ]
    }
}
