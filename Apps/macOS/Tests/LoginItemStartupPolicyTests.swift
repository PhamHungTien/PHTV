import XCTest
import ServiceManagement
@testable import PHTV

final class LoginItemStartupPolicyTests: XCTestCase {
    func testFreshInstallRegistersDefaultLoginItem() {
        XCTAssertTrue(LoginItemStartupPolicy.shouldRegister(isFirstLaunch: true, status: .notRegistered))
    }

    func testExistingUserChoiceIsNeverOverriddenOnLaunch() {
        for status: SMAppService.Status in [.enabled, .notRegistered, .requiresApproval, .notFound] {
            XCTAssertFalse(LoginItemStartupPolicy.shouldRegister(isFirstLaunch: false, status: status))
        }
    }

    func testAlreadyRegisteredOrPendingApprovalIsNotRegisteredAgain() {
        for status: SMAppService.Status in [.enabled, .requiresApproval, .notFound] {
            XCTAssertFalse(LoginItemStartupPolicy.shouldRegister(isFirstLaunch: true, status: status))
        }
    }

    func testBothDefaultKeysAgreeAndExplicitOptOutSurvivesRegistration() {
        let suite = "PHTV.LoginDefaultsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.register(defaults: SettingsBootstrap.registrationDefaults())
        XCTAssertTrue(defaults.bool(forKey: UserDefaultsKey.runOnStartup))
        XCTAssertEqual(defaults.integer(forKey: UserDefaultsKey.runOnStartupLegacy), 1)
        defaults.set(false, forKey: UserDefaultsKey.runOnStartup)
        defaults.register(defaults: SettingsBootstrap.registrationDefaults())
        XCTAssertFalse(defaults.bool(forKey: UserDefaultsKey.runOnStartup))
    }
}
