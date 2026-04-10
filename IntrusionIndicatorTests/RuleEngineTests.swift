import XCTest
@testable import IntrusionIndicator

final class RuleEngineTests: XCTestCase {
    private let engine = RuleEngine()

    func testOutboundVNCViewerProducesYellowFinding() {
        let rules = RuleSeeder.seededRules()
        let trust = TrustContext()
        let snapshot = SignalSnapshot(
            serviceStates: [:],
            permissions: [],
            processes: [],
            launchAgents: [],
            listeningSockets: [],
            activeConnections: [
                ActiveConnection(
                    processName: "Screen",
                    pid: 32401,
                    localAddress: "100.116.232.12",
                    localPort: 60269,
                    remoteAddress: "100.96.75.87",
                    remotePort: 5900,
                    state: "ESTABLISHED"
                )
            ],
            limitedVisibilityReasons: []
        )

        let findings = engine.evaluate(snapshot: snapshot, rules: rules, trust: trust)
        XCTAssertEqual(engine.aggregateSeverity(for: findings), .yellow)
        XCTAssertTrue(findings.contains(where: { $0.title == "Outbound VNC Viewer Session" }))
    }

    func testCitrixWithoutScreenRecordingDoesNotProduceRedFinding() {
        let rules = RuleSeeder.seededRules()
        let snapshot = SignalSnapshot(
            serviceStates: [:],
            permissions: [],
            processes: [
                ObservedProcess(pid: 99, command: "Citrix Workspace", executablePath: "/Applications/Citrix Workspace.app/Contents/MacOS/Citrix Workspace")
            ],
            launchAgents: [
                LaunchAgentObservation(label: "com.citrix.AuthManager_Mac", status: "-")
            ],
            listeningSockets: [],
            activeConnections: [],
            limitedVisibilityReasons: []
        )

        let findings = engine.evaluate(snapshot: snapshot, rules: rules, trust: TrustContext())
        XCTAssertEqual(engine.aggregateSeverity(for: findings), .yellow)
        XCTAssertFalse(findings.contains(where: { $0.severity == .red }))
    }

    func testUntrustedScreenRecordingGrantIsRed() {
        let rules = RuleSeeder.seededRules()
        let snapshot = SignalSnapshot(
            serviceStates: [:],
            permissions: [
                PermissionGrant(
                    kind: .screenRecording,
                    client: "com.suspicious.Capture",
                    bundleIdentifier: "com.suspicious.Capture",
                    state: .allowed,
                    source: "User TCC"
                )
            ],
            processes: [],
            launchAgents: [],
            listeningSockets: [],
            activeConnections: [],
            limitedVisibilityReasons: []
        )

        let findings = engine.evaluate(snapshot: snapshot, rules: rules, trust: TrustContext())
        XCTAssertEqual(engine.aggregateSeverity(for: findings), .red)
        XCTAssertTrue(findings.contains(where: { $0.title == "Untrusted Screen Recording Permission" }))
    }

    func testListeningVNCPortIsRed() {
        let rules = RuleSeeder.seededRules()
        let snapshot = SignalSnapshot(
            serviceStates: [:],
            permissions: [],
            processes: [],
            launchAgents: [],
            listeningSockets: [
                ListeningSocket(processName: "screensharingd", pid: 100, localAddress: "*", localPort: 5900, rawName: "*:5900 (LISTEN)")
            ],
            activeConnections: [],
            limitedVisibilityReasons: []
        )

        let findings = engine.evaluate(snapshot: snapshot, rules: rules, trust: TrustContext())
        XCTAssertEqual(engine.aggregateSeverity(for: findings), .red)
        XCTAssertTrue(findings.contains(where: { $0.title == "Remote Desktop Server Port Listening" }))
    }

    func testNoSignalsStaysGreen() {
        let findings = engine.evaluate(snapshot: SignalSnapshot(), rules: RuleSeeder.seededRules(), trust: TrustContext())
        XCTAssertTrue(findings.isEmpty)
        XCTAssertEqual(engine.aggregateSeverity(for: findings), .green)
    }
}
