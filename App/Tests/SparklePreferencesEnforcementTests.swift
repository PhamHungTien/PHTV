//
//  SparklePreferencesEnforcementTests.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import XCTest
@testable import PHTV

final class SparklePreferencesEnforcementTests: XCTestCase {
    func testEnforcementNormalizesSparklePreferences() {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { clear(defaults: defaults, suiteName: suiteName) }

        defaults.set(true, forKey: UserDefaultsKey.sparkleBetaChannel)
        defaults.set(false, forKey: UserDefaultsKey.automaticUpdateChecks)
        defaults.set(false, forKey: UserDefaultsKey.autoInstallUpdates)
        defaults.set(false, forKey: UserDefaultsKey.legacyAutoInstallUpdates)

        XCTAssertTrue(defaults.requiresStableUpdateChannelEnforcement())
        XCTAssertTrue(defaults.enforceStableUpdateChannel())

        XCTAssertNil(defaults.object(forKey: UserDefaultsKey.sparkleBetaChannel))
        XCTAssertNil(defaults.object(forKey: UserDefaultsKey.legacyAutoInstallUpdates))
        XCTAssertTrue(defaults.bool(forKey: UserDefaultsKey.automaticUpdateChecks, default: false))
        XCTAssertTrue(defaults.bool(forKey: UserDefaultsKey.autoInstallUpdates, default: false))
        XCTAssertFalse(defaults.requiresStableUpdateChannelEnforcement())
    }

    func testNormalizedPreferencesRemainUntouched() {
        let (defaults, suiteName) = makeIsolatedDefaults()
        defer { clear(defaults: defaults, suiteName: suiteName) }

        defaults.set(true, forKey: UserDefaultsKey.automaticUpdateChecks)
        defaults.set(true, forKey: UserDefaultsKey.autoInstallUpdates)

        XCTAssertFalse(defaults.requiresStableUpdateChannelEnforcement())
        XCTAssertFalse(defaults.enforceStableUpdateChannel())
    }

    private func makeIsolatedDefaults() -> (UserDefaults, String) {
        let suiteName = "com.phamhungtien.phtv.tests.sparkle.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Unable to create isolated UserDefaults suite")
        }
        return (defaults, suiteName)
    }

    private func clear(defaults: UserDefaults, suiteName: String) {
        defaults.removePersistentDomain(forName: suiteName)
        defaults.synchronize()
        phtvRemoveUserDefaultsSuiteFilesForTesting(suiteName)
    }
}
