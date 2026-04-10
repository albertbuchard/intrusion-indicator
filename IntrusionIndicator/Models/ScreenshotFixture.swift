import Foundation

enum AppCaptureScenario: String, CaseIterable, Sendable {
    case healthy
    case yellow
    case red
    case permissions

    static var current: AppCaptureScenario? {
        guard let value = ProcessInfo.processInfo.environment["II_SCREENSHOT_FIXTURE"]?.lowercased() else {
            return nil
        }
        return AppCaptureScenario(rawValue: value)
    }
}

struct AppCaptureFixture: Sendable {
    let scenario: AppCaptureScenario

    static var current: AppCaptureFixture? {
        guard let scenario = AppCaptureScenario.current else { return nil }
        return AppCaptureFixture(scenario: scenario)
    }

    var shouldShowCaptureHarness: Bool {
        true
    }

    func findings(at timestamp: Date) -> [Finding] {
        switch scenario {
        case .healthy:
            return []
        case .yellow:
            return [
                Finding(
                    ruleID: Self.yellowRuleID,
                    severity: .yellow,
                    title: "Possible capture-capability grant",
                    message: "A non-trusted application has microphone permission enabled in system privacy settings.",
                    evidence: [
                        EvidenceItem(label: "Permission", value: "com.example.untrusted.micwatcher")
                    ],
                    matchedAt: timestamp,
                    confidence: 0.93,
                    remediation: "Review and revoke microphone/camera permissions for apps you do not use."
                )
            ]
        case .red:
            return [
                Finding(
                    ruleID: Self.redRuleID,
                    severity: .red,
                    title: "Screen Sharing endpoint exposed",
                    message: "A remote desktop listener is active on a common viewer-control port.",
                    evidence: [
                        EvidenceItem(label: "Listener", value: "vncserver 5900")
                    ],
                    matchedAt: timestamp,
                    confidence: 0.98,
                    remediation: "Disable unexpected screen sharing services and verify access permissions."
                )
            ]
        case .permissions:
            return [
                Finding(
                    ruleID: Self.yellowRuleID,
                    severity: .yellow,
                    title: "Screen Recording permission granted",
                    message: "An untrusted app has screen-recording permission. It can capture what appears on this display.",
                    evidence: [
                        EvidenceItem(label: "Screen", value: "com.example.untrusted.capture")
                    ],
                    matchedAt: timestamp,
                    confidence: 0.96,
                    remediation: "Keep an eye on System Settings > Privacy & Security > Screen Recording."
                )
            ]
        }
    }

    var aggregateSeverity: Severity {
        findings(at: Date()).map(\.severity).max() ?? .green
    }

    static let redRuleID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")
    static let yellowRuleID = UUID(uuidString: "10000000-0000-0000-0000-000000000003")
}
