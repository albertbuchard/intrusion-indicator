import AppKit

@MainActor
enum AppBootstrap {
    static var onLaunch: (() -> Void)?
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if AppCaptureFixture.current != nil {
            NSApplication.shared.setActivationPolicy(.regular)
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        AppBootstrap.onLaunch?()
    }
}
