import XCTest

final class IntrusionIndicatorUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testScreenshot_HealthyStateOverview() throws {
        try runScenario(
            fixture: "healthy",
            outputName: "01-overview.png"
        )
    }

    func testScreenshot_YellowRiskState() throws {
        try runScenario(
            fixture: "yellow",
            outputName: "03-risk-yellow.png"
        )
    }

    func testScreenshot_RedRiskState() throws {
        try runScenario(
            fixture: "red",
            outputName: "04-risk-red.png"
        )
    }

    func testScreenshot_PermissionGuidance() throws {
        try runScenario(
            fixture: "permissions",
            outputName: "05-permissions.png"
        )
    }

    func testScreenshot_RulesEditor() throws {
        let app = launchApp(withFixture: "healthy")
        openRulesWindow(on: app)
        let rulesWindow = app.windows["Rules & Trust"]
        if rulesWindow.waitForExistence(timeout: 5) {
            save(screenshot: rulesWindow.screenshot(), as: "02-rules.png")
            return
        }
        save(screenshot: app.screenshot(), as: "02-rules.png")
    }

    private func runScenario(fixture: String, outputName: String) throws {
        let app = launchApp(withFixture: fixture)
        let harnessTitle = app.staticTexts["screenshot-harness-title"]
        XCTAssertTrue(harnessTitle.waitForExistence(timeout: 6))
        let scenarioLabel = app.staticTexts["screenshot-harness-scenario"]
        XCTAssertTrue(scenarioLabel.waitForExistence(timeout: 2))
        if fixture == "permissions" {
            XCTAssertTrue(app.buttons["permission-help-menu"].waitForExistence(timeout: 2))
        }
        save(screenshot: app.screenshot(), as: outputName)
    }

    private func launchApp(withFixture fixture: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["II_SCREENSHOT_FIXTURE"] = fixture
        app.launchEnvironment["II_SCREENSHOT_OUTPUT_DIR"] = outputDirectory.path
        app.launchArguments.append("--ui-testing")
        app.launch()
        app.activate()
        return app
    }

    private func openRulesWindow(on app: XCUIApplication) {
        let openRules = app.buttons["open-rules-for-screenshot"]
        if openRules.waitForExistence(timeout: 5) {
            openRules.tap()
            return
        }
        app.buttons["open-rules"].waitForExistence(timeout: 2)
        app.buttons["open-rules"].tap()
    }

    private func save(screenshot: XCUIScreenshot, as name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        let outputURL = outputDirectory.appendingPathComponent(name)
        try? screenshot.pngRepresentation.write(to: outputURL)
    }

    private var outputDirectory: URL {
        let base = ProcessInfo.processInfo.environment["II_SCREENSHOT_OUTPUT_DIR"].flatMap { URL(fileURLWithPath: $0) }
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        try? FileManager.default.createDirectory(
            at: base,
            withIntermediateDirectories: true,
            attributes: nil
        )
        return base
    }
}
