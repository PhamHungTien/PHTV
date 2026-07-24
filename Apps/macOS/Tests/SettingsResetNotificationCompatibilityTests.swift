//
//  SettingsResetNotificationCompatibilityTests.swift
//  PHTV
//
//  Verifies reset-notification compatibility for SwiftUI/AppDelegate bridge.
//  Created by Phạm Hùng Tiến on 2026.
//

import XCTest
@testable import PHTV

@MainActor
final class SettingsResetNotificationCompatibilityTests: XCTestCase {
    func testLegacySettingsResetNotificationStillTriggersResetComplete() async {
        let appDelegate = AppDelegate()
        appDelegate.setupSwiftUIBridge()
        defer { appDelegate.cancelManagedNotificationTasks() }

        await Task.yield()

        let notificationExpectation = XCTNSNotificationExpectation(
            name: NotificationName.settingsResetComplete
        )

        NotificationCenter.default.post(name: NotificationName.settingsReset, object: nil)

        await fulfillment(of: [notificationExpectation], timeout: 1.0)
    }

    func testSettingsResetToDefaultsNotificationTriggersResetComplete() async {
        let appDelegate = AppDelegate()
        appDelegate.setupSwiftUIBridge()
        defer { appDelegate.cancelManagedNotificationTasks() }

        await Task.yield()

        let notificationExpectation = XCTNSNotificationExpectation(
            name: NotificationName.settingsResetComplete
        )

        NotificationCenter.default.post(name: NotificationName.settingsResetToDefaults, object: nil)

        await fulfillment(of: [notificationExpectation], timeout: 1.0)
    }
}
