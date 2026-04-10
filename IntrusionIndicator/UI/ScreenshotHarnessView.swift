import SwiftUI
import AppKit

struct ScreenshotHarnessView: View {
    let scenario: AppCaptureScenario
    @EnvironmentObject private var appState: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Intrusion Indicator Screenshot Harness")
                .font(.title2.weight(.semibold))
                .accessibilityIdentifier("screenshot-harness-title")

            Text("Fixture: \(scenario.rawValue.capitalized)")
                .font(.headline)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("screenshot-harness-scenario")

            StatusMenuContentView()
                .environmentObject(appState)
                .accessibilityIdentifier("screenshot-status-content")

            Divider()

            Button("Open Rules for Screenshot") {
                openRulesWindow()
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("open-rules-for-screenshot")
        }
        .padding(16)
        .frame(minWidth: 520, minHeight: 740)
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
