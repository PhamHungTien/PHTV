import Foundation
import XCTest
@testable import PHTV

final class SettingsBackupValueTests: XCTestCase {
    @MainActor
    func testMacroExclusionsPersistAndRoundTripThroughBackup() throws {
        let suite = "PHTV.MacroExclusions.Tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let apps = [MacroExcludedApp(bundleIdentifier: "com.apple.TextEdit", name: "TextEdit", path: "/System/Applications/TextEdit.app")]
        XCTAssertTrue(MacroState.loadExcludedApps(defaults: defaults).isEmpty)
        defaults.set(try JSONEncoder().encode(apps), forKey: UserDefaultsKey.macroExcludedApps)
        XCTAssertEqual(MacroState.loadExcludedApps(defaults: defaults), apps)
        defaults.set(false, forKey: UserDefaultsKey.useMacro)
        defaults.set(true, forKey: UserDefaultsKey.useMacroInEnglishMode)
        let state = MacroState()
        state.loadSettings(defaults: defaults)
        XCTAssertEqual(state.macroExcludedApps, apps)
        XCTAssertFalse(state.useMacro)
        XCTAssertTrue(state.useMacroInEnglishMode)
        XCTAssertFalse(state.isLoadingSettings)
        let legacyJSON = Data(#"{"version":"2.0","exportDate":"2026-09-19"}"#.utf8)
        var backup = try JSONDecoder().decode(SettingsBackup.self, from: legacyJSON)
        XCTAssertNil(backup.macroExcludedApps)
        backup.macroExcludedApps = apps
        let decoded = try JSONDecoder().decode(SettingsBackup.self, from: JSONEncoder().encode(backup))
        XCTAssertEqual(decoded.macroExcludedApps, apps)
    }

    func testSupportedDefaultsValuesRoundTripWithoutUncheckedSendableStorage() throws {
        let values = [
            AnyCodableValue(NSNumber(value: 42)),
            AnyCodableValue(NSNumber(value: 1.5)),
            AnyCodableValue(NSNumber(value: true)),
            AnyCodableValue("PHTV"),
        ]

        let data = try JSONEncoder().encode(values)
        let decoded = try JSONDecoder().decode([AnyCodableValue].self, from: data)

        XCTAssertEqual(decoded[0].value as? Int, 42)
        XCTAssertEqual(decoded[1].value as? Double, 1.5)
        XCTAssertEqual(decoded[2].value as? Bool, true)
        XCTAssertEqual(decoded[3].value as? String, "PHTV")
    }
}
