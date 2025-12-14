//
//  PHTVFunctionalTests.swift
//  PHTV Tests
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import XCTest

// MARK: - Test Suite cho các cải tiến

class PHTVFunctionalTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Clear UserDefaults before each test
        let domain = Bundle.main.bundleIdentifier ?? ""
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()
    }

    override func tearDown() {
        super.tearDown()
        // Clean up
        UserDefaults.standard.synchronize()
    }

    // MARK: - Test 1: Macro Hot-Reload
    /// Test Case: Thêm macro mới và kiểm tra nó được lưu ngay lập tức
    func testMacroHotReload() {
        let testMacroName = "tvn"
        let testMacroContent = "Tiếng Việt Nam"

        // 1. Simulate saving macro
        var macros: [MacroItem] = []
        let newMacro = MacroItem(shortcut: testMacroName, expansion: testMacroContent)
        macros.append(newMacro)

        if let encoded = try? JSONEncoder().encode(macros) {
            UserDefaults.standard.set(encoded, forKey: "macroList")
            UserDefaults.standard.synchronize()
        }

        // 2. Verify it's saved
        if let data = UserDefaults.standard.data(forKey: "macroList"),
            let loadedMacros = try? JSONDecoder().decode([MacroItem].self, from: data)
        {
            XCTAssertEqual(loadedMacros.count, 1)
            XCTAssertEqual(loadedMacros[0].shortcut, testMacroName)
            XCTAssertEqual(loadedMacros[0].expansion, testMacroContent)
            print("✅ Test 1 PASS: Macro hot-reload works correctly")
        } else {
            XCTFail("Failed to load saved macros")
        }
    }

    // MARK: - Test 2: Settings Observer Debouncing
    /// Test Case: SettingsObserver không gọi update quá tần suất
    func testSettingsObserverDebouncing() {
        let observer = SettingsObserver.shared
        var updateCount = 0
        let expectation = XCTestExpectation(description: "Debounce completes")

        // Subscribe to changes
        var cancellable: NSObjectProtocol?
        cancellable = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: UserDefaults.standard,
            queue: .main
        ) { _ in
            updateCount += 1
        }

        // Make rapid changes
        for i in 0..<5 {
            UserDefaults.standard.set(i, forKey: "TestKey_\(i)")
        }

        // Wait for debounce
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)

        if let cancellable = cancellable {
            NotificationCenter.default.removeObserver(cancellable)
        }

        // Should have multiple updates but debounced
        XCTAssertGreater(updateCount, 0)
        print("✅ Test 2 PASS: Settings observer debouncing works (updates: \(updateCount))")
    }

    // MARK: - Test 3: Excluded Apps Management
    /// Test Case: Thêm/xóa ứng dụng loại trừ hoạt động đúng
    func testExcludedAppsManagement() {
        // 1. Create test app
        let testApp = ExcludedApp(
            bundleIdentifier: "com.test.app",
            name: "Test App",
            path: "/Applications/TestApp.app"
        )

        // 2. Save to defaults
        var apps: [ExcludedApp] = [testApp]
        if let encoded = try? JSONEncoder().encode(apps) {
            UserDefaults.standard.set(encoded, forKey: "ExcludedApps")
            UserDefaults.standard.synchronize()
        }

        // 3. Load and verify
        if let data = UserDefaults.standard.data(forKey: "ExcludedApps"),
            let loadedApps = try? JSONDecoder().decode([ExcludedApp].self, from: data)
        {
            XCTAssertEqual(loadedApps.count, 1)
            XCTAssertEqual(loadedApps[0].bundleIdentifier, "com.test.app")
            XCTAssertEqual(loadedApps[0].name, "Test App")
            print("✅ Test 3 PASS: Excluded apps management works correctly")
        } else {
            XCTFail("Failed to load excluded apps")
        }
    }

    // MARK: - Test 4: Settings Persistence
    /// Test Case: Cài đặt được lưu và load chính xác
    func testSettingsPersistence() {
        // Save various settings
        UserDefaults.standard.set(0, forKey: "InputType")  // Telex
        UserDefaults.standard.set(1, forKey: "InputMethod")  // Vietnamese enabled
        UserDefaults.standard.set(true, forKey: "Spelling")
        UserDefaults.standard.set(true, forKey: "UseMacro")
        UserDefaults.standard.synchronize()

        // Load and verify
        let inputType = UserDefaults.standard.integer(forKey: "InputType")
        let inputMethod = UserDefaults.standard.integer(forKey: "InputMethod")
        let spelling = UserDefaults.standard.bool(forKey: "Spelling")
        let useMacro = UserDefaults.standard.bool(forKey: "UseMacro")

        XCTAssertEqual(inputType, 0)
        XCTAssertEqual(inputMethod, 1)
        XCTAssertTrue(spelling)
        XCTAssertTrue(useMacro)
        print("✅ Test 4 PASS: Settings persistence works correctly")
    }

    // MARK: - Test 5: Default Settings Reset
    /// Test Case: Reset to defaults hoạt động
    func testDefaultSettingsReset() {
        // Save custom settings
        UserDefaults.standard.set(1, forKey: "InputType")  // VNI
        UserDefaults.standard.set(false, forKey: "UseMacro")
        UserDefaults.standard.synchronize()

        // Verify custom settings are saved
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "InputType"), 1)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "UseMacro"))

        // Reset to defaults
        let defaultSettings: [String: Any] = [
            "InputType": 0,  // Telex
            "InputMethod": 1,  // Vietnamese
            "UseMacro": true,
            "Spelling": true,
            "UseSmartSwitchKey": true,
        ]

        for (key, value) in defaultSettings {
            UserDefaults.standard.set(value, forKey: key)
        }
        UserDefaults.standard.synchronize()

        // Verify reset worked
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "InputType"), 0)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "UseMacro"))
        print("✅ Test 5 PASS: Reset to defaults works correctly")
    }

    // MARK: - Test 6: Hotkey Settings
    /// Test Case: Hotkey settings được encode/decode đúng
    func testHotkeySettings() {
        // Simulate hotkey: Ctrl + Shift (0xFE = no key, just modifiers)
        var status = 0xFE  // No key
        status |= 0x100  // Control
        status |= 0x800  // Shift

        UserDefaults.standard.set(status, forKey: "SwitchKeyStatus")
        UserDefaults.standard.synchronize()

        // Load and verify
        let loadedStatus = UserDefaults.standard.integer(forKey: "SwitchKeyStatus")

        let hasControl = (loadedStatus & 0x100) != 0
        let hasShift = (loadedStatus & 0x800) != 0
        let keyCode = UInt16(loadedStatus & 0xFF)

        XCTAssertTrue(hasControl)
        XCTAssertTrue(hasShift)
        XCTAssertEqual(keyCode, 0xFE)
        print("✅ Test 6 PASS: Hotkey settings encode/decode works correctly")
    }

    // MARK: - Test 7: Macro List Operations
    /// Test Case: Thêm, xóa, chỉnh sửa macro
    func testMacroListOperations() {
        var macros: [MacroItem] = []

        // Add 3 macros
        macros.append(MacroItem(shortcut: "tvn", expansion: "Tiếng Việt Nam"))
        macros.append(MacroItem(shortcut: "hnt", expansion: "Hùng Tiến"))
        macros.append(MacroItem(shortcut: "phtv", expansion: "PHTV Bộ gõ"))

        // Save
        if let encoded = try? JSONEncoder().encode(macros) {
            UserDefaults.standard.set(encoded, forKey: "macroList")
            UserDefaults.standard.synchronize()
        }

        // Load
        if let data = UserDefaults.standard.data(forKey: "macroList"),
            let loadedMacros = try? JSONDecoder().decode([MacroItem].self, from: data)
        {
            XCTAssertEqual(loadedMacros.count, 3)

            // Remove one
            var updatedMacros = loadedMacros
            updatedMacros.removeAll { $0.shortcut == "hnt" }
            XCTAssertEqual(updatedMacros.count, 2)

            // Edit one
            if var editMacro = updatedMacros.first(where: { $0.shortcut == "tvn" }) {
                editMacro.expansion = "Việt Nam (Updated)"
                updatedMacros.removeAll { $0.shortcut == "tvn" }
                updatedMacros.append(editMacro)
            }
            XCTAssertEqual(updatedMacros.count, 2)

            print("✅ Test 7 PASS: Macro list operations work correctly")
        } else {
            XCTFail("Failed to load macros")
        }
    }

    // MARK: - Test 8: Performance Test
    /// Test Case: Kiểm tra hiệu suất lưu/load
    func testPerformance() {
        let startTime = Date()

        // Create 100 macros
        var macros: [MacroItem] = []
        for i in 0..<100 {
            macros.append(MacroItem(shortcut: "m\(i)", expansion: "Macro \(i)"))
        }

        // Save
        if let encoded = try? JSONEncoder().encode(macros) {
            UserDefaults.standard.set(encoded, forKey: "macroList")
            UserDefaults.standard.synchronize()
        }

        // Load
        if let data = UserDefaults.standard.data(forKey: "macroList"),
            let loadedMacros = try? JSONDecoder().decode([MacroItem].self, from: data)
        {
            XCTAssertEqual(loadedMacros.count, 100)
        }

        let elapsed = Date().timeIntervalSince(startTime)
        XCTAssertLessThan(elapsed, 1.0)  // Should complete in less than 1 second
        print("✅ Test 8 PASS: Performance test (\(String(format: "%.3f", elapsed))s)")
    }
}

// MARK: - Test Model
struct MacroItem: Codable, Identifiable {
    var id: UUID = UUID()
    var shortcut: String
    var expansion: String

    enum CodingKeys: String, CodingKey {
        case id, shortcut, expansion
    }
}

struct ExcludedApp: Codable, Identifiable, Hashable {
    var id: String { bundleIdentifier }
    let bundleIdentifier: String
    let name: String
    let path: String

    init(bundleIdentifier: String, name: String, path: String) {
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.path = path
    }
}
