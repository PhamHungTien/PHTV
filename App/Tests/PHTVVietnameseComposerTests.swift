//
//  PHTVVietnameseComposerTests.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import XCTest
@testable import PHTV
@testable import PHTVInputMethod

final class PHTVVietnameseComposerTests: XCTestCase {
    private let composer = PHTVVietnameseComposer()

    func testTelexToneMarkerRecognitionWithRawVowelW() {
        // "mwfng" -> "mừng" (w first, f tone marker)
        XCTAssertEqual(composer.compose("mwfng", style: .telex), "mừng")
        XCTAssertEqual(composer.compose("mwf", style: .telex), "mừ")
        XCTAssertEqual(composer.compose("dwfng", style: .telex), "dừng")
        XCTAssertEqual(composer.compose("ddwfng", style: .telex), "đừng")
        XCTAssertEqual(composer.compose("duowngf", style: .telex), "dường")
        XCTAssertEqual(composer.compose("dduowngf", style: .telex), "đường")
        XCTAssertEqual(composer.compose("suownf", style: .telex), "sườn")
    }

    func testTonePlacementForInitialConsonantGI() {
        // "giups" -> "giúp" (tone on u, not on i)
        XCTAssertEqual(composer.compose("giups", style: .telex), "giúp")
        XCTAssertEqual(composer.compose("giangr", style: .telex), "giảng")
        XCTAssertEqual(composer.compose("giayf", style: .telex), "giày")
        XCTAssertEqual(composer.compose("gieets", style: .telex), "giết")
        XCTAssertEqual(composer.compose("gioir", style: .telex), "giỏi")
        
        // Single vowel cases with "gi"
        XCTAssertEqual(composer.compose("gif", style: .telex), "gì")
        XCTAssertEqual(composer.compose("ginf", style: .telex), "gìn")
    }

    func testTonePlacementForInitialConsonantQU() {
        // "quans" -> "quán" (tone on a, not on u)
        XCTAssertEqual(composer.compose("quans", style: .telex), "quán")
        XCTAssertEqual(composer.compose("quawns", style: .telex), "quắn")
        XCTAssertEqual(composer.compose("queor", style: .telex), "quẻo")
        XCTAssertEqual(composer.compose("quys", style: .telex), "quý")
        XCTAssertEqual(composer.compose("quyeets", style: .telex), "quyết")
    }

    func testTraditionalRegressionCases() {
        // "sai" -> "sai" (s at start should not be consumed as acute)
        XCTAssertEqual(composer.compose("sai", style: .telex), "sai")
        XCTAssertEqual(composer.compose("sau", style: .telex), "sau")
        XCTAssertEqual(composer.compose("fan", style: .telex), "fan")
        XCTAssertEqual(composer.compose("rum", style: .telex), "rum")
        XCTAssertEqual(composer.compose("xin", style: .telex), "xin")
        XCTAssertEqual(composer.compose("jam", style: .telex), "jam")
        XCTAssertEqual(composer.compose("zap", style: .telex), "zap")
        
        // "huowsng" -> "hướng"
        XCTAssertEqual(composer.compose("huowsng", style: .telex), "hướng")
    }

    func testVowelCombinationEdgeCases() {
        // "khoas" -> "khoá"
        XCTAssertEqual(composer.compose("khoas", style: .telex), "khoá")
        // "khuys" -> "khuý"
        XCTAssertEqual(composer.compose("khuys", style: .telex), "khuý")
        // "hoaf" -> "hoà"
        XCTAssertEqual(composer.compose("hoaf", style: .telex), "hoà")
    }

    func testVNIMethodEdgeCases() {
        // VNI method tests
        XCTAssertEqual(composer.compose("mu7ng2", style: .vni), "mừng")
        XCTAssertEqual(composer.compose("giu1p", style: .vni), "giúp")
        XCTAssertEqual(composer.compose("qua1n", style: .vni), "quán")
        XCTAssertEqual(composer.compose("sai", style: .vni), "sai")
    }

    func testSpellingNormalization() {
        // Telex spelling normalization for ươ
        XCTAssertEqual(composer.compose("huwongs", style: .telex), "hướng")
        XCTAssertEqual(composer.compose("huwong", style: .telex), "hương")
        XCTAssertEqual(composer.compose("huongw", style: .telex), "hương")
        XCTAssertEqual(composer.compose("huongws", style: .telex), "hướng")
        XCTAssertEqual(composer.compose("HUWONGS", style: .telex), "HƯỚNG")
        XCTAssertEqual(composer.compose("Huwongs", style: .telex), "Hướng")

        // VNI spelling normalization for ươ
        XCTAssertEqual(composer.compose("hu7ong", style: .vni), "hương")
        XCTAssertEqual(composer.compose("huong7", style: .vni), "hương")
        XCTAssertEqual(composer.compose("hu7ong1", style: .vni), "hướng")
        XCTAssertEqual(composer.compose("huong71", style: .vni), "hướng")
        XCTAssertEqual(composer.compose("HU7ONG1", style: .vni), "HƯỚNG")
        XCTAssertEqual(composer.compose("Hu7ong1", style: .vni), "Hướng")

        // Precomposed/Partial composition normalization
        XCTAssertEqual(composer.compose("hứo", style: .telex), "hướ")
        XCTAssertEqual(composer.compose("huớ", style: .telex), "hướ")
        XCTAssertEqual(composer.compose("hứong", style: .telex), "hướng")
        XCTAssertEqual(composer.compose("huớng", style: .telex), "hướng")
        XCTAssertEqual(composer.compose("Hứong", style: .telex), "Hướng")
        XCTAssertEqual(composer.compose("HUỚNG", style: .telex), "HƯỚNG")
    }

    func testAutoRestoreEnglish() {
        // English words that should not be mangled
        XCTAssertEqual(composer.compose("terminal", style: .telex), "terminal")
        XCTAssertEqual(composer.compose("microsoft", style: .telex), "microsoft")
        XCTAssertEqual(composer.compose("clear", style: .telex), "clear")
        XCTAssertEqual(composer.compose("email", style: .telex), "email")
        XCTAssertEqual(composer.compose("install", style: .telex), "install")
        XCTAssertEqual(composer.compose("facebook", style: .telex), "facebook")
        XCTAssertEqual(composer.compose("google", style: .telex), "google")
        XCTAssertEqual(composer.compose("local", style: .telex), "local")
        XCTAssertEqual(composer.compose("internet", style: .telex), "internet")
        
        // With autoRestore disabled
        XCTAssertNotEqual(composer.compose("terminal", style: .telex, autoRestore: false), "terminal")
        
        // Single-syllable English words that are invalid in Vietnamese
        XCTAssertEqual(composer.compose("free", style: .telex), "free")
        XCTAssertEqual(composer.compose("book", style: .telex), "book")
        XCTAssertEqual(composer.compose("good", style: .telex), "good")
        XCTAssertEqual(composer.compose("size", style: .telex), "size")
        XCTAssertEqual(composer.compose("code", style: .telex), "code")
        XCTAssertEqual(composer.compose("make", style: .telex), "make")
        
        // Check that standard Vietnamese typing remains 100% unaffected
        XCTAssertEqual(composer.compose("mwfng", style: .telex), "mừng")
        XCTAssertEqual(composer.compose("giups", style: .telex), "giúp")
        XCTAssertEqual(composer.compose("quans", style: .telex), "quán")
        XCTAssertEqual(composer.compose("huowsng", style: .telex), "hướng")
        XCTAssertEqual(composer.compose("xoong", style: .telex), "xông")
    }
}
