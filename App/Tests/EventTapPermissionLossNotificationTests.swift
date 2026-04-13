//
//  EventTapPermissionLossNotificationTests.swift
//  PHTV
//
//  Verifies event-tap permission-loss notifications and bridge integration.
//

import XCTest
@testable import PHTV

@MainActor
final class EventTapPermissionLossNotificationTests: XCTestCase {
    func testMarkPermissionLostPostsNotificationOnlyOncePerLossTransition() async {
        PHTVEventTapService.resetPermissionLossForTesting()

        let onceExpectation = XCTNSNotificationExpectation(
            name: NotificationName.accessibilityPermissionLost
        )
        onceExpectation.expectedFulfillmentCount = 1
        onceExpectation.assertForOverFulfill = true

        PHTVEventTapService.markPermissionLost()
        PHTVEventTapService.markPermissionLost()

        await fulfillment(of: [onceExpectation], timeout: 1.0)

        PHTVEventTapService.resetPermissionLossForTesting()
    }

    func testResetPermissionLossAllowsNotificationForNextLossTransition() async {
        PHTVEventTapService.resetPermissionLossForTesting()

        let firstLoss = XCTNSNotificationExpectation(
            name: NotificationName.accessibilityPermissionLost
        )
        PHTVEventTapService.markPermissionLost()
        await fulfillment(of: [firstLoss], timeout: 1.0)

        PHTVEventTapService.resetPermissionLossForTesting()

        let secondLoss = XCTNSNotificationExpectation(
            name: NotificationName.accessibilityPermissionLost
        )
        PHTVEventTapService.markPermissionLost()
        await fulfillment(of: [secondLoss], timeout: 1.0)

        PHTVEventTapService.resetPermissionLossForTesting()
    }

    func testMarkPermissionLostDrivesAppDelegateRevokedHandlerThroughBridge() async {
        defer {
            phtvAccessibilityRevokedAlertRunner = phtvRunAccessibilityRevokedAlert
            PHTVEventTapService.resetPermissionLossForTesting()
        }

        let appDelegate = AppDelegate()
        appDelegate.setupSwiftUIBridge()
        defer { appDelegate.cancelManagedNotificationTasks() }

        appDelegate.automaticTCCRepairAttemptCount = Int.max
        PHTVEventTapService.resetPermissionLossForTesting()

        let alertPresented = expectation(description: "Revoked alert handler triggered from markPermissionLost")
        var callCount = 0

        phtvAccessibilityRevokedAlertRunner = {
            callCount += 1
            alertPresented.fulfill()
            return .alertSecondButtonReturn
        }

        await Task.yield()
        PHTVEventTapService.markPermissionLost()

        await fulfillment(of: [alertPresented], timeout: 1.0)
        XCTAssertEqual(callCount, 1)
    }
}
