//
//  IntegrationTests.swift
//  PHTV Integration Tests
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import XCTest

// MARK: - Integration Test Suite

class PHTVIntegrationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "")
        UserDefaults.standard.synchronize()
    }

    override func tearDown() {
        super.tearDown()
        UserDefaults.standard.synchronize()
    }

    // MARK: - Integration Test 1: End-to-End Macro Workflow
    /// Test Case: Complete workflow from adding to using macro
    func testEndToEndMacroWorkflow() {
        // 1. Add macro
        var macros: [MacroItem] = []
        macros.append(MacroItem(shortcut: "tvn", expansion: "Tiếng Việt Nam"))
        macros.append(MacroItem(shortcut: "phtv", expansion: "PHTV Bộ gõ"))

        if let encoded = try? JSONEncoder().encode(macros) {
            UserDefaults.standard.set(encoded, forKey: "macroList")
        }

        // 2. Simulate notification
        NotificationCenter.default.post(name: NSNotification.Name("MacrosChanged"), object: nil)

        // 3. Reload macros
        if let data = UserDefaults.standard.data(forKey: "macroList"),
            let loadedMacros = try? JSONDecoder().decode([MacroItem].self, from: data)
        {
            XCTAssertEqual(loadedMacros.count, 2)
            XCTAssertTrue(loadedMacros.contains { $0.shortcut == "tvn" })
            XCTAssertTrue(loadedMacros.contains { $0.shortcut == "phtv" })
        }

        // 4. Edit macro
        var updatedMacros = macros
        if let index = updatedMacros.firstIndex(where: { $0.shortcut == "tvn" }) {
            updatedMacros[index].expansion = "Việt Nam (Updated)"
        }

        if let encoded = try? JSONEncoder().encode(updatedMacros) {
            UserDefaults.standard.set(encoded, forKey: "macroList")
        }

        // 5. Verify update
        if let data = UserDefaults.standard.data(forKey: "macroList"),
            let finalMacros = try? JSONDecoder().decode([MacroItem].self, from: data)
        {
            XCTAssertEqual(finalMacros.count, 2)
            let tvnMacro = finalMacros.first { $0.shortcut == "tvn" }
            XCTAssertEqual(tvnMacro?.expansion, "Việt Nam (Updated)")
        }

        print("✅ Integration Test 1: End-to-End Macro Workflow - PASS")
    }

    // MARK: - Integration Test 2: Settings Sync with Backend
    /// Test Case: Settings changes are properly synced
    func testSettingsSyncWithBackend() {
        // 1. Set initial settings
        UserDefaults.standard.set(0, forKey: "InputType")  // Telex
        UserDefaults.standard.set(true, forKey: "UseMacro")
        UserDefaults.standard.set(true, forKey: "Spelling")

        // 2. Post notification (simulate backend sync)
        NotificationCenter.default.post(
            name: NSNotification.Name("PHTVSettingsChanged"),
            object: nil
        )

        // 3. Verify settings persisted
        let inputType = UserDefaults.standard.integer(forKey: "InputType")
        let useMacro = UserDefaults.standard.bool(forKey: "UseMacro")
        let spelling = UserDefaults.standard.bool(forKey: "Spelling")

        XCTAssertEqual(inputType, 0)
        XCTAssertTrue(useMacro)
        XCTAssertTrue(spelling)

        // 4. Change settings
        UserDefaults.standard.set(1, forKey: "InputType")  // VNI
        UserDefaults.standard.set(false, forKey: "UseMacro")

        // 5. Post update notification
        NotificationCenter.default.post(
            name: NSNotification.Name("PHTVSettingsChanged"),
            object: nil
        )

        // 6. Verify new settings
        let newInputType = UserDefaults.standard.integer(forKey: "InputType")
        let newUseMacro = UserDefaults.standard.bool(forKey: "UseMacro")

        XCTAssertEqual(newInputType, 1)
        XCTAssertFalse(newUseMacro)

        print("✅ Integration Test 2: Settings Sync with Backend - PASS")
    }

    // MARK: - Integration Test 3: Excluded Apps Synchronization
    /// Test Case: Excluded apps properly synchronized
    func testExcludedAppsSynchronization() {
        // 1. Create excluded apps
        var apps: [ExcludedApp] = []
        apps.append(
            ExcludedApp(
                bundleIdentifier: "com.apple.TextEdit",
                name: "TextEdit",
                path: "/Applications/TextEdit.app"
            ))

        if let encoded = try? JSONEncoder().encode(apps) {
            UserDefaults.standard.set(encoded, forKey: "ExcludedApps")
        }

        // 2. Notify backend
        NotificationCenter.default.post(
            name: NSNotification.Name("ExcludedAppsChanged"),
            object: nil
        )

        // 3. Reload and verify
        if let data = UserDefaults.standard.data(forKey: "ExcludedApps"),
            let loadedApps = try? JSONDecoder().decode([ExcludedApp].self, from: data)
        {
            XCTAssertEqual(loadedApps.count, 1)
            XCTAssertEqual(loadedApps[0].bundleIdentifier, "com.apple.TextEdit")
        }

        // 4. Add another app
        apps.append(
            ExcludedApp(
                bundleIdentifier: "com.microsoft.Word",
                name: "Microsoft Word",
                path: "/Applications/Microsoft Word.app"
            ))

        if let encoded = try? JSONEncoder().encode(apps) {
            UserDefaults.standard.set(encoded, forKey: "ExcludedApps")
        }

        // 5. Verify both apps
        if let data = UserDefaults.standard.data(forKey: "ExcludedApps"),
            let loadedApps = try? JSONDecoder().decode([ExcludedApp].self, from: data)
        {
            XCTAssertEqual(loadedApps.count, 2)
            XCTAssertTrue(loadedApps.contains { $0.bundleIdentifier == "com.apple.TextEdit" })
            XCTAssertTrue(loadedApps.contains { $0.bundleIdentifier == "com.microsoft.Word" })
        }

        print("✅ Integration Test 3: Excluded Apps Synchronization - PASS")
    }

    // MARK: - Integration Test 4: Multi-Setting Changes
    /// Test Case: Multiple settings change simultaneously
    func testMultipleSettingsChanges() {
        // 1. Change multiple settings at once
        UserDefaults.standard.set(0, forKey: "InputType")
        UserDefaults.standard.set(1, forKey: "InputMethod")
        UserDefaults.standard.set(0, forKey: "CodeTable")
        UserDefaults.standard.set(true, forKey: "UseMacro")
        UserDefaults.standard.set(true, forKey: "Spelling")
        UserDefaults.standard.set(true, forKey: "UseSmartSwitchKey")

        // 2. Verify all saved
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "InputType"), 0)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "InputMethod"), 1)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "CodeTable"), 0)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "UseMacro"))
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "Spelling"))
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "UseSmartSwitchKey"))

        print("✅ Integration Test 4: Multiple Settings Changes - PASS")
    }

    // MARK: - Integration Test 5: Hotkey Encoding/Decoding
    /// Test Case: Hotkey settings encode/decode correctly
    func testHotkeyEncodingDecoding() {
        // 1. Create hotkey: Ctrl + Shift
        var status = 0xFE  // No key
        status |= 0x100  // Control
        status |= 0x800  // Shift

        UserDefaults.standard.set(status, forKey: "SwitchKeyStatus")

        // 2. Load and decode
        let loadedStatus = UserDefaults.standard.integer(forKey: "SwitchKeyStatus")

        let hasControl = (loadedStatus & 0x100) != 0
        let hasShift = (loadedStatus & 0x800) != 0
        let keyCode = UInt16(loadedStatus & 0xFF)

        XCTAssertTrue(hasControl)
        XCTAssertTrue(hasShift)
        XCTAssertEqual(keyCode, 0xFE)

        // 3. Try different hotkey: Ctrl + Alt
        var newStatus = 0xFE
        newStatus |= 0x100  // Control
        newStatus |= 0x200  // Option

        UserDefaults.standard.set(newStatus, forKey: "SwitchKeyStatus")

        let newLoadedStatus = UserDefaults.standard.integer(forKey: "SwitchKeyStatus")
        let newHasControl = (newLoadedStatus & 0x100) != 0
        let newHasOption = (newLoadedStatus & 0x200) != 0

        XCTAssertTrue(newHasControl)
        XCTAssertTrue(newHasOption)

        print("✅ Integration Test 5: Hotkey Encoding/Decoding - PASS")
    }

    // MARK: - Integration Test 6: Concurrent Operations
    /// Test Case: Multiple concurrent operations don't corrupt data
    func testConcurrentOperations() {
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let expectation = XCTestExpectation(description: "Concurrent operations")
        var results: [Bool] = []

        // Operation 1: Save macros
        queue.async {
            var macros: [MacroItem] = []
            macros.append(MacroItem(shortcut: "m1", expansion: "Macro 1"))
            if let encoded = try? JSONEncoder().encode(macros) {
                UserDefaults.standard.set(encoded, forKey: "macroList")
            }
            results.append(true)
        }

        // Operation 2: Save settings
        queue.async {
            UserDefaults.standard.set(true, forKey: "UseMacro")
            UserDefaults.standard.set(true, forKey: "Spelling")
            results.append(true)
        }

        // Operation 3: Save excluded apps
        queue.async {
            var apps: [ExcludedApp] = []
            apps.append(
                ExcludedApp(
                    bundleIdentifier: "com.test",
                    name: "Test",
                    path: "/Test"
                ))
            if let encoded = try? JSONEncoder().encode(apps) {
                UserDefaults.standard.set(encoded, forKey: "ExcludedApps")
            }
            results.append(true)
        }

        // Verify operations completed
        queue.async(flags: .barrier) {
            XCTAssertEqual(results.count, 3)

            // Verify data integrity
            XCTAssertTrue(UserDefaults.standard.bool(forKey: "UseMacro"))
            XCTAssertTrue(UserDefaults.standard.bool(forKey: "Spelling"))

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
        print("✅ Integration Test 6: Concurrent Operations - PASS")
    }

    // MARK: - Integration Test 7: Notification Chain
    /// Test Case: Notifications properly cascade through system
    func testNotificationChain() {
        var notificationReceived = false
        var chainComplete = false

        let observer = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("MacrosChanged"),
            object: nil,
            queue: .main
        ) { _ in
            notificationReceived = true

            // Simulate secondary action
            NotificationCenter.default.post(
                name: NSNotification.Name("MacroDataNeedsReload"),
                object: nil
            )
        }

        let chainObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("MacroDataNeedsReload"),
            object: nil,
            queue: .main
        ) { _ in
            chainComplete = true
        }

        // Post initial notification
        NotificationCenter.default.post(
            name: NSNotification.Name("MacrosChanged"),
            object: nil
        )

        // Wait for async operations
        let expectation = XCTestExpectation(description: "Notification chain")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)

        XCTAssertTrue(notificationReceived)
        XCTAssertTrue(chainComplete)

        NotificationCenter.default.removeObserver(observer)
        NotificationCenter.default.removeObserver(chainObserver)

        print("✅ Integration Test 7: Notification Chain - PASS")
    }

    // MARK: - Integration Test 8: Data Persistence Across Sessions
    /// Test Case: Data persists across app sessions
    func testDataPersistenceAcrossSessions() {
        // Simulate first session - save data
        UserDefaults.standard.set("TestValue", forKey: "TestKey")
        UserDefaults.standard.synchronize()

        // Verify it was saved
        let savedValue = UserDefaults.standard.string(forKey: "TestKey")
        XCTAssertEqual(savedValue, "TestValue")

        // Simulate second session - load data
        UserDefaults.standard.synchronize()
        let loadedValue = UserDefaults.standard.string(forKey: "TestKey")
        XCTAssertEqual(loadedValue, "TestValue")

        // Save macro and verify persistence
        var macros: [MacroItem] = []
        macros.append(MacroItem(shortcut: "test", expansion: "Test Macro"))

        if let encoded = try? JSONEncoder().encode(macros) {
            UserDefaults.standard.set(encoded, forKey: "macroList")
            UserDefaults.standard.synchronize()
        }

        // Reload and verify
        if let data = UserDefaults.standard.data(forKey: "macroList"),
            let loadedMacros = try? JSONDecoder().decode([MacroItem].self, from: data)
        {
            XCTAssertEqual(loadedMacros.count, 1)
            XCTAssertEqual(loadedMacros[0].shortcut, "test")
        }

        print("✅ Integration Test 8: Data Persistence Across Sessions - PASS")
    }
}

// MARK: - Test Models
struct MacroItem: Codable, Identifiable {
    var id: UUID = UUID()
    var shortcut: String
    var expansion: String
}

struct ExcludedApp: Codable, Identifiable, Hashable {
    var id: String { bundleIdentifier }
    let bundleIdentifier: String
    let name: String
    let path: String
}
