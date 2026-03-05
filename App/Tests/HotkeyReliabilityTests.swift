import XCTest
import AppKit
@testable import PHTV

final class HotkeyReliabilityTests: XCTestCase {
    private let trackedDefaultsKeys = [
        "SwitchKeyStatus",
        "convertToolHotKey",
        "vEnableEmojiHotkey",
        "vEmojiHotkeyModifiers",
        "vEmojiHotkeyKeyCode"
    ]

    private var defaultsBackup: [String: Any] = [:]
    private var missingDefaultsKeys: Set<String> = []

    override func setUp() {
        super.setUp()
        let defaults = UserDefaults.standard
        defaultsBackup.removeAll(keepingCapacity: true)
        missingDefaultsKeys.removeAll(keepingCapacity: true)

        for key in trackedDefaultsKeys {
            if let value = defaults.object(forKey: key) {
                defaultsBackup[key] = value
            } else {
                missingDefaultsKeys.insert(key)
            }
        }
    }

    override func tearDown() {
        let defaults = UserDefaults.standard

        for key in trackedDefaultsKeys {
            if missingDefaultsKeys.contains(key) {
                defaults.removeObject(forKey: key)
            } else if let value = defaultsBackup[key] {
                defaults.set(value, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        super.tearDown()
    }

    func testLoadRuntimeSettingsNormalizesInvalidSwitchHotkey() {
        let defaults = UserDefaults.standard
        defaults.set(Int(Int32(bitPattern: 0xFFFF_FFFF)), forKey: "SwitchKeyStatus")

        _ = PHTVManager.loadRuntimeSettingsFromUserDefaults()

        XCTAssertEqual(PHTVManager.currentSwitchKeyStatus(), Int32(Defaults.defaultSwitchKeyStatus))
        XCTAssertEqual(defaults.integer(forKey: "SwitchKeyStatus"), Defaults.defaultSwitchKeyStatus)
    }

    func testConvertHotkeyNormalizationFallsBackToEmptyHotkey() {
        let defaults = UserDefaults.standard
        defaults.set(0x0041, forKey: "convertToolHotKey")

        let resolved = PHTVConvertToolHotkeyService.currentHotkey()
        let expected = Int32(bitPattern: 0xFE0000FE)

        XCTAssertEqual(resolved, expected)
        XCTAssertEqual(
            Int32(truncatingIfNeeded: defaults.integer(forKey: "convertToolHotKey")),
            expected
        )
    }

    func testEmojiHotkeyNormalizationRepairsInvalidValues() {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "vEnableEmojiHotkey")
        defaults.set(0, forKey: "vEmojiHotkeyModifiers")
        defaults.set(999, forKey: "vEmojiHotkeyKeyCode")

        PHTVManager.loadEmojiHotkeySettingsFromDefaults()
        let snapshot = PHTVManager.runtimeSettingsSnapshot()

        XCTAssertEqual(snapshot["enableEmojiHotkey"]?.intValue, 1)
        XCTAssertEqual(
            snapshot["emojiHotkeyModifiers"]?.intValue,
            Int(NSEvent.ModifierFlags.command.rawValue)
        )
        XCTAssertEqual(snapshot["emojiHotkeyKeyCode"]?.intValue, Int(KeyCode.eKey))
        XCTAssertEqual(
            defaults.integer(forKey: "vEmojiHotkeyModifiers"),
            Int(NSEvent.ModifierFlags.command.rawValue)
        )
        XCTAssertEqual(defaults.integer(forKey: "vEmojiHotkeyKeyCode"), Int(KeyCode.eKey))
    }

    func testEmojiHotkeyPreservesKeyCodeZero() {
        let defaults = UserDefaults.standard
        let commandModifiers = Int(NSEvent.ModifierFlags.command.rawValue)
        defaults.set(true, forKey: "vEnableEmojiHotkey")
        defaults.set(commandModifiers, forKey: "vEmojiHotkeyModifiers")
        defaults.set(0, forKey: "vEmojiHotkeyKeyCode")

        PHTVManager.loadEmojiHotkeySettingsFromDefaults()
        let snapshot = PHTVManager.runtimeSettingsSnapshot()

        XCTAssertEqual(snapshot["emojiHotkeyKeyCode"]?.intValue, 0)
        XCTAssertEqual(defaults.integer(forKey: "vEmojiHotkeyKeyCode"), 0)
        XCTAssertTrue(
            PHTVHotkeyService.checkEmojiHotkey(
                enabled: 1,
                keycode: 0,
                flags: UInt64(CGEventFlags.maskCommand.rawValue),
                emojiModifiers: Int32(commandModifiers),
                emojiHotkeyKeyCode: 0
            )
        )
    }
}
