import SwiftData
import SwiftUI

@main
struct IntrusionIndicatorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let modelContainer: ModelContainer
    @StateObject private var appState: AppState
    private let captureFixture: AppCaptureFixture?

    init() {
        let captureFixture = AppCaptureFixture.current
        self.captureFixture = captureFixture

        let configuration = ModelConfiguration(isStoredInMemoryOnly: captureFixture != nil)
        let container = try! ModelContainer(
            for: RuleRecord.self,
            TrustedAppRecord.self,
            TrustedEndpointRecord.self,
            configurations: configuration
        )
        modelContainer = container

        let initialState = AppState(modelContainer: container)
        _appState = StateObject(wrappedValue: initialState)
        AppBootstrap.onLaunch = {
            initialState.bootstrap()
        }
    }

    @SceneBuilder
    var body: some Scene {
        menuBarScene
        rulesScene
        screenshotScene
    }

    private var menuBarScene: some Scene {
        MenuBarExtra {
            StatusMenuContentView()
                .environmentObject(appState)
        } label: {
            Label {
                if !appState.findings.isEmpty {
                    Text("\(appState.findings.count)")
                }
            } icon: {
                Image(systemName: "circle.fill")
                    .foregroundStyle(Color(nsColor: appState.severity.tintColor))
            }
        }
        .menuBarExtraStyle(.window)
        .modelContainer(modelContainer)
    }

    private var screenshotScene: some Scene {
        Window("Screenshot Capture", id: "screenshot-capture") {
            if let fixture = captureFixture {
                ScreenshotHarnessView(scenario: fixture.scenario)
                    .environmentObject(appState)
            } else {
                Text("Screenshot capture disabled.")
            }
        }
        .defaultSize(width: 1365, height: 768)
        .windowResizability(.contentSize)
    }

    private var rulesScene: some Scene {
        Window("Rules & Trust", id: "rules") {
            RulesSettingsView()
                .modelContainer(modelContainer)
        }
        .defaultSize(width: 980, height: 760)
        .windowResizability(.contentSize)
    }
}
