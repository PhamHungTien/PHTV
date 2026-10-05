import XCTest
@testable import PHTV

final class CustomConsonantsTests: XCTestCase {
    func testNormalizationAndValidation() {
        XCTAssertEqual(PHTVCustomConsonants.normalized([" z ", "dz", "Z", "BL"]), ["Z", "DZ", "BL"])
        for invalid in ["", "A", "AE", "ABC", "Z1", "Đ", "ß", "Z F", "🙂"] {
            XCTAssertNil(PHTVCustomConsonants.normalizedEntry(invalid), invalid)
        }
        XCTAssertEqual(PHTVCustomConsonants.normalized([]), [])
    }

    func testBackupRoundTripAndRejectInvalidEntries() throws {
        let key = UserDefaultsKey.customConsonants
        let result = try SettingsBackupSchema.normalizedSettings([key: .array([.string("bl"), .string("DZ")])])
        XCTAssertEqual(result[key] as? [String], ["BL", "DZ"])
        let empty = try SettingsBackupSchema.normalizedSettings([key: .array([])])
        XCTAssertEqual(empty[key] as? [String], [])
        for invalid: AnyCodableValue in [.array([.string("AE")]), .array([.integer(1)]), .array(Array(repeating: .string("Z"), count: 65))] {
            XCTAssertThrowsError(try SettingsBackupSchema.normalizedSettings([key: invalid]))
        }
    }

    @MainActor
    func testSettingsPersistReloadAndTokenDetectsSameLengthEdits() {
        let key = UserDefaultsKey.customConsonants
        let defaults = UserDefaults.standard
        let saved = defaults.object(forKey: key)
        defer {
            if let saved { defaults.set(saved, forKey: key) } else { defaults.removeObject(forKey: key) }
            AppState.shared.loadSettings()
            PHTVEngineRuntimeFacade.setCustomConsonants(PHTVCustomConsonants.defaults)
        }
        defaults.set(["Z", "BL"], forKey: key)
        let firstToken = PHTVManager.phtv_currentSettingsTokenFromUserDefaults()
        defaults.set(["Z", "BR"], forKey: key)
        XCTAssertNotEqual(PHTVManager.phtv_currentSettingsTokenFromUserDefaults(), firstToken)
        let state = InputMethodState()
        state.loadSettings()
        XCTAssertEqual(state.customConsonants, ["Z", "BR"])
        state.customConsonants = ["DZ", "BL"]
        XCTAssertEqual(defaults.stringArray(forKey: key), ["DZ", "BL"])
        let restored = InputMethodState()
        restored.loadSettings()
        XCTAssertEqual(restored.customConsonants, ["DZ", "BL"])
    }
}
