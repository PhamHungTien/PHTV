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

    func testMarkPermissionLostPublishesReadinessFalseOnlyOncePerLossTransition() async {
        PHTVEventTapService.resetPermissionLossForTesting()

        let readinessFalseExpectation = XCTNSNotificationExpectation(
            name: NotificationName.accessibilityStatusChanged
        ) { (notification: Notification) in
            guard let value = notification.object as? NSNumber else {
                return false
            }
            return value.boolValue == false
        }
        readinessFalseExpectation.expectedFulfillmentCount = 1
        readinessFalseExpectation.assertForOverFulfill = true

        PHTVEventTapService.markPermissionLost()
        PHTVEventTapService.markPermissionLost()

        await fulfillment(of: [readinessFalseExpectation], timeout: 1.0)

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

    func testBridgeDedupesWithinSameLossAndRearmsAfterReset() async {
        defer {
            phtvAccessibilityRevokedAlertRunner = phtvRunAccessibilityRevokedAlert
            PHTVEventTapService.resetPermissionLossForTesting()
        }

        let appDelegate = AppDelegate()
        appDelegate.setupSwiftUIBridge()
        defer { appDelegate.cancelManagedNotificationTasks() }

        appDelegate.automaticTCCRepairAttemptCount = Int.max
        PHTVEventTapService.resetPermissionLossForTesting()

        let firstAlert = expectation(description: "First revoked alert should be presented")
        let secondAlert = expectation(description: "Second revoked alert should be presented after reset")

        var callCount = 0
        phtvAccessibilityRevokedAlertRunner = {
            callCount += 1
            if callCount == 1 {
                firstAlert.fulfill()
            } else if callCount == 2 {
                secondAlert.fulfill()
            }
            return .alertSecondButtonReturn
        }

        await Task.yield()

        PHTVEventTapService.markPermissionLost()
        PHTVEventTapService.markPermissionLost()
        await fulfillment(of: [firstAlert], timeout: 1.0)
        XCTAssertEqual(callCount, 1)

        PHTVEventTapService.resetPermissionLossForTesting()
        PHTVEventTapService.markPermissionLost()

        await fulfillment(of: [secondAlert], timeout: 1.0)
        XCTAssertEqual(callCount, 2)
    }
}
