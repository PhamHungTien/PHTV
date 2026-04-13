//
//  AccessibilityPermissionLossFlowTests.swift
//  PHTV
//
//  Verifies AccessibilityPermissionLost notification routing and re-entrant alert protection.
//

import XCTest
@testable import PHTV

@MainActor
final class AccessibilityPermissionLossFlowTests: XCTestCase {
    func testAccessibilityPermissionLostNotificationTriggersRevokedHandler() async {
        defer { phtvAccessibilityRevokedAlertRunner = phtvRunAccessibilityRevokedAlert }

        let appDelegate = AppDelegate()
        appDelegate.setupSwiftUIBridge()
        defer { appDelegate.cancelManagedNotificationTasks() }

        // Keep this test focused on notification routing and avoid background TCC repair work.
        appDelegate.automaticTCCRepairAttemptCount = Int.max

        let alertPresented = expectation(description: "Accessibility revoked alert runner called")
        var callCount = 0

        phtvAccessibilityRevokedAlertRunner = {
            callCount += 1
            alertPresented.fulfill()
            return .alertSecondButtonReturn
        }

        await Task.yield()
        NotificationCenter.default.post(name: NotificationName.accessibilityPermissionLost, object: nil)

        await fulfillment(of: [alertPresented], timeout: 1.0)
        XCTAssertEqual(callCount, 1)
    }

    func testHandleAccessibilityRevokedBlocksReentrantAlertPresentation() {
        defer { phtvAccessibilityRevokedAlertRunner = phtvRunAccessibilityRevokedAlert }

        let appDelegate = AppDelegate()
        appDelegate.automaticTCCRepairAttemptCount = Int.max

        var callCount = 0
        phtvAccessibilityRevokedAlertRunner = {
            callCount += 1
            appDelegate.handleAccessibilityRevoked()
            return .alertSecondButtonReturn
        }

        appDelegate.handleAccessibilityRevoked()

        XCTAssertEqual(callCount, 1)
    }
}
