import XCTest
@testable import PHTV

final class RetiredAccessibilitySettingsTests: XCTestCase {
    func testOldBackupImportsTypingSettingsWithoutRestoringRetiredMode() throws {
        for value: AnyCodableValue in [.boolean(true), .boolean(false), .integer(0), .integer(1)] {
            let result = try SettingsBackupSchema.normalizedSettings([
                "SafeMode": value,
                UserDefaultsKey.sendKeyStepByStep: .boolean(true)
            ])
            XCTAssertNil(result["SafeMode"])
            XCTAssertEqual(result[UserDefaultsKey.sendKeyStepByStep] as? Bool, true)
        }
        XCTAssertNil(SettingsBackupSchema.defaults["SafeMode"])
        XCTAssertThrowsError(try SettingsBackupSchema.normalizedSettings(["SafeMode": .string("true")]))
        XCTAssertThrowsError(try SettingsBackupSchema.normalizedSettings(["SafeMode": .integer(2)]))
        XCTAssertThrowsError(try SettingsBackupSchema.normalizedSettings(["UnknownSetting": .boolean(true)]))
    }

    func testUpgradeClearsPersistedCrashRecoveryAndPreservesTypingSettings() throws {
        let suite = "PHTV.RetiredAccessibilitySettingsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "SafeMode")
        defaults.set(true, forKey: "AXTestInProgress")
        defaults.set(true, forKey: UserDefaultsKey.sendKeyStepByStep)
        defaults.set(0, forKey: UserDefaultsKey.codeTable)

        for _ in 0..<2 {
            PHTVCoreSettingsBootstrapService.removeRetiredAccessibilitySettings(from: defaults)
            XCTAssertNil(defaults.object(forKey: "SafeMode"))
            XCTAssertNil(defaults.object(forKey: "AXTestInProgress"))
            XCTAssertTrue(defaults.bool(forKey: UserDefaultsKey.sendKeyStepByStep))
            XCTAssertEqual(defaults.integer(forKey: UserDefaultsKey.codeTable), 0)
        }
    }
}
