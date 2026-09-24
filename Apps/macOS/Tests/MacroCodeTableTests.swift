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
        PHTVEngineRuntimeFacade.setNativeSystemTextReplacementMode(false)
        PHTVEngineRuntimeFacade.setQuickTelex(0)
        PHTVEngineRuntimeFacade.setAutoCapsMacro(0)
        PHTVEngineRuntimeFacade.setCheckSpelling(1)
        engineInitialize()
    }

    override func tearDown() {
        loadMacros([])
        PHTVEngineRuntimeFacade.setUseMacro(0)
        PHTVEngineRuntimeFacade.setNativeSystemTextReplacementMode(false)
        PHTVEngineRuntimeFacade.setQuickTelex(0)
        PHTVEngineRuntimeFacade.setCurrentCodeTable(0)
        engineInitialize()
        super.tearDown()
    }

    func testExcludedAppBlocksUserAndSystemMacrosInBothLanguages() {
        PHTVEngineRuntimeFacade.setMacroExcludedBundleIDs(["com.example.Editor"])
        defer {
            PHTVEngineRuntimeFacade.setMacroExcludedBundleIDs([])
            PHTVEngineRuntimeFacade.configureMacroTarget(bundleIdentifier: nil)
        }
        for type in [SnippetType.static, .systemTextReplacement] {
            loadMacros([MacroItem(shortcut: "zz", expansion: "Xin chào", snippetType: type)])
            for bundle in ["com.example.editor", "COM.EXAMPLE.EDITOR"] {
                PHTVEngineRuntimeFacade.configureMacroTarget(bundleIdentifier: bundle)
                XCTAssertEqual(PHTVEngineRuntimeFacade.useMacro(), 1, "Keep the global preference enabled")
                XCTAssertFalse(typedTokenTriggersMacro("zz"))
                let english = PHTVVietnameseEngine()
                for key in [KEY_Z, KEY_Z, KEY_SPACE] {
                    english.vEnglishMode(state: .keyDown, data: key, isCaps: false, otherControlKey: false)
                }
                XCTAssertNotEqual(english.hCode, HookCodeState.replaceMacro.rawValue)
                XCTAssertEqual(PHTVEngineRuntimeFacade.currentLanguage(), 1)
            }
            for bundle in ["com.example.editor.beta", "com.apple.TextEdit", nil] {
                PHTVEngineRuntimeFacade.configureMacroTarget(bundleIdentifier: bundle)
                XCTAssertTrue(typedTokenTriggersMacro("zz"))
                let english = PHTVVietnameseEngine()
                for key in [KEY_Z, KEY_Z, KEY_SPACE] {
                    english.vEnglishMode(state: .keyDown, data: key, isCaps: false, otherControlKey: false)
                }
                XCTAssertEqual(english.hCode, HookCodeState.replaceMacro.rawValue)
            }
        }
    }

    func testExclusionBoundaryClearsPartialShortcutAndRespectsGlobalOff() {
        loadMacros([MacroItem(shortcut: "zz", expansion: "Xin chào")])
        PHTVEngineRuntimeFacade.setMacroExcludedBundleIDs(["com.example.Editor"])
        defer {
            PHTVEngineRuntimeFacade.setMacroExcludedBundleIDs([])
            PHTVEngineRuntimeFacade.configureMacroTarget(bundleIdentifier: nil)
        }
        PHTVEngineRuntimeFacade.configureMacroTarget(bundleIdentifier: "com.apple.TextEdit")
        engineHandleEnglishMode(0, KEY_Z, 0, 0)
        engineHandleEnglishMode(0, KEY_Z, 0, 0)
        PHTVEngineRuntimeFacade.configureMacroTarget(bundleIdentifier: "com.example.Editor")
        PHTVEngineRuntimeFacade.configureMacroTarget(bundleIdentifier: "com.apple.TextEdit")
        engineHandleEnglishMode(0, KEY_SPACE, 0, 0)
        XCTAssertNotEqual(PHTVEngineRuntimeFacade.engineDataCode(), EngineSignalCode.replaceMacro)
        PHTVEngineRuntimeFacade.setUseMacro(0)
        XCTAssertFalse(typedTokenTriggersMacro("zz"))
    }

    // MARK: - Helpers

    private func loadMacros(_ macros: [MacroItem]) {
        let data = MacroStorage.engineBinaryData(from: macros)
        PHTVEngineDataBridge.initializeMacroMap(with: data)
    }

    private func nativeKeyCodes(for token: String) -> [UInt32] {
        token.map { character in
            let keyCode = UInt32(keyCode(for: Character(character.lowercased())))
            return character.isUppercase ? keyCode | EngineBitMask.caps : keyCode
        }
    }

    private func nativePrefixMatches(_ token: String) -> Bool {
        let candidate = nativeKeyCodes(for: token)
        return candidate.withUnsafeBufferPointer { buffer in
            phtvHasNativeTextReplacementPrefix(buffer.baseAddress, Int32(buffer.count)) != 0
        }
    }

    private func legacyNativePrefixMatch(
        _ candidate: [UInt32],
        macros: [MacroItem]
    ) -> Bool {
        var finalEntries: [[UInt32]: SnippetType] = [:]
        for macro in macros {
            finalEntries[nativeKeyCodes(for: macro.shortcut)] = macro.snippetType
        }

        for (macroKey, snippetType) in finalEntries
        where snippetType == .systemTextReplacement && macroKey.count >= candidate.count {
            let prefix = Array(macroKey.prefix(candidate.count))
            if prefix == candidate {
                return true
            }

            let loweredCandidate = candidate.map { $0 & ~EngineBitMask.caps }
            if loweredCandidate != candidate, prefix == loweredCandidate {
                return true
            }
        }
        return false
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
                data: keyCode(for: Character(ch.lowercased())),
                capsStatus: ch.isUppercase ? 1 : 0,
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

    func testSystemReplacementCapitalizationWithAutoCapsDisabled() {
        let macros = PHTVSystemTextReplacementService.mergedRuntimeMacros(
            userMacros: [],
            useSystemTextReplacements: true,
            rawItems: [["replace": "vd", "with": "ví dụ", "on": 1]]
        )
        loadMacros(macros)

        for nativeMode in [false, true] {
            PHTVEngineRuntimeFacade.setNativeSystemTextReplacementMode(nativeMode)
            for (token, expected) in [("Vd", "Ví dụ"), ("VD", "VÍ DỤ")] {
                let result = macroResult(afterTyping: token)
                XCTAssertTrue(result.didTrigger, "token=\(token), native=\(nativeMode)")
                XCTAssertEqual(result.backspaceCount, 2)
                XCTAssertEqual(
                    PHTVEngineDataBridge.macroString(fromMacroData: result.macroData, codeTable: 0),
                    expected
                )
            }
            let exact = macroResult(afterTyping: "vd")
            XCTAssertEqual(exact.didTrigger, !nativeMode)
            if !nativeMode {
                XCTAssertEqual(
                    PHTVEngineDataBridge.macroString(fromMacroData: exact.macroData, codeTable: 0),
                    "ví dụ"
                )
            }
        }
    }

    func testUserMacroStillRequiresAutoCapsForCapitalizedShortcut() {
        loadMacros([MacroItem(shortcut: "vd", expansion: "ví dụ")])
        XCTAssertFalse(typedTokenTriggersMacro("Vd"))
        PHTVEngineRuntimeFacade.setAutoCapsMacro(1)
        XCTAssertTrue(typedTokenTriggersMacro("Vd"))
        PHTVEngineRuntimeFacade.setAutoCapsMacro(0)
    }

    func testVNISystemTextReplacementExpandsThroughPHTV() {
        PHTVEngineRuntimeFacade.setCurrentInputType(VKeyInputType.vni.rawValue)
        PHTVEngineRuntimeFacade.setNativeSystemTextReplacementMode(false)
        loadMacros([
            MacroItem(
                shortcut: "dc",
                expansion: "được",
                snippetType: .systemTextReplacement
            )
        ])

        let result = macroResult(afterTyping: "dc")
        XCTAssertTrue(result.didTrigger)
        XCTAssertEqual(
            PHTVEngineDataBridge.macroString(
                fromMacroData: result.macroData,
                codeTable: Int32(CodeTable.unicode.toIndex())
            ),
            "được"
        )
    }

    // MARK: - Native Text Replacement prefix index

    func testNativeTextReplacementPrefixIndexMatchesLegacyScanSemantics() {
        let macros = [
            MacroItem(shortcut: "btw", expansion: "by the way", snippetType: .systemTextReplacement),
            MacroItem(shortcut: "hello", expansion: "hello world", snippetType: .systemTextReplacement),
            MacroItem(shortcut: "VIP", expansion: "important", snippetType: .systemTextReplacement),
            MacroItem(shortcut: "dup", expansion: "system", snippetType: .systemTextReplacement),
            MacroItem(shortcut: "dup", expansion: "user", snippetType: .static),
            MacroItem(shortcut: "win", expansion: "user", snippetType: .static),
            MacroItem(shortcut: "win", expansion: "system", snippetType: .systemTextReplacement),
            MacroItem(shortcut: "static", expansion: "local", snippetType: .static)
        ]
        loadMacros(macros)

        let candidates = [
            "b", "bt", "btw", "B", "BT", "BTW", "btwx",
            "h", "HEL", "hello", "helloo",
            "V", "VI", "VIP", "v", "vip",
            "d", "du", "dup", "w", "wi", "win", "z"
        ]

        for candidate in candidates {
            let keyCodes = nativeKeyCodes(for: candidate)
            XCTAssertEqual(
                nativePrefixMatches(candidate),
                legacyNativePrefixMatch(keyCodes, macros: macros),
                "candidate=\(candidate)"
            )
        }
    }

    func testNativeTextReplacementPrefixIndexUsesFinalDuplicateEntryType() {
        loadMacros([
            MacroItem(shortcut: "dup", expansion: "system", snippetType: .systemTextReplacement),
            MacroItem(shortcut: "dup", expansion: "user", snippetType: .static)
        ])
        XCTAssertFalse(nativePrefixMatches("d"))
        XCTAssertFalse(nativePrefixMatches("dup"))

        loadMacros([
            MacroItem(shortcut: "dup", expansion: "user", snippetType: .static),
            MacroItem(shortcut: "dup", expansion: "system", snippetType: .systemTextReplacement)
        ])
        XCTAssertTrue(nativePrefixMatches("d"))
        XCTAssertTrue(nativePrefixMatches("dup"))
    }

    func testNativeTextReplacementPrefixIndexReloadRemovesStalePrefixes() {
        loadMacros([
            MacroItem(shortcut: "alpha", expansion: "A", snippetType: .systemTextReplacement)
        ])
        XCTAssertTrue(nativePrefixMatches("a"))
        XCTAssertFalse(nativePrefixMatches("b"))

        loadMacros([
            MacroItem(shortcut: "beta", expansion: "B", snippetType: .systemTextReplacement)
        ])
        XCTAssertFalse(nativePrefixMatches("a"))
        XCTAssertTrue(nativePrefixMatches("b"))

        loadMacros([])
        XCTAssertFalse(nativePrefixMatches("b"))
    }

    func testNativeTextReplacementPrefixIndexPreservesCapitalizationSemantics() {
        loadMacros([
            MacroItem(shortcut: "lower", expansion: "lowercase", snippetType: .systemTextReplacement),
            MacroItem(shortcut: "UPPER", expansion: "uppercase", snippetType: .systemTextReplacement)
        ])

        XCTAssertTrue(nativePrefixMatches("LOW"))
        XCTAssertTrue(nativePrefixMatches("Lower"))
        XCTAssertTrue(nativePrefixMatches("UP"))
        XCTAssertFalse(nativePrefixMatches("up"))
    }

    func testNativeTextReplacementPrefixIndexSurvivesCodeTableSwitches() {
        PHTVEngineRuntimeFacade.setCurrentCodeTable(2)
        loadMacros([
            MacroItem(shortcut: "btw", expansion: "by the way", snippetType: .systemTextReplacement)
        ])

        for codeTable in [0, 3, 2, 0] {
            PHTVEngineRuntimeFacade.setCurrentCodeTable(Int32(codeTable))
            XCTAssertTrue(nativePrefixMatches("b"), "codeTable=\(codeTable)")
            XCTAssertTrue(nativePrefixMatches("BTW"), "codeTable=\(codeTable)")
        }
    }

    func testNativeTextReplacementPrefixIndexHandlesLongShortcuts() {
        let shortcut = String(repeating: "a", count: 200)
        loadMacros([
            MacroItem(
                shortcut: shortcut,
                expansion: "long replacement",
                snippetType: .systemTextReplacement
            )
        ])

        XCTAssertTrue(nativePrefixMatches(String(shortcut.prefix(199))))
        XCTAssertTrue(nativePrefixMatches(shortcut))
        XCTAssertFalse(nativePrefixMatches(shortcut + "a"))
    }

    func testNativeTextReplacementPrefixIndexSupportsConcurrentReloadAndLookup() {
        let dataA = MacroStorage.engineBinaryData(from: [
            MacroItem(shortcut: "alpha", expansion: "A", snippetType: .systemTextReplacement)
        ])
        let dataB = MacroStorage.engineBinaryData(from: [
            MacroItem(shortcut: "beta", expansion: "B", snippetType: .systemTextReplacement)
        ])
        let candidateA = nativeKeyCodes(for: "a")
        let candidateB = nativeKeyCodes(for: "b")

        DispatchQueue.concurrentPerform(iterations: 8) { worker in
            for iteration in 0..<200 {
                if worker == 0 {
                    PHTVEngineDataBridge.initializeMacroMap(
                        with: iteration.isMultiple(of: 2) ? dataA : dataB
                    )
                } else {
                    let candidate = iteration.isMultiple(of: 2) ? candidateA : candidateB
                    _ = candidate.withUnsafeBufferPointer { buffer in
                        phtvHasNativeTextReplacementPrefix(
                            buffer.baseAddress,
                            Int32(buffer.count)
                        )
                    }
                }
            }
        }

        PHTVEngineDataBridge.initializeMacroMap(with: dataB)
        XCTAssertFalse(nativePrefixMatches("a"))
        XCTAssertTrue(nativePrefixMatches("b"))
    }
}
