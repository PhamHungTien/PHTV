//
//  RemoteViewCrashGuardPolicyTests.swift
//  PHTV
//

import Foundation
import XCTest
@testable import PHTV

final class RemoteViewCrashGuardPolicyTests: XCTestCase {
    func testGuardAppliesAcrossMacOS27BetaBuilds() {
        XCTAssertTrue(
            PHTVRemoteViewCrashGuardPolicy.shouldInstall(
                operatingSystemVersion: OperatingSystemVersion(majorVersion: 27, minorVersion: 0, patchVersion: 0)
            )
        )
    }

    func testGuardDoesNotAlterOlderMacOSReleases() {
        XCTAssertFalse(
            PHTVRemoteViewCrashGuardPolicy.shouldInstall(
                operatingSystemVersion: OperatingSystemVersion(majorVersion: 26, minorVersion: 6, patchVersion: 0)
            )
        )
    }

    func testGuardIsRetiredAutomaticallyForLaterMajorVersions() {
        XCTAssertFalse(
            PHTVRemoteViewCrashGuardPolicy.shouldInstall(
                operatingSystemVersion: OperatingSystemVersion(majorVersion: 28, minorVersion: 0, patchVersion: 0)
            )
        )
    }
}
