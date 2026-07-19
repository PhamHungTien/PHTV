//
//  LanguageLockPolicyTests.swift
//  PHTVTests
//
//  Created by Phạm Hùng Tiến on 2026.
//

import XCTest
@testable import PHTV

final class LanguageLockPolicyTests: XCTestCase {
    override func tearDown() {
        PHTVEngineRuntimeFacade.setEnglishLanguageLocked(false)
        PHTVEngineRuntimeFacade.setCurrentLanguage(1)
        super.tearDown()
    }

    func testVietnameseRequestIsForcedToEnglishWhileLocked() {
        XCTAssertEqual(
            PHTVLanguageLockPolicy.resolvedLanguage(
                requestedLanguage: 1,
                isEnglishLocked: true
            ),
            0
        )
    }

    func testEnglishRequestRemainsEnglishWhileLocked() {
        XCTAssertEqual(
            PHTVLanguageLockPolicy.resolvedLanguage(
                requestedLanguage: 0,
                isEnglishLocked: true
            ),
            0
        )
    }

    func testLanguageRequestPassesThroughWhenUnlocked() {
        XCTAssertEqual(
            PHTVLanguageLockPolicy.resolvedLanguage(
                requestedLanguage: 1,
                isEnglishLocked: false
            ),
            1
        )
    }

    func testRuntimeCannotEnableVietnameseUntilLockIsReleased() {
        PHTVEngineRuntimeFacade.setEnglishLanguageLocked(false)
        PHTVEngineRuntimeFacade.setCurrentLanguage(1)
        XCTAssertEqual(PHTVEngineRuntimeFacade.currentLanguage(), 1)

        PHTVEngineRuntimeFacade.setEnglishLanguageLocked(true)
        XCTAssertEqual(PHTVEngineRuntimeFacade.currentLanguage(), 0)

        PHTVEngineRuntimeFacade.setCurrentLanguage(1)
        XCTAssertEqual(PHTVEngineRuntimeFacade.currentLanguage(), 0)

        PHTVEngineRuntimeFacade.setEnglishLanguageLocked(false)
        PHTVEngineRuntimeFacade.setCurrentLanguage(1)
        XCTAssertEqual(PHTVEngineRuntimeFacade.currentLanguage(), 1)
    }
}
