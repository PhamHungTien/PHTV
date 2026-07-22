//
//  UpperCaseExcludeScopeTests.swift
//  PHTV
//
//  Coverage for per-language auto-capitalize exclusion (issue #152):
//  an app may suppress auto-capitalize for English only (an IDE), for
//  Vietnamese only, or for both (the original behaviour).
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import XCTest
@testable import PHTV

final class UpperCaseExcludeScopeTests: XCTestCase {

    // MARK: - Runtime encoding

    func testRuntimeValueForEachScope() {
        XCTAssertEqual(PHTVUpperCaseExclusion.runtimeValue(for: nil), PHTVUpperCaseExclusion.none)
        XCTAssertEqual(PHTVUpperCaseExclusion.runtimeValue(for: .both), PHTVUpperCaseExclusion.both)
        XCTAssertEqual(PHTVUpperCaseExclusion.runtimeValue(for: .englishOnly), PHTVUpperCaseExclusion.englishOnly)
        XCTAssertEqual(PHTVUpperCaseExclusion.runtimeValue(for: .vietnameseOnly), PHTVUpperCaseExclusion.vietnameseOnly)
    }

    // MARK: - Effective exclusion per typing language

    func testAppNotInListNeverExcludes() {
        for vietnamese in [true, false] {
            XCTAssertFalse(PHTVUpperCaseExclusion.isExcluded(
                runtimeValue: PHTVUpperCaseExclusion.none, typingVietnamese: vietnamese))
        }
    }

    func testBothScopeExcludesInEitherLanguage() {
        XCTAssertTrue(PHTVUpperCaseExclusion.isExcluded(
            runtimeValue: PHTVUpperCaseExclusion.both, typingVietnamese: true))
        XCTAssertTrue(PHTVUpperCaseExclusion.isExcluded(
            runtimeValue: PHTVUpperCaseExclusion.both, typingVietnamese: false))
    }

    func testEnglishOnlyScopeKeepsVietnameseCapitalization() {
        // The IDE case from the request: no auto-capitalize while typing
        // English code, but Vietnamese comments still capitalize.
        XCTAssertTrue(PHTVUpperCaseExclusion.isExcluded(
            runtimeValue: PHTVUpperCaseExclusion.englishOnly, typingVietnamese: false))
        XCTAssertFalse(PHTVUpperCaseExclusion.isExcluded(
            runtimeValue: PHTVUpperCaseExclusion.englishOnly, typingVietnamese: true))
    }

    func testVietnameseOnlyScopeKeepsEnglishCapitalization() {
        XCTAssertTrue(PHTVUpperCaseExclusion.isExcluded(
            runtimeValue: PHTVUpperCaseExclusion.vietnameseOnly, typingVietnamese: true))
        XCTAssertFalse(PHTVUpperCaseExclusion.isExcluded(
            runtimeValue: PHTVUpperCaseExclusion.vietnameseOnly, typingVietnamese: false))
    }

    func testUnknownRuntimeValueDoesNotExclude() {
        // A corrupted value must never silently disable auto-capitalize.
        XCTAssertFalse(PHTVUpperCaseExclusion.isExcluded(runtimeValue: 99, typingVietnamese: true))
        XCTAssertFalse(PHTVUpperCaseExclusion.isExcluded(runtimeValue: -1, typingVietnamese: false))
    }

    // MARK: - Persistence stays backward compatible

    func testLegacyEntryWithoutScopeDecodesAsBoth() throws {
        // Entries saved before this setting existed have no `upperCaseScope`
        // key; they must keep behaving exactly as before the upgrade.
        let legacyJSON = """
        [{"bundleIdentifier":"com.apple.dt.Xcode","name":"Xcode","path":"/Applications/Xcode.app"}]
        """
        let data = try XCTUnwrap(legacyJSON.data(using: .utf8))

        let apps = try JSONDecoder().decode([ExcludedApp].self, from: data)

        XCTAssertEqual(apps.count, 1)
        XCTAssertEqual(apps[0].upperCaseScope, .both)
    }

    func testScopeSurvivesEncodeDecodeRoundTrip() throws {
        let original = ExcludedApp(
            bundleIdentifier: "com.apple.dt.Xcode",
            name: "Xcode",
            path: "/Applications/Xcode.app",
            upperCaseScope: .englishOnly
        )

        let data = try JSONEncoder().encode([original])
        let decoded = try JSONDecoder().decode([ExcludedApp].self, from: data)

        XCTAssertEqual(decoded.first?.upperCaseScope, .englishOnly)
    }

    func testNewEntryDefaultsToBoth() {
        let app = ExcludedApp(bundleIdentifier: "a.b.c", name: "App", path: "/App.app")
        XCTAssertEqual(app.upperCaseScope, .both, "Adding an app must keep the original behaviour")
    }
}
