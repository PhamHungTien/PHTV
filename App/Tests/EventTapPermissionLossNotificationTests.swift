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
        PHTVEventTapService.resetPermissionLossForTesting()
        // Keep app-hosted tests deterministic by avoiding modal UI from revoke handling.
        phtvAccessibilityRevokedAlertRunner = { .alertSecondButtonReturn }
        hostAppDelegate?.stopAccessibilityMonitoring()
        hostAppDelegate?.stopHealthCheckMonitoring()
        hostAppDelegate?.automaticTCCRepairAttemptCount = Int.max
    }

    override func tearDown() {
        phtvAccessibilityRevokedAlertRunner = phtvRunAccessibilityRevokedAlert
        PHTVEventTapService.resetPermissionLossForTesting()
        super.tearDown()
    }

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

        var readinessFalseCount = 0
        let token = NotificationCenter.default.addObserver(
            forName: NotificationName.accessibilityStatusChanged,
            object: nil,
            queue: nil
        ) { notification in
            guard let value = notification.object as? NSNumber,
                  value.boolValue == false else {
                return
            }
            readinessFalseCount += 1
        }
        defer { NotificationCenter.default.removeObserver(token) }

        PHTVEventTapService.markPermissionLost()
        PHTVEventTapService.markPermissionLost()

        await Task.yield()
        // Depending on host state, false may already be the last published readiness.
        // The invariant we enforce is "no duplicate false publish" for one loss transition.
        XCTAssertLessThanOrEqual(readinessFalseCount, 1)

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
        let bridge = makeBridgeDelegateForTest()
        defer { bridge.cleanup() }
        let appDelegate = bridge.delegate
        appDelegate.automaticTCCRepairAttemptCount = Int.max

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
        XCTAssertGreaterThanOrEqual(callCount, 1)
    }
}
