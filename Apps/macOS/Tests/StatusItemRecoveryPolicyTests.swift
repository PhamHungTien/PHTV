//
//  StatusItemRecoveryPolicyTests.swift
//  PHTV
//

import Foundation
import XCTest
@testable import PHTV

final class StatusItemRecoveryPolicyTests: XCTestCase {
    func testMacOS27UsesLongerRecoveryDelay() {
        XCTAssertEqual(
            PHTVStatusItemRecoveryPolicy.delay(
                operatingSystemVersion: OperatingSystemVersion(majorVersion: 27, minorVersion: 0, patchVersion: 0)
            ),
            .milliseconds(1_250)
        )
    }

    func testOlderMacOSUsesStandardRecoveryDelay() {
        XCTAssertEqual(
            PHTVStatusItemRecoveryPolicy.delay(
                operatingSystemVersion: OperatingSystemVersion(majorVersion: 26, minorVersion: 6, patchVersion: 0)
            ),
            .milliseconds(750)
        )
    }

    func testLaterMacOSAutomaticallyReturnsToStandardDelay() {
        XCTAssertEqual(
            PHTVStatusItemRecoveryPolicy.delay(
                operatingSystemVersion: OperatingSystemVersion(majorVersion: 28, minorVersion: 0, patchVersion: 0)
            ),
            .milliseconds(750)
        )
    }
}
