import SwiftData
import SwiftUI
import AppKit

struct StatusMenuContentView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openWindow) private var openWindow
    @State private var selectedFinding: Finding?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Circle()
                        .fill(Color(nsColor: appState.severity.tintColor))
                        .frame(width: 14, height: 14)
                        .shadow(color: Color(nsColor: appState.severity.tintColor).opacity(0.35), radius: 4, x: 0, y: 0)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(statusHeadline)
                            .font(.headline)
                        Text(statusDetail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .accessibilityIdentifier("screenshot-status-indicator-row")

                SeverityLegendView()

                if let lastScanAt = appState.lastScanAt {
                    Text("Last scan: \(lastScanAt.formatted(date: .omitted, time: .standard))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let lastErrorMessage = appState.lastErrorMessage {
                    Text(lastErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            if appState.findings.isEmpty {
                Text("No current warnings. No configured rule is firing.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(appState.findings.prefix(5))) { finding in
                        FindingSummaryRow(finding: finding) {
                            selectedFinding = finding
                        }
                    }

                    if appState.findings.count > 5 {
                        Text("Showing 5 of \(appState.findings.count) active warnings. Open Rules to review all.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            HStack {
                Button("Rescan Now") {
                    Task { await appState.rescan() }
                }
                .keyboardShortcut("r")
                .accessibilityIdentifier("screenshot-rescan")

                Button("Open Rules") {
                    openRulesWindow()
                }
                .accessibilityIdentifier("open-rules")
                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }

            GroupBox("What is being checked") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("This app only checks local system signals; it does not capture screen, microphone, or camera content.")
                        .font(.caption)
                        .foregroundStyle(.primary)

                    Text("You are being warned when a high-confidence remote-exposure signal is present (permissions, services, remote tools, or network activity).")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Screen Recording is a strong cue because it gives direct framebuffer access, so it is flagged when an untrusted app has it enabled.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Button("Screen Recording") {
                            openPrivacyPane(anchor: "Privacy_ScreenCapture")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .accessibilityIdentifier("permission-help-screen-recording")

                        Button("Microphone") {
                            openPrivacyPane(anchor: "Privacy_Microphone")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .accessibilityIdentifier("permission-help-microphone")

                        Button("Camera") {
                            openPrivacyPane(anchor: "Privacy_Camera")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .accessibilityIdentifier("permission-help-camera")
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 420)
        .popover(item: $selectedFinding, arrowEdge: .leading) { finding in
            FindingDetailPanel(finding: finding)
                .padding(12)
                .frame(width: 300)
        }
    }

    private var statusHeadline: String {
        switch appState.severity {
        case .green:
            return "No active warnings"
        case .yellow:
            return "Potential eavesdropping cues detected"
        case .red:
            return "High-confidence remote-viewing exposure"
        }
    }

    private var statusDetail: String {
        switch appState.severity {
        case .green:
            return "Green means no configured signal is currently present."
        case .yellow:
            return "Yellow means caution. These are potential risk indicators or limited visibility."
        case .red:
            return "Red means a stronger indicator was matched. Review the highlighted warning now."
        }
    }

    private func openPrivacyPane(anchor: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func openRulesWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        openWindow(id: "rules")
        focusRulesWindow(retriesRemaining: 12)
    }

    private func focusRulesWindow(retriesRemaining: Int) {
        guard retriesRemaining > 0 else {
            return
        }

        let matchingWindow = NSApplication.shared.windows.first(where: isRulesWindow)

        if let matchingWindow {
            if matchingWindow.isMiniaturized {
                matchingWindow.deminiaturize(nil)
            }
            matchingWindow.makeKeyAndOrderFront(nil)
            matchingWindow.orderFrontRegardless()
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            focusRulesWindow(retriesRemaining: retriesRemaining - 1)
        }
    }

    private func isRulesWindow(_ window: NSWindow) -> Bool {
        if let identifier = window.identifier?.rawValue, identifier == "rules" {
            return true
        }
        return window.title == "Rules & Trust"
    }
}

private struct SeverityLegendView: View {
    private let entries: [(severity: Severity, label: String, detail: String)] = [
        (.green, "Green", "No matching signs"),
        (.yellow, "Yellow", "Possible caution"),
        (.red, "Red", "Likely exposure")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Color meaning")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                ForEach(entries, id: \.label) { entry in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color(nsColor: entry.severity.tintColor))
                            .frame(width: 8, height: 8)
                        Text("\(entry.label):")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(entry.detail)
                            .font(.caption.weight(.medium))
                    }
                }
            }
        }
    }
}

private struct FindingSummaryRow: View {
    let finding: Finding
    let onInfoTapped: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button(action: onInfoTapped) {
                ZStack {
                    Circle()
                        .fill(Color(nsColor: finding.severity.tintColor))
                        .frame(width: 20, height: 20)
                    Image(systemName: "info.circle")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .help("Open warning details")

            VStack(alignment: .leading, spacing: 2) {
                Text(finding.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("Severity: \(finding.severity.title) · Confidence: \(finding.confidencePercentage)")
                    .font(.caption2)
                    .foregroundStyle(Color(nsColor: finding.severity.tintColor))
            }
        }
    }
}

private struct FindingDetailPanel: View {
    let finding: Finding

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Circle()
                    .fill(Color(nsColor: finding.severity.tintColor))
                    .frame(width: 10, height: 10)
                Text(finding.title)
                    .font(.headline)
            }

            Text("Why this warning appeared")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(finding.message)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)

            if !finding.evidence.isEmpty {
                Text("Signals observed")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(finding.evidence) { item in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(item.label): \(item.value)")
                                .font(.caption)
                        }
                    }
                }
            }

            if let remediation = finding.remediation {
                Text("Recommended action")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(remediation)
                    .font(.caption)
            }

            Text("Detected at \(finding.matchedAt.formatted(date: .omitted, time: .shortened))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

private extension Finding {
    var confidencePercentage: String {
        let value = max(0, min(100, Int((confidence * 100).rounded())))
        return "\(value)%"
    }
}
