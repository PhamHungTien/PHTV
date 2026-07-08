//
//  UpdateMaintenancePolicyTests.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import XCTest
@testable import PHTV

final class UpdateMaintenancePolicyTests: XCTestCase {

    // MARK: - shouldRunMaintenance

    func testRunsOnFirstLaunchAfterMechanismShipped() {
        XCTAssertTrue(PHTVUpdateMaintenancePolicy.shouldRunMaintenance(
            lastRunBuild: nil, currentBuild: "328"))
    }

    func testRunsWhenBuildChanged() {
        XCTAssertTrue(PHTVUpdateMaintenancePolicy.shouldRunMaintenance(
            lastRunBuild: "327", currentBuild: "328"))
    }

    func testSkipsWhenBuildUnchanged() {
        XCTAssertFalse(PHTVUpdateMaintenancePolicy.shouldRunMaintenance(
            lastRunBuild: "328", currentBuild: "328"))
    }

    func testSkipsWhenCurrentBuildUnknown() {
        XCTAssertFalse(PHTVUpdateMaintenancePolicy.shouldRunMaintenance(
            lastRunBuild: "327", currentBuild: ""))
    }

    func testRunsOnDowngradeSoRegistryStaysConsistent() {
        XCTAssertTrue(PHTVUpdateMaintenancePolicy.shouldRunMaintenance(
            lastRunBuild: "329", currentBuild: "328"))
    }

    // MARK: - canRemoveLegacyKey

    func testLegacyKeyRemovableOnlyAfterMigrationCompleted() {
        XCTAssertTrue(PHTVUpdateMaintenancePolicy.canRemoveLegacyKey(replacementHasValue: true))
        XCTAssertFalse(PHTVUpdateMaintenancePolicy.canRemoveLegacyKey(replacementHasValue: false))
    }

    // MARK: - isStaleTemporaryFile

    func testOldTemporaryFileIsStale() {
        let now = Date()
        let fourDaysAgo = now.addingTimeInterval(-4 * 24 * 60 * 60)
        XCTAssertTrue(PHTVUpdateMaintenancePolicy.isStaleTemporaryFile(
            modificationDate: fourDaysAgo, now: now, maxAge: 3 * 24 * 60 * 60))
    }

    func testRecentTemporaryFileIsKept() {
        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-3600)
        XCTAssertFalse(PHTVUpdateMaintenancePolicy.isStaleTemporaryFile(
            modificationDate: oneHourAgo, now: now, maxAge: 3 * 24 * 60 * 60))
    }

    func testFileWithUnknownDateIsKept() {
        XCTAssertFalse(PHTVUpdateMaintenancePolicy.isStaleTemporaryFile(
            modificationDate: nil, now: Date(), maxAge: 3 * 24 * 60 * 60))
    }
}
