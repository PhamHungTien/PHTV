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
        PHTVEngineRuntimeFacade.setRestoreIfWrongSpelling(0)
        PHTVEngineRuntimeFacade.setCheckSpelling(1)
        PHTVEngineRuntimeFacade.setUseModernOrthography(1)
        PHTVEngineRuntimeFacade.setQuickTelex(0)
        PHTVEngineRuntimeFacade.setFreeMark(0)
        PHTVEngineRuntimeFacade.setAllowConsonantZFWJ(1)
        PHTVEngineRuntimeFacade.setQuickStartConsonant(0)
        PHTVEngineRuntimeFacade.setQuickEndConsonant(0)
        PHTVEngineRuntimeFacade.setUpperCaseFirstChar(0)
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

    private func customDictionaryContainsVietnameseWord(_ word: String) -> Bool {
        word.withCString { ptr in
            phtvCustomDictionaryContainsVietnameseWord(ptr) != 0
        }
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

    private func feedWord(_ token: String, rendered: inout String) {
        for ch in token {
            let code = keyCode(for: ch)
            engineHandleEvent(eventKeyboard, stateKeyDown, code, 0, 0)
            applyHookOutput(for: code, caps: 0, to: &rendered)
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

    private func literalOutput(for keyCode: UInt16, caps: UInt8) -> String {
        switch keyCode {
        case KEY_A: return caps != 0 ? "A" : "a"
        case KEY_B: return caps != 0 ? "B" : "b"
        case KEY_C: return caps != 0 ? "C" : "c"
        case KEY_D: return caps != 0 ? "D" : "d"
        case KEY_E: return caps != 0 ? "E" : "e"
        case KEY_F: return caps != 0 ? "F" : "f"
        case KEY_G: return caps != 0 ? "G" : "g"
        case KEY_H: return caps != 0 ? "H" : "h"
        case KEY_I: return caps != 0 ? "I" : "i"
        case KEY_J: return caps != 0 ? "J" : "j"
        case KEY_K: return caps != 0 ? "K" : "k"
        case KEY_L: return caps != 0 ? "L" : "l"
        case KEY_M: return caps != 0 ? "M" : "m"
        case KEY_N: return caps != 0 ? "N" : "n"
        case KEY_O: return caps != 0 ? "O" : "o"
        case KEY_P: return caps != 0 ? "P" : "p"
        case KEY_Q: return caps != 0 ? "Q" : "q"
        case KEY_R: return caps != 0 ? "R" : "r"
        case KEY_S: return caps != 0 ? "S" : "s"
        case KEY_T: return caps != 0 ? "T" : "t"
        case KEY_U: return caps != 0 ? "U" : "u"
        case KEY_V: return caps != 0 ? "V" : "v"
        case KEY_W: return caps != 0 ? "W" : "w"
        case KEY_X: return caps != 0 ? "X" : "x"
        case KEY_Y: return caps != 0 ? "Y" : "y"
        case KEY_Z: return caps != 0 ? "Z" : "z"
        case KEY_0: return "0"
        case KEY_1: return "1"
        case KEY_2: return "2"
        case KEY_3: return "3"
        case KEY_4: return "4"
        case KEY_5: return "5"
        case KEY_6: return "6"
        case KEY_7: return "7"
        case KEY_8: return "8"
        case KEY_9: return "9"
        case KEY_SPACE: return " "
        default: return ""
        }
    }

    private func applyHookOutput(for keyCode: UInt16, caps: UInt8, to rendered: inout String) {
        if engineHookCode() == HookCodeState.doNothing.rawValue {
            rendered += literalOutput(for: keyCode, caps: caps)
            return
        }
        let backspaces = Int(engineHookBackspaceCount())
        if backspaces > 0 {
            for _ in 0..<min(backspaces, rendered.count) {
                rendered.removeLast()
            }
        }
        rendered += hookOutputWord()
    }

    private func runSpaceCase(
        _ token: String,
        customEnglish: [String] = [],
        expectRestore: Bool,
        autoRestoreEnglish: Bool = true,
        restoreIfWrongSpelling: Bool = false,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        setCustomEnglishWords(customEnglish)
        let saved = PHTVEngineRuntimeFacade.autoRestoreEnglishWord()
        let savedRestoreIfWrongSpelling = PHTVEngineRuntimeFacade.restoreIfWrongSpelling()
        PHTVEngineRuntimeFacade.setAutoRestoreEnglishWord(autoRestoreEnglish ? 1 : 0)
        PHTVEngineRuntimeFacade.setRestoreIfWrongSpelling(restoreIfWrongSpelling ? 1 : 0)
        defer {
            PHTVEngineRuntimeFacade.setAutoRestoreEnglishWord(saved)
            PHTVEngineRuntimeFacade.setRestoreIfWrongSpelling(savedRestoreIfWrongSpelling)
        }
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
        restoreIfWrongSpelling: Bool = false,
        breakKey: UInt16 = KEY_DOT,
        breakCaps: UInt8 = 0,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        setCustomEnglishWords(customEnglish)
        let saved = PHTVEngineRuntimeFacade.autoRestoreEnglishWord()
        let savedRestoreIfWrongSpelling = PHTVEngineRuntimeFacade.restoreIfWrongSpelling()
        PHTVEngineRuntimeFacade.setAutoRestoreEnglishWord(autoRestoreEnglish ? 1 : 0)
        PHTVEngineRuntimeFacade.setRestoreIfWrongSpelling(restoreIfWrongSpelling ? 1 : 0)
        defer {
            PHTVEngineRuntimeFacade.setAutoRestoreEnglishWord(saved)
            PHTVEngineRuntimeFacade.setRestoreIfWrongSpelling(savedRestoreIfWrongSpelling)
        }
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

    private func runMarkAfterKCase(
        _ token: String,
        expectedOutput: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        engineInitialize()
        var rendered = ""
        feedWord(token, rendered: &rendered)
        engineHandleEvent(eventKeyboard, stateKeyDown, KEY_S, 0, 0)
        applyHookOutput(for: KEY_S, caps: 0, to: &rendered)
        XCTAssertEqual(
            rendered,
            expectedOutput,
            "MARK-after-k mismatch for token='\(token)'",
            file: file,
            line: line
        )
    }

    // MARK: - Built-in dictionary regressions (Issue #135)

    func testDakLakBuiltInTelexFormsPersistAfterDictionaryClear() {
        phtvCustomDictionaryClear()
        for token in ["lawsk", "lawks", "ddawsk", "ddawks"] {
            XCTAssertTrue(
                customDictionaryContainsVietnameseWord(token),
                "Built-in Vietnamese form should persist after clear: \(token)"
            )
        }
    }

    func testDakLakBuiltInTelexFormsPersistAfterCustomDictionaryLoad() {
        setCustomEnglishWords(["terminal"])
        for token in ["lawsk", "lawks", "ddawsk", "ddawks"] {
            XCTAssertTrue(
                customDictionaryContainsVietnameseWord(token),
                "Built-in Vietnamese form should persist after custom load: \(token)"
            )
        }
    }

    func testLakAcceptsKsOrderingForMark() {
        runMarkAfterKCase("lawk", expectedOutput: "lắk")
    }

    func testDakAcceptsKsOrderingForMark() {
        runMarkAfterKCase("ddawk", expectedOutput: "đắk")
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
        runSpaceCase("user", expectRestore: true, autoRestoreEnglish: false, restoreIfWrongSpelling: true)
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
        runWordBreakCase("user", expectRestore: true, autoRestoreEnglish: false, restoreIfWrongSpelling: true)
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
        runWordBreakCase("user", expectRestore: true, autoRestoreEnglish: false, restoreIfWrongSpelling: true,
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
}
