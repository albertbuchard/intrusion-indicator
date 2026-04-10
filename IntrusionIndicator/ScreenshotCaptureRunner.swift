import AppKit
import SwiftData
import SwiftUI

@MainActor
enum ScreenshotCaptureRunner {
    private static let captureEnabledKey = "II_SCREENSHOT_CAPTURE"
    private static let outputDirectoryKey = "II_SCREENSHOT_OUTPUT_DIR"
    private static let outputNameKey = "II_SCREENSHOT_NAME"
    private static let rulesOutputNameKey = "II_SCREENSHOT_RULES_NAME"
    private static let captureRulesKey = "II_SCREENSHOT_CAPTURE_RULES"

    static func runIfRequested(using appState: AppState) {
        guard isEnabled else { return }
        guard let fixture = AppCaptureFixture.current?.scenario else { return }

        guard let outputDirectory = outputDirectory else {
            NSLog("II_SCREENSHOT_OUTPUT_DIR is not set; skipping screenshot capture.")
            NSApplication.shared.terminate(nil)
            return
        }

        let mainOutputName = ProcessInfo.processInfo.environment[outputNameKey] ?? defaultName(for: fixture)
        capture(
            ScreenshotHarnessView(scenario: fixture)
                .environmentObject(appState)
                .frame(width: 1365, height: 768),
            to: outputDirectory.appendingPathComponent(mainOutputName)
        )

        if shouldCaptureRules { captureRules(to: outputDirectory) }
        NSApplication.shared.terminate(nil)
    }

    private static func capture(_ view: some View, to outputURL: URL) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2

        guard let image = renderer.nsImage else {
            NSLog("Failed to render screenshot for \(outputURL.lastPathComponent)")
            return
        }
        guard let data = image.pngData() else {
            NSLog("Unable to encode screenshot image: \(outputURL.lastPathComponent)")
            return
        }
        do {
            try data.write(to: outputURL)
            NSLog("Wrote screenshot: \(outputURL.path)")
        } catch {
            NSLog("Failed to write screenshot \(outputURL.path): \(error.localizedDescription)")
        }
    }

    private static func captureRules(to outputDirectory: URL) {
        let rulesView = RulesSettingsView()
            .frame(width: 980, height: 760)
            .modelContainer(seedRulesModelContainer())

        let rulesOutputName = ProcessInfo.processInfo.environment[rulesOutputNameKey] ?? "02-rules.png"
        capture(
            rulesView,
            to: outputDirectory.appendingPathComponent(rulesOutputName)
        )
    }

    private static func seedRulesModelContainer() -> ModelContainer {
        let container = try! ModelContainer(
            for: RuleRecord.self,
            TrustedAppRecord.self,
            TrustedEndpointRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )

        do {
            try RuleSeeder.seedIfNeeded(in: container.mainContext)
        } catch {
            NSLog("Failed to seed rules data for screenshot capture: \(error.localizedDescription)")
        }
        return container
    }

    private static var isEnabled: Bool {
        let enabled = ProcessInfo.processInfo.environment[captureEnabledKey]?.lowercased()
        return enabled == "1" || enabled == "true" || enabled == "yes"
    }

    private static var shouldCaptureRules: Bool {
        let request = ProcessInfo.processInfo.environment[captureRulesKey]?.lowercased()
        return request == "1" || request == "true" || request == "yes"
    }

    private static var outputDirectory: URL? {
        guard let path = ProcessInfo.processInfo.environment[outputDirectoryKey],
              !path.isEmpty else {
            return nil
        }
        let url = URL(fileURLWithPath: path)
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return url
        } catch {
            NSLog("Unable to create output directory \(url.path): \(error.localizedDescription)")
            return nil
        }
    }

    private static func defaultName(for fixture: AppCaptureScenario) -> String {
        switch fixture {
        case .healthy:
            "01-overview.png"
        case .yellow:
            "03-risk-yellow.png"
        case .red:
            "04-risk-red.png"
        case .permissions:
            "05-permissions.png"
        }
    }
}

private extension NSImage {
    func pngData() -> Data? {
        guard let tiffData = tiffRepresentation else { return nil }
        guard let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
