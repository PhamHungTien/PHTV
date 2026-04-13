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
    private var hostAppDelegate: AppDelegate? {
        AppDelegate.current()
    }

    private func makeBridgeDelegateForTest() -> (delegate: AppDelegate, cleanup: () -> Void) {
        if let host = hostAppDelegate {
            return (host, {})
        }

        let fallback = AppDelegate()
        fallback.setupSwiftUIBridge()
        return (fallback, {
            fallback.cancelManagedNotificationTasks()
        })
    }

    override func setUp() {
        super.setUp()
        phtvAccessibilityRevokedAlertRunner = { .alertSecondButtonReturn }
        hostAppDelegate?.stopAccessibilityMonitoring()
        hostAppDelegate?.stopHealthCheckMonitoring()
        hostAppDelegate?.automaticTCCRepairAttemptCount = Int.max
    }

    override func tearDown() {
        phtvAccessibilityRevokedAlertRunner = phtvRunAccessibilityRevokedAlert
        super.tearDown()
    }

    func testAccessibilityPermissionLostNotificationTriggersRevokedHandler() async {
        let bridge = makeBridgeDelegateForTest()
        defer { bridge.cleanup() }
        let appDelegate = bridge.delegate

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

        await fulfillment(of: [alertPresented], timeout: 2.0)
        XCTAssertGreaterThanOrEqual(callCount, 1)
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
