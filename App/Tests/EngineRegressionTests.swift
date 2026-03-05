// EngineRegressionTests.swift
// PHEngineTests
//
// Port of tests/engine/EngineRegressionTests.cpp → Swift XCTest
// Created by Phạm Hùng Tiến on 2026.

import XCTest
@testable import PHTV

final class EngineRegressionTests: XCTestCase {

    // MARK: - Constants

    private let eventKeyboard: Int32 = 0  // PHTV_ENGINE_EVENT_KEYBOARD
    private let stateKeyDown: Int32  = 0  // PHTV_ENGINE_EVENT_STATE_KEY_DOWN

    // MARK: - Suite setup / teardown

    // Dictionaries are already loaded by PHTV.app at launch (applicationDidFinishLaunching
    // calls initEnglishWordDictionary). No extra setup needed for the hosted test target.

    override class func tearDown() {
        phtvCustomDictionaryClear()
        super.tearDown()
    }

    // MARK: - Per-test setup

    override func setUp() {
        super.setUp()
        // Reset runtime to defaults matching the C++ test binary defaults
        PHTVEngineRuntimeFacade.setCurrentInputType(0)          // Telex
        PHTVEngineRuntimeFacade.setAutoRestoreEnglishWord(1)
        PHTVEngineRuntimeFacade.setCheckSpelling(1)
        PHTVEngineRuntimeFacade.setUseModernOrthography(1)
        PHTVEngineRuntimeFacade.setQuickTelex(0)
        PHTVEngineRuntimeFacade.setFreeMark(0)
        PHTVEngineRuntimeFacade.setAllowConsonantZFWJ(1)
        PHTVEngineRuntimeFacade.setQuickStartConsonant(0)
        PHTVEngineRuntimeFacade.setQuickEndConsonant(0)
        PHTVEngineRuntimeFacade.setUseMacro(0)
        phtvCustomDictionaryClear()
        engineInitialize()
    }

    // MARK: - Helpers

    private func setCustomEnglishWords(_ words: [String]) {
        phtvCustomDictionaryClear()
        guard !words.isEmpty else { return }
        var json = "["
        for (i, w) in words.enumerated() {
            if i > 0 { json += "," }
            json += "{\"word\":\"\(w)\",\"type\":\"en\"}"
        }
        json += "]"
        phtvCustomDictionaryLoadJSON(json, Int32(json.utf8.count))
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
        case "0": return KEY_0; case "1": return KEY_1; case "2": return KEY_2
        case "3": return KEY_3; case "4": return KEY_4; case "5": return KEY_5
        case "6": return KEY_6; case "7": return KEY_7; case "8": return KEY_8
        case "9": return KEY_9
        default:  return KEY_SPACE
        }
    }

    private func feedWord(_ token: String) {
        for ch in token {
            let code = keyCode(for: ch)
            engineHandleEvent(eventKeyboard, stateKeyDown, code, 0, 0)
        }
    }

    private func isRestore(_ code: Int32) -> Bool {
        code == HookCodeState.restore.rawValue ||
        code == HookCodeState.restoreAndStartNewSession.rawValue
    }

    private func decodeOutputCharacter(_ data: UInt32, codeTable: Int32) -> UInt16 {
        let capsMask = EngineBitMask.caps
        let pureCharacterMask = EngineBitMask.pureCharacter
        let charCodeMask = EngineBitMask.charCode

        if (data & pureCharacterMask) != 0 {
            return UInt16(truncatingIfNeeded: data & ~capsMask)
        }
        if (data & charCodeMask) == 0 {
            return EngineMacroKeyMap.character(for: data)
        }
        if codeTable == Int32(CodeTable.unicode.toIndex()) {
            return UInt16(truncatingIfNeeded: data & 0xFFFF)
        }
        return EnginePackedData.lowByte(data)
    }

    private func hookOutputWord() -> String {
        let count = Int(engineHookNewCharCount())
        guard count > 0 else { return "" }
        let codeTable = PHTVEngineRuntimeFacade.currentCodeTable()
        var scalars: [UnicodeScalar] = []
        scalars.reserveCapacity(count)
        for i in stride(from: count - 1, through: 0, by: -1) {
            let codePoint = decodeOutputCharacter(engineHookCharAt(Int32(i)), codeTable: codeTable)
            guard codePoint != 0, let scalar = UnicodeScalar(Int(codePoint)) else { continue }
            scalars.append(scalar)
        }
        return String(String.UnicodeScalarView(scalars))
    }

    private func renderedTypingWord(_ engine: PHTVVietnameseEngine) -> String {
        let codeTable = PHTVEngineRuntimeFacade.currentCodeTable()
        var scalars: [UnicodeScalar] = []
        scalars.reserveCapacity(engine.idx)
        for i in 0..<engine.idx {
            let packed = engine.getCharacterCode(engine.typingWord[i])
            let codePoint = decodeOutputCharacter(packed, codeTable: codeTable)
            guard codePoint != 0, let scalar = UnicodeScalar(Int(codePoint)) else { continue }
            scalars.append(scalar)
        }
        return String(String.UnicodeScalarView(scalars))
    }

    private func renderedToken(_ token: String) -> String {
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
        return renderedTypingWord(engine)
    }

    private func runSpaceCase(
        _ token: String,
        customEnglish: [String] = [],
        expectRestore: Bool,
        autoRestoreEnglish: Bool = true,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        setCustomEnglishWords(customEnglish)
        let saved = PHTVEngineRuntimeFacade.autoRestoreEnglishWord()
        PHTVEngineRuntimeFacade.setAutoRestoreEnglishWord(autoRestoreEnglish ? 1 : 0)
        defer { PHTVEngineRuntimeFacade.setAutoRestoreEnglishWord(saved) }
        engineInitialize()
        feedWord(token)
        engineHandleEvent(eventKeyboard, stateKeyDown, KEY_SPACE, 0, 0)
        let restored = isRestore(engineHookCode())
        XCTAssertEqual(restored, expectRestore,
            "SPACE: token='\(token)' expectRestore=\(expectRestore) got code=\(engineHookCode())",
            file: file, line: line)
    }

    private func runWordBreakCase(
        _ token: String,
        customEnglish: [String] = [],
        expectRestore: Bool,
        autoRestoreEnglish: Bool = true,
        breakKey: UInt16 = KEY_DOT,
        breakCaps: UInt8 = 0,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        setCustomEnglishWords(customEnglish)
        let saved = PHTVEngineRuntimeFacade.autoRestoreEnglishWord()
        PHTVEngineRuntimeFacade.setAutoRestoreEnglishWord(autoRestoreEnglish ? 1 : 0)
        defer { PHTVEngineRuntimeFacade.setAutoRestoreEnglishWord(saved) }
        engineInitialize()
        feedWord(token)
        engineHandleEvent(eventKeyboard, stateKeyDown, breakKey, breakCaps, 0)
        let restored = isRestore(engineHookCode())
        XCTAssertEqual(restored, expectRestore,
            "BREAK(key=\(breakKey),caps=\(breakCaps)): token='\(token)' expectRestore=\(expectRestore) got code=\(engineHookCode())",
            file: file, line: line)
    }

    private func runQuickConsonantSpaceCase(
        _ token: String,
        customEnglish: [String] = [],
        quickStart: Bool,
        quickEnd: Bool,
        expectedOutput: String,
        expectedBackspaceCount: Int,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        setCustomEnglishWords(customEnglish)
        let savedQuickStart = PHTVEngineRuntimeFacade.quickStartConsonant()
        let savedQuickEnd = PHTVEngineRuntimeFacade.quickEndConsonant()
        defer {
            PHTVEngineRuntimeFacade.setQuickStartConsonant(savedQuickStart)
            PHTVEngineRuntimeFacade.setQuickEndConsonant(savedQuickEnd)
        }

        PHTVEngineRuntimeFacade.setQuickStartConsonant(quickStart ? 1 : 0)
        PHTVEngineRuntimeFacade.setQuickEndConsonant(quickEnd ? 1 : 0)

        engineInitialize()
        feedWord(token)
        engineHandleEvent(eventKeyboard, stateKeyDown, KEY_SPACE, 0, 0)

        XCTAssertTrue(
            isRestore(engineHookCode()),
            "Quick consonant should trigger restore flow, got code=\(engineHookCode())",
            file: file, line: line
        )
        XCTAssertEqual(
            Int(engineHookBackspaceCount()),
            expectedBackspaceCount,
            "Unexpected backspace count for token='\(token)'",
            file: file, line: line
        )
        XCTAssertEqual(
            hookOutputWord(),
            expectedOutput,
            "SPACE quick-consonant mismatch for token='\(token)'",
            file: file, line: line
        )
    }

    // MARK: - Space tests

    func testCustomEnglishTerminalRestoresOnSpace() {
        runSpaceCase("terminal", customEnglish: ["terminal"], expectRestore: true)
    }

    func testCustomEnglishQesRestoresOnSpace() {
        runSpaceCase("qes", customEnglish: ["qes"], expectRestore: true)
    }

    func testAlnumInt1234NoRestoreOnSpace() {
        runSpaceCase("int1234", customEnglish: ["int"], expectRestore: false)
    }

    func testTelexConflictTerminal1234RestoresOnSpace() {
        runSpaceCase("terminal1234", customEnglish: ["terminal"], expectRestore: true)
    }

    func testWrongSpellingUserRestoresOnSpace() {
        runSpaceCase("user", expectRestore: true, autoRestoreEnglish: false)
    }

    // MARK: - Word-break (DOT) tests

    func testCustomEnglishTerminalRestoresOnDot() {
        runWordBreakCase("terminal", customEnglish: ["terminal"], expectRestore: true)
    }

    func testTelexConflictTerminal1234RestoresOnDot() {
        runWordBreakCase("terminal1234", customEnglish: ["terminal"], expectRestore: true)
    }

    func testAlnumInt1234NoRestoreOnDot() {
        runWordBreakCase("int1234", customEnglish: ["int"], expectRestore: false)
    }

    func testWrongSpellingUserRestoresOnDot() {
        runWordBreakCase("user", expectRestore: true, autoRestoreEnglish: false)
    }

    // MARK: - Word-break (other punctuation) tests

    func testCustomEnglishRestoresOnComma() {
        runWordBreakCase("terminal", customEnglish: ["terminal"], expectRestore: true,
                         breakKey: KEY_COMMA)
    }

    func testCustomEnglishRestoresOnQuestionMark() {
        runWordBreakCase("terminal", customEnglish: ["terminal"], expectRestore: true,
                         breakKey: KEY_SLASH, breakCaps: 1)
    }

    func testCustomEnglishRestoresOnExclamationMark() {
        runWordBreakCase("terminal", customEnglish: ["terminal"], expectRestore: true,
                         breakKey: KEY_1, breakCaps: 1)
    }

    func testCustomEnglishRestoresOnLeftParenthesis() {
        runWordBreakCase("terminal", customEnglish: ["terminal"], expectRestore: true,
                         breakKey: KEY_9, breakCaps: 1)
    }

    func testCustomEnglishRestoresOnRightParenthesis() {
        runWordBreakCase("terminal", customEnglish: ["terminal"], expectRestore: true,
                         breakKey: KEY_0, breakCaps: 1)
    }

    func testCustomEnglishRestoresOnLeftBracket() {
        runWordBreakCase("terminal", customEnglish: ["terminal"], expectRestore: true,
                         breakKey: KEY_LEFT_BRACKET)
    }

    func testTelexConflictRestoresOnRightBracket() {
        runWordBreakCase("terminal1234", customEnglish: ["terminal"], expectRestore: true,
                         breakKey: KEY_RIGHT_BRACKET)
    }

    func testAlnumNoRestoreOnExclamationMark() {
        runWordBreakCase("int1234", customEnglish: ["int"], expectRestore: false,
                         breakKey: KEY_1, breakCaps: 1)
    }

    func testAlnumNoRestoreOnRightParenthesis() {
        runWordBreakCase("int1234", customEnglish: ["int"], expectRestore: false,
                         breakKey: KEY_0, breakCaps: 1)
    }

    func testWrongSpellingRestoresOnExclamationMark() {
        runWordBreakCase("user", expectRestore: true, autoRestoreEnglish: false,
                         breakKey: KEY_1, breakCaps: 1)
    }

    // MARK: - Quick consonant tests

    func testQuickStartConsonantWorksWithAutoRestoreEnglishOn() {
        runQuickConsonantSpaceCase(
            "fan",
            customEnglish: ["fan"],
            quickStart: true,
            quickEnd: false,
            expectedOutput: "phan",
            expectedBackspaceCount: 3
        )
    }

    func testQuickEndConsonantWorksWithAutoRestoreEnglishOn() {
        runQuickConsonantSpaceCase(
            "nah",
            customEnglish: ["nah"],
            quickStart: false,
            quickEnd: true,
            expectedOutput: "nh",
            expectedBackspaceCount: 1
        )
    }

    func testQuickStartAndQuickEndWorkTogetherWithAutoRestoreEnglishOn() {
        runQuickConsonantSpaceCase(
            "fag",
            customEnglish: ["fag"],
            quickStart: true,
            quickEnd: true,
            expectedOutput: "phang",
            expectedBackspaceCount: 3
        )
    }

    // MARK: - Issue #136: wrong-spelling fallback missing in handleWordBreak

    func testKosovoRestoresOnComma() {
        // "koosvo" in Telex produces "kốvo" (oo→ô, s adds sắc).
        // Not in English dict → wrong-spelling fallback must fire on comma with autoRestoreEnglish on.
        runWordBreakCase("koosvo", expectRestore: true, breakKey: KEY_COMMA)
    }

    func testKosovoRestoresOnDot() {
        // Same token, verifies the fallback works for dot as well.
        runWordBreakCase("koosvo", expectRestore: true)
    }

    func testRoothideRestoresOnComma() {
        // "roothide" in Telex produces "rôthide" (oo→ô).
        // Not in English dict → wrong-spelling fallback must fire on comma.
        runWordBreakCase("roothide", expectRestore: true, breakKey: KEY_COMMA)
    }

    func testNoobRestoresOnSpace() {
        // "noob" in Telex produces "nôb" (oo→ô). "noob" is in the English dictionary.
        runSpaceCase("noob", expectRestore: true)
    }

    func testNoobRestoresOnComma() {
        // "noob" is in the English dictionary; must restore on comma via main detection path.
        runWordBreakCase("noob", expectRestore: true, breakKey: KEY_COMMA)
    }

    // MARK: - Issue #135: Telex Vietnamese words must not auto-restore as English on space

    func testDakLakVariantDawksDoesNotRestoreOnSpace() {
        runSpaceCase("dawks", expectRestore: false)
    }

    func testDakLakVariantDawksProducesMarkedSyllable() {
        XCTAssertEqual(renderedToken("dawks"), "dắk")
    }

    func testDakLakVariantDawskDoesNotRestoreOnSpace() {
        runSpaceCase("dawsk", expectRestore: false)
    }

    func testDakLakVariantDaswkDoesNotRestoreOnSpace() {
        runSpaceCase("daswk", expectRestore: false)
    }

    func testDakLakVariantLawksDoesNotRestoreOnSpace() {
        runSpaceCase("lawks", expectRestore: false)
    }

    func testDakLakVariantLawksProducesMarkedSyllable() {
        XCTAssertEqual(renderedToken("lawks"), "lắk")
    }

    func testDakLakVariantLawskDoesNotRestoreOnSpace() {
        runSpaceCase("lawsk", expectRestore: false)
    }

    func testDakLakVariantLaswkDoesNotRestoreOnSpace() {
        runSpaceCase("laswk", expectRestore: false)
    }

    // MARK: - sips/sisp → síp conflict (#issue)

    func testSipsDoesNotRestoreOnSpace() {
        runSpaceCase("sips", expectRestore: false)
    }

    func testSispDoesNotRestoreOnSpace() {
        runSpaceCase("sisp", expectRestore: false)
    }

    func testSipsProducesMarkedSyllable() {
        XCTAssertEqual(renderedToken("sips"), "síp")
    }

    func testSispProducesMarkedSyllable() {
        XCTAssertEqual(renderedToken("sisp"), "síp")
    }
}
