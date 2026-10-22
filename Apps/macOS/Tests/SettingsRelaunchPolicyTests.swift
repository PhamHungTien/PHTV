import XCTest
import AppKit
@testable import PHTV

final class SettingsRelaunchPolicyTests: XCTestCase {
    func testPinningHiddenSettingsDoesNotPresentWindow() async {
        await MainActor.run {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 780, height: 550),
                                  styleMask: [.titled, .closable], backing: .buffered, defer: true)
            window.isReleasedWhenClosed = false
            defer { window.close() }
            XCTAssertFalse(window.isVisible)
            SettingsWindowHelper.applyWindowConfiguration(to: window, alwaysOnTop: true)
            XCTAssertEqual(window.level, .floating)
            XCTAssertFalse(window.isVisible)
            SettingsWindowHelper.applyWindowConfiguration(to: window, alwaysOnTop: false)
            XCTAssertEqual(window.level, .normal)
            XCTAssertFalse(window.isVisible)
        }
    }

    func testBackgroundRelaunchSuppressesLegacyShowSettingsPreference() {
        for preference in [true, false] {
            XCTAssertFalse(SettingsRelaunchPolicy.shouldShowSettingsOnStartup(
                arguments: ["PHTV", SettingsRelaunchPolicy.backgroundArgument], preference: preference
            ))
        }
    }

    func testNormalLaunchRespectsExistingPreference() {
        XCTAssertTrue(SettingsRelaunchPolicy.shouldShowSettingsOnStartup(arguments: ["PHTV"], preference: true))
        XCTAssertFalse(SettingsRelaunchPolicy.shouldShowSettingsOnStartup(arguments: ["PHTV"], preference: false))
    }

    func testSettingsRelaunchWaitsForParentAndUsesBackgroundArgument() {
        let arguments = phtvDeferredRelaunchProcessArguments(
            parentPID: 123, bundlePath: "/Applications/PHTV.app",
            launchArguments: [SettingsRelaunchPolicy.backgroundArgument]
        )
        XCTAssertTrue(arguments[1].contains("while kill -0"))
        XCTAssertTrue(arguments[1].contains("/usr/bin/open -g -j -n"))
        XCTAssertEqual(Array(arguments.suffix(3)), ["123", "/Applications/PHTV.app", "--phtv-background"])
    }
}
