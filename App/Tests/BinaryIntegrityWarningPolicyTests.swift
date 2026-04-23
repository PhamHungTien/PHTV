//
//  BinaryIntegrityWarningPolicyTests.swift
//  PHTV
//
//  Regression tests for dev-build friendly binary warning policy.
//

import XCTest
@testable import PHTV

final class BinaryIntegrityWarningPolicyTests: XCTestCase {
    func testApplicationsInstallPathKeepsActionableWarning() {
        XCTAssertTrue(
            phtvShouldElevateBinaryModificationWarning(bundlePath: "/Applications/PHTV.app")
        )
    }

    func testDerivedDataPathDoesNotElevateWarning() {
        XCTAssertFalse(
            phtvShouldElevateBinaryModificationWarning(
                bundlePath: "/Users/test/Library/Developer/Xcode/DerivedData/PHTV/Build/Products/Debug/PHTV.app"
            )
        )
    }

    func testWorkspaceLocalBundleDoesNotElevateWarning() {
        XCTAssertFalse(
            phtvShouldElevateBinaryModificationWarning(
                bundlePath: "/Users/test/Documents/PHTV/dist/PHTV.app"
            )
        )
    }
}
