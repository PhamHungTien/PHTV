//
//  MacroCodeTableTests.swift
//  PHTV
//
//  Regression coverage for issue #146: macros (Gõ Tắt / macOS Text
//  Replacements) must keep matching regardless of which code table was
//  active when the macro map was loaded, and diacritic shortcuts must work.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import XCTest
@testable import PHTV

final class MacroCodeTableTests: XCTestCase {
    func testMacroStringDecodesUnicodeAndSupplementaryScalarsForWholeTextInsertion() {
        let macroData: [UInt32] = [
            UInt32(0x0111) | EngineBitMask.charCode,
            UInt32(0x1F642) | EngineBitMask.pureCharacter
        ]

        XCTAssertEqual(
            PHTVEngineDataBridge.macroString(
                fromMacroData: macroData,
                codeTable: Int32(CodeTable.unicode.toIndex())
            ),
            "đ🙂"
        )
    }

    func testMacroStringPreservesUnicodeCompoundOutput() {
        let acuteA = UInt32((1 << 13) | 0x0061) | EngineBitMask.charCode

        XCTAssertEqual(
            PHTVEngineDataBridge.macroString(
                fromMacroData: [acuteA],
                codeTable: Int32(CodeTable.unicodeComposite.toIndex())
            ),
            "a\u{0301}"
        )
    }

    func testLongUnicodeMacroPayloadSurvivesEngineRoundTripWithoutTruncation() {
        let expansion = String(repeating: "Nội dung thử nghiệm dài. ", count: 80)
        XCTAssertGreaterThan(expansion.count, 1_564)
        loadMacros([MacroItem(shortcut: "zz", expansion: expansion)])

        let result = macroResult(afterTyping: "zz")
        XCTAssertTrue(result.didTrigger)
        XCTAssertEqual(
            PHTVEngineDataBridge.macroString(
                fromMacroData: result.macroData,
                codeTable: Int32(CodeTable.unicode.toIndex())
            ),
            expansion
        )
    }

    override func setUp() {
        super.setUp()
        PHTVEngineRuntimeFacade.setCurrentLanguage(1)   // Vietnamese
        PHTVEngineRuntimeFacade.setCurrentInputType(0)  // Telex
        PHTVEngineRuntimeFacade.setCurrentCodeTable(0)  // Unicode
        PHTVEngineRuntimeFacade.setUseMacro(1)
        PHTVEngineRuntimeFacade.setQuickTelex(0)
        PHTVEngineRuntimeFacade.setAutoCapsMacro(0)
        PHTVEngineRuntimeFacade.setCheckSpelling(1)
        engineInitialize()
    }

    override func tearDown() {
        loadMacros([])
        PHTVEngineRuntimeFacade.setUseMacro(0)
        PHTVEngineRuntimeFacade.setQuickTelex(0)
        PHTVEngineRuntimeFacade.setCurrentCodeTable(0)
        engineInitialize()
        super.tearDown()
    }

    // MARK: - Helpers

    private func loadMacros(_ macros: [MacroItem]) {
        let data = MacroStorage.engineBinaryData(from: macros)
        PHTVEngineDataBridge.initializeMacroMap(with: data)
    }

    private func keyCode(for ch: Character) -> UInt16 {
        switch ch {
        case "a": return KEY_A; case "b": return KEY_B; case "c": return KEY_C
        case "d": return KEY_D; case "e": return KEY_E; case "f": return KEY_F
        case "g": return KEY_G; case "h": return KEY_H; case "i": return KEY_I
        case "j": return KEY_J; case "k": return KEY_K; case "l": return KEY_L
        case "m": return KEY_M; case "n": return KEY_N; case "o": return KEY_O
        case "p": return KEY_P; case "q": return KEY_Q; case "r": return KEY_R
        case "s": return KEY_S; case "t": return KEY_T; case "u": return KEY_U
        case "v": return KEY_V; case "w": return KEY_W; case "x": return KEY_X
        case "y": return KEY_Y; case "z": return KEY_Z
        default:  return KEY_SPACE
        }
    }

    /// Types the token then a space; returns true when the engine signaled a
    /// macro replacement on the space.
    private func typedTokenTriggersMacro(_ token: String) -> Bool {
        macroResult(afterTyping: token).didTrigger
    }

    private func macroResult(afterTyping token: String) -> (didTrigger: Bool, macroData: [UInt32], backspaceCount: Int) {
        // App-hosted tests can schedule unrelated session work against the
        // process singleton. A local engine keeps this fixture's keystroke
        // sequence atomic while exercising the same runtime macro map.
        let engine = PHTVVietnameseEngine()
        engine.refreshRuntimeLayoutSnapshot()
        engine.startNewSession()
        for ch in token {
            engine.vKeyHandleEvent(
                event: .keyboard,
                state: .keyDown,
                data: keyCode(for: ch),
                capsStatus: 0,
                otherControlKey: false
            )
        }
        engine.vKeyHandleEvent(
            event: .keyboard,
            state: .keyDown,
            data: UInt16(KEY_SPACE),
            capsStatus: 0,
            otherControlKey: false
        )
        return (
            engine.hCode == HookCodeState.replaceMacro.rawValue,
            engine.hMacroData,
            engine.hBPC
        )
    }

    // MARK: - Baseline

    func testAsciiMacroTriggersOnSpace() {
        loadMacros([MacroItem(shortcut: "btw", expansion: "by the way")])
        XCTAssertTrue(typedTokenTriggersMacro("btw"))
    }

    func testAsciiMacroTracksRawShortcutWhileQuickTelexExpandsVisibleText() {
        PHTVEngineRuntimeFacade.setQuickTelex(1)
        loadMacros([MacroItem(shortcut: "btw", expansion: "by the way")])

        let result = macroResult(afterTyping: "btw")

        XCTAssertTrue(result.didTrigger)
        XCTAssertEqual(result.backspaceCount, 4) // `btw` is displayed as `bthw`.
    }

    func testUnrelatedTokenDoesNotTriggerMacro() {
        loadMacros([MacroItem(shortcut: "btw", expansion: "by the way")])
        XCTAssertFalse(typedTokenTriggersMacro("hello"))
    }

    // MARK: - Diacritic shortcuts (issue #146)

    func testDiacriticShortcutMatchesComposedTyping() {
        // Shortcut "bò" is typed in Telex as b-o-f.
        loadMacros([MacroItem(shortcut: "bò", expansion: "bao nhiêu")])
        XCTAssertTrue(typedTokenTriggersMacro("bof"))
    }

    func testDiacriticShortcutSurvivesCodeTableSwitch() {
        // Map loaded while a non-Unicode table is active, then the user (or
        // Smart Switch) changes to Unicode: lookups must still match.
        PHTVEngineRuntimeFacade.setCurrentCodeTable(2) // VNI Windows
        loadMacros([MacroItem(shortcut: "bò", expansion: "bao nhiêu")])

        PHTVEngineRuntimeFacade.setCurrentCodeTable(0) // Unicode
        XCTAssertTrue(typedTokenTriggersMacro("bof"))
    }

    func testAsciiShortcutSurvivesCodeTableSwitch() {
        PHTVEngineRuntimeFacade.setCurrentCodeTable(2)
        loadMacros([MacroItem(shortcut: "btw", expansion: "by the way")])

        PHTVEngineRuntimeFacade.setCurrentCodeTable(0)
        XCTAssertTrue(typedTokenTriggersMacro("btw"))
    }

    func testDiacriticShortcutSurvivesTemporaryUnicodeOverride() {
        // The Spotlight path temporarily forces the Unicode table mid-event;
        // macros loaded under another table must still match during it.
        PHTVEngineRuntimeFacade.setCurrentCodeTable(3) // Unicode Compound
        loadMacros([MacroItem(shortcut: "bò", expansion: "bao nhiêu")])

        PHTVEngineRuntimeFacade.setCurrentCodeTable(0)
        let matchedDuringOverride = typedTokenTriggersMacro("bof")
        PHTVEngineRuntimeFacade.setCurrentCodeTable(3)

        XCTAssertTrue(matchedDuringOverride)
    }

    // MARK: - Native deferral must never swallow diacritic shortcuts (issue #146)

    func testCanDeferShortcutToNativeOnlyForASCII() {
        XCTAssertTrue(PHTVSystemTextReplacementService.canDeferShortcutToNative("btw"))
        XCTAssertTrue(PHTVSystemTextReplacementService.canDeferShortcutToNative("cd"))
        XCTAssertFalse(PHTVSystemTextReplacementService.canDeferShortcutToNative("cđ"))
        XCTAssertFalse(PHTVSystemTextReplacementService.canDeferShortcutToNative("đt"))
        XCTAssertFalse(PHTVSystemTextReplacementService.canDeferShortcutToNative("bò"))
        XCTAssertFalse(PHTVSystemTextReplacementService.canDeferShortcutToNative(""))
        XCTAssertFalse(PHTVSystemTextReplacementService.canDeferShortcutToNative("   "))
    }

    private func snippetType(of shortcut: String, in macros: [MacroItem]) -> SnippetType? {
        macros.first { $0.shortcut == shortcut }?.snippetType
    }

    func testDiacriticUserMacroNeverDefersEvenWhenCollidingWithSystemEntry() {
        // Same shortcut exists in both PHTV and macOS Text Replacements.
        let user = [MacroItem(shortcut: "cđ", expansion: "cũng được")]
        let systemRaw: [[String: Any]] = [["replace": "cđ", "with": "cũng được", "on": 1]]

        let merged = PHTVSystemTextReplacementService.mergedRuntimeMacros(
            userMacros: user, useSystemTextReplacements: true, rawItems: systemRaw)

        // Must stay PHTV-handled so the shortcut actually expands.
        XCTAssertEqual(snippetType(of: "cđ", in: merged), .static)
    }

    func testAsciiUserMacroStillDefersWhenCollidingWithSystemEntry() {
        let user = [MacroItem(shortcut: "btw", expansion: "by the way")]
        let systemRaw: [[String: Any]] = [["replace": "btw", "with": "by the way", "on": 1]]

        let merged = PHTVSystemTextReplacementService.mergedRuntimeMacros(
            userMacros: user, useSystemTextReplacements: true, rawItems: systemRaw)

        XCTAssertEqual(snippetType(of: "btw", in: merged), .systemTextReplacement)
    }

    func testImportedDiacriticSystemEntryIsHandledByPHTV() {
        let systemRaw: [[String: Any]] = [
            ["replace": "đc", "with": "được", "on": 1],
            ["replace": "omw", "with": "on my way", "on": 1]
        ]

        let merged = PHTVSystemTextReplacementService.mergedRuntimeMacros(
            userMacros: [], useSystemTextReplacements: true, rawItems: systemRaw)

        XCTAssertEqual(snippetType(of: "đc", in: merged), .static)
        XCTAssertEqual(snippetType(of: "omw", in: merged), .systemTextReplacement)
    }
}
