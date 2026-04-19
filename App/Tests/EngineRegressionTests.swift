// EngineRegressionTests.swift
// PHEngineTests
//
// Engine regression coverage using XCTest
// Created by Phạm Hùng Tiến on 2026.
// Copyright © 2026 Phạm Hùng Tiến. All rights reserved.

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
        ensureBuiltInDictionariesLoaded()
        // Reset runtime to known defaults for each test.
        PHTVEngineRuntimeFacade.setCurrentLanguage(1)           // Vietnamese
        PHTVEngineRuntimeFacade.setCurrentInputType(0)          // Telex
        PHTVEngineRuntimeFacade.setAutoRestoreEnglishWord(1)
        PHTVEngineRuntimeFacade.setAutoRestoreEnglishWordMode(Int32(AutoRestoreEnglishMode.englishOnly.rawValue))
        PHTVEngineRuntimeFacade.setRestoreIfWrongSpelling(0)
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

    private func ensureBuiltInDictionariesLoaded(file: StaticString = #filePath, line: UInt = #line) {
        if phtvDictionaryIsEnglishInitialized() == 0 {
            guard let enPath = Bundle.main.path(forResource: "en_dict", ofType: "bin") else {
                XCTFail("Missing en_dict.bin in app bundle", file: file, line: line)
                return
            }
            XCTAssertTrue(
                PHTVEngineDataBridge.initializeEnglishDictionary(atPath: enPath),
                "Failed to initialize built-in English dictionary",
                file: file,
                line: line
            )
        }

        if phtvDictionaryVietnameseWordCount() == 0 {
            guard let viPath = Bundle.main.path(forResource: "vi_dict", ofType: "bin") else {
                XCTFail("Missing vi_dict.bin in app bundle", file: file, line: line)
                return
            }
            XCTAssertTrue(
                PHTVEngineDataBridge.initializeVietnameseDictionary(atPath: viPath),
                "Failed to initialize built-in Vietnamese dictionary",
                file: file,
                line: line
            )
        }
    }

    // MARK: - Helpers

    private func setCustomWords(english: [String] = [], vietnamese: [String] = []) {
        phtvCustomDictionaryClear()
        guard !english.isEmpty || !vietnamese.isEmpty else { return }
        var json = "["
        var entryIndex = 0
        for w in english {
            if entryIndex > 0 { json += "," }
            json += "{\"word\":\"\(w)\",\"type\":\"en\"}"
            entryIndex += 1
        }
        for w in vietnamese {
            if entryIndex > 0 { json += "," }
            json += "{\"word\":\"\(w)\",\"type\":\"vi\"}"
            entryIndex += 1
        }
        json += "]"
        phtvCustomDictionaryLoadJSON(json, Int32(json.utf8.count))
    }

    private func setCustomEnglishWords(_ words: [String]) {
        setCustomWords(english: words)
    }

    private func setCustomVietnameseWords(_ words: [String]) {
        setCustomWords(vietnamese: words)
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

    private func detectorKeyStates(for token: String) -> [UInt32] {
        token.map { UInt32(keyCode(for: $0)) }
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

    private func runtimeEmittedWord(for keycode: UInt16) -> String {
        let codeTable = PHTVEngineRuntimeFacade.currentCodeTable()
        let count = Int(engineHookNewCharCount())
        var scalars: [UnicodeScalar] = []
        scalars.reserveCapacity(count + 1)

        if count > 0 {
            for i in stride(from: count - 1, through: 0, by: -1) {
                let codePoint = decodeOutputCharacter(engineHookCharAt(Int32(i)), codeTable: codeTable)
                guard codePoint != 0, let scalar = UnicodeScalar(Int(codePoint)) else { continue }
                scalars.append(scalar)
            }
        }

        if isRestore(engineHookCode()) {
            let codePoint = EngineMacroKeyMap.character(for: UInt32(keycode))
            if codePoint != 0, let scalar = UnicodeScalar(Int(codePoint)) {
                scalars.append(scalar)
            }
        }

        return String(String.UnicodeScalarView(scalars))
    }

    private func runtimeRenderedToken(_ token: String) -> String {
        engineInitialize()
        var output = ""

        for ch in token {
            let code = keyCode(for: ch)
            engineHandleEvent(eventKeyboard, stateKeyDown, code, 0, 0)

            let backspaceCount = min(Int(engineHookBackspaceCount()), output.count)
            if backspaceCount > 0 {
                output.removeLast(backspaceCount)
            }

            if engineHookCode() == HookCodeState.doNothing.rawValue {
                if let scalar = UnicodeScalar(Int(EngineMacroKeyMap.character(for: UInt32(code)))) {
                    output.unicodeScalars.append(scalar)
                }
                continue
            }

            output += runtimeEmittedWord(for: code)
        }

        return output
    }

    private func runSpaceCase(
        _ token: String,
        customEnglish: [String] = [],
        expectRestore: Bool,
        autoRestoreEnglish: Bool = true,
        autoRestoreMode: AutoRestoreEnglishMode = .englishOnly,
        allowConsonantZFWJ: Bool? = nil,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        setCustomEnglishWords(customEnglish)
        let saved = PHTVEngineRuntimeFacade.autoRestoreEnglishWord()
        let savedMode = PHTVEngineRuntimeFacade.autoRestoreEnglishWordMode()
        let savedWrongSpelling = PHTVEngineRuntimeFacade.restoreIfWrongSpelling()
        let savedAllowConsonantZFWJ = PHTVEngineRuntimeFacade.allowConsonantZFWJ()
        PHTVEngineRuntimeFacade.setAutoRestoreEnglishWord(autoRestoreEnglish ? 1 : 0)
        PHTVEngineRuntimeFacade.setAutoRestoreEnglishWordMode(Int32(autoRestoreMode.rawValue))
        if let allowConsonantZFWJ {
            PHTVEngineRuntimeFacade.setAllowConsonantZFWJ(allowConsonantZFWJ ? 1 : 0)
        }
        let wrongSpellingFallback: Int32 = autoRestoreEnglish && autoRestoreMode.enablesWrongSpellingFallback ? 1 : 0
        PHTVEngineRuntimeFacade.setRestoreIfWrongSpelling(wrongSpellingFallback)
        defer {
            PHTVEngineRuntimeFacade.setAutoRestoreEnglishWord(saved)
            PHTVEngineRuntimeFacade.setAutoRestoreEnglishWordMode(savedMode)
            PHTVEngineRuntimeFacade.setRestoreIfWrongSpelling(savedWrongSpelling)
            PHTVEngineRuntimeFacade.setAllowConsonantZFWJ(savedAllowConsonantZFWJ)
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
        autoRestoreMode: AutoRestoreEnglishMode = .englishOnly,
        allowConsonantZFWJ: Bool? = nil,
        breakKey: UInt16 = KEY_DOT,
        breakCaps: UInt8 = 0,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        setCustomEnglishWords(customEnglish)
        let saved = PHTVEngineRuntimeFacade.autoRestoreEnglishWord()
        let savedMode = PHTVEngineRuntimeFacade.autoRestoreEnglishWordMode()
        let savedWrongSpelling = PHTVEngineRuntimeFacade.restoreIfWrongSpelling()
        let savedAllowConsonantZFWJ = PHTVEngineRuntimeFacade.allowConsonantZFWJ()
        PHTVEngineRuntimeFacade.setAutoRestoreEnglishWord(autoRestoreEnglish ? 1 : 0)
        PHTVEngineRuntimeFacade.setAutoRestoreEnglishWordMode(Int32(autoRestoreMode.rawValue))
        if let allowConsonantZFWJ {
            PHTVEngineRuntimeFacade.setAllowConsonantZFWJ(allowConsonantZFWJ ? 1 : 0)
        }
        let wrongSpellingFallback: Int32 = autoRestoreEnglish && autoRestoreMode.enablesWrongSpellingFallback ? 1 : 0
        PHTVEngineRuntimeFacade.setRestoreIfWrongSpelling(wrongSpellingFallback)
        defer {
            PHTVEngineRuntimeFacade.setAutoRestoreEnglishWord(saved)
            PHTVEngineRuntimeFacade.setAutoRestoreEnglishWordMode(savedMode)
            PHTVEngineRuntimeFacade.setRestoreIfWrongSpelling(savedWrongSpelling)
            PHTVEngineRuntimeFacade.setAllowConsonantZFWJ(savedAllowConsonantZFWJ)
        }
        engineInitialize()
        feedWord(token)
        engineHandleEvent(eventKeyboard, stateKeyDown, breakKey, breakCaps, 0)
        let restored = isRestore(engineHookCode())
        XCTAssertEqual(restored, expectRestore,
            "BREAK(key=\(breakKey),caps=\(breakCaps)): token='\(token)' expectRestore=\(expectRestore) got code=\(engineHookCode())",
            file: file, line: line)
    }

    private func withInputType<T>(_ inputType: Int32, perform body: () throws -> T) rethrows -> T {
        let savedInputType = PHTVEngineRuntimeFacade.currentInputType()
        PHTVEngineRuntimeFacade.setCurrentInputType(inputType)
        defer { PHTVEngineRuntimeFacade.setCurrentInputType(savedInputType) }
        return try body()
    }

    private func runQuickConsonantSpaceCase(
        _ token: String,
        customEnglish: [String] = [],
        quickStart: Bool,
        quickEnd: Bool,
        autoRestoreMode: AutoRestoreEnglishMode = .englishOnly,
        allowConsonantZFWJ: Bool? = nil,
        expectedOutput: String,
        expectedBackspaceCount: Int,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        setCustomEnglishWords(customEnglish)
        let savedQuickStart = PHTVEngineRuntimeFacade.quickStartConsonant()
        let savedQuickEnd = PHTVEngineRuntimeFacade.quickEndConsonant()
        let savedAutoRestoreMode = PHTVEngineRuntimeFacade.autoRestoreEnglishWordMode()
        let savedWrongSpelling = PHTVEngineRuntimeFacade.restoreIfWrongSpelling()
        let savedAllowConsonantZFWJ = PHTVEngineRuntimeFacade.allowConsonantZFWJ()
        defer {
            PHTVEngineRuntimeFacade.setQuickStartConsonant(savedQuickStart)
            PHTVEngineRuntimeFacade.setQuickEndConsonant(savedQuickEnd)
            PHTVEngineRuntimeFacade.setAutoRestoreEnglishWordMode(savedAutoRestoreMode)
            PHTVEngineRuntimeFacade.setRestoreIfWrongSpelling(savedWrongSpelling)
            PHTVEngineRuntimeFacade.setAllowConsonantZFWJ(savedAllowConsonantZFWJ)
        }

        PHTVEngineRuntimeFacade.setQuickStartConsonant(quickStart ? 1 : 0)
        PHTVEngineRuntimeFacade.setQuickEndConsonant(quickEnd ? 1 : 0)
        PHTVEngineRuntimeFacade.setAutoRestoreEnglishWordMode(Int32(autoRestoreMode.rawValue))
        let wrongSpellingFallback: Int32 = autoRestoreMode.enablesWrongSpellingFallback ? 1 : 0
        PHTVEngineRuntimeFacade.setRestoreIfWrongSpelling(wrongSpellingFallback)
        if let allowConsonantZFWJ {
            PHTVEngineRuntimeFacade.setAllowConsonantZFWJ(allowConsonantZFWJ ? 1 : 0)
        }

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

    private func runQuickConsonantWordBreakCase(
        _ token: String,
        customEnglish: [String] = [],
        quickStart: Bool,
        quickEnd: Bool,
        autoRestoreMode: AutoRestoreEnglishMode = .englishOnly,
        allowConsonantZFWJ: Bool? = nil,
        breakKey: UInt16 = KEY_COMMA,
        breakCaps: UInt8 = 0,
        expectedOutput: String,
        expectedBackspaceCount: Int,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        setCustomEnglishWords(customEnglish)
        let savedQuickStart = PHTVEngineRuntimeFacade.quickStartConsonant()
        let savedQuickEnd = PHTVEngineRuntimeFacade.quickEndConsonant()
        let savedAutoRestoreMode = PHTVEngineRuntimeFacade.autoRestoreEnglishWordMode()
        let savedWrongSpelling = PHTVEngineRuntimeFacade.restoreIfWrongSpelling()
        let savedAllowConsonantZFWJ = PHTVEngineRuntimeFacade.allowConsonantZFWJ()
        defer {
            PHTVEngineRuntimeFacade.setQuickStartConsonant(savedQuickStart)
            PHTVEngineRuntimeFacade.setQuickEndConsonant(savedQuickEnd)
            PHTVEngineRuntimeFacade.setAutoRestoreEnglishWordMode(savedAutoRestoreMode)
            PHTVEngineRuntimeFacade.setRestoreIfWrongSpelling(savedWrongSpelling)
            PHTVEngineRuntimeFacade.setAllowConsonantZFWJ(savedAllowConsonantZFWJ)
        }

        PHTVEngineRuntimeFacade.setQuickStartConsonant(quickStart ? 1 : 0)
        PHTVEngineRuntimeFacade.setQuickEndConsonant(quickEnd ? 1 : 0)
        PHTVEngineRuntimeFacade.setAutoRestoreEnglishWordMode(Int32(autoRestoreMode.rawValue))
        let wrongSpellingFallback: Int32 = autoRestoreMode.enablesWrongSpellingFallback ? 1 : 0
        PHTVEngineRuntimeFacade.setRestoreIfWrongSpelling(wrongSpellingFallback)
        if let allowConsonantZFWJ {
            PHTVEngineRuntimeFacade.setAllowConsonantZFWJ(allowConsonantZFWJ ? 1 : 0)
        }

        engineInitialize()
        feedWord(token)
        engineHandleEvent(eventKeyboard, stateKeyDown, breakKey, breakCaps, 0)

        XCTAssertTrue(
            isRestore(engineHookCode()),
            "Quick consonant should trigger restore flow, got code=\(engineHookCode())",
            file: file, line: line
        )
        XCTAssertEqual(
            Int(engineHookBackspaceCount()),
            expectedBackspaceCount,
            "Unexpected backspace count for token='\(token)' on break key=\(breakKey)",
            file: file, line: line
        )
        XCTAssertEqual(
            hookOutputWord(),
            expectedOutput,
            "BREAK(key=\(breakKey),caps=\(breakCaps)) quick-consonant mismatch for token='\(token)'",
            file: file, line: line
        )
    }

    // MARK: - Space tests

    func testCustomEnglishTerminalRestoresOnSpace() {
        runSpaceCase("terminal", customEnglish: ["terminal"], expectRestore: true)
    }

    func testCustomEnglishQesDoesNotRestoreOnSpaceWhenTypingStaysEnglish() {
        runSpaceCase("qes", customEnglish: ["qes"], expectRestore: false)
    }

    func testAlnumInt1234NoRestoreOnSpace() {
        runSpaceCase("int1234", customEnglish: ["int"], expectRestore: false)
    }

    func testTelexConflictTerminal1234RestoresOnSpace() {
        runSpaceCase("terminal1234", customEnglish: ["terminal"], expectRestore: true)
    }

    func testWrongSpellingUserDoesNotRestoreOnSpace() {
        runSpaceCase("user", expectRestore: false, autoRestoreEnglish: false)
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

    func testWrongSpellingUserDoesNotRestoreOnDot() {
        runWordBreakCase("user", expectRestore: false, autoRestoreEnglish: false)
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

    func testWrongSpellingDoesNotRestoreOnExclamationMark() {
        runWordBreakCase("user", expectRestore: false, autoRestoreEnglish: false,
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

    func testQuickStartConsonantWorksInNonVietnameseAutoRestoreMode() {
        runQuickConsonantSpaceCase(
            "fan",
            customEnglish: ["fan"],
            quickStart: true,
            quickEnd: false,
            autoRestoreMode: .nonVietnamese,
            expectedOutput: "phan",
            expectedBackspaceCount: 3
        )
    }

    func testQuickStartConsonantWorksOnCommaWhenAllowConsonantZFWJIsEnabled() {
        runQuickConsonantWordBreakCase(
            "fan",
            customEnglish: ["fan"],
            quickStart: true,
            quickEnd: false,
            autoRestoreMode: .nonVietnamese,
            allowConsonantZFWJ: true,
            expectedOutput: "phan",
            expectedBackspaceCount: 3
        )
    }

    func testQuickEndConsonantWorksOnCommaInNonVietnameseAutoRestoreMode() {
        runQuickConsonantWordBreakCase(
            "nah",
            customEnglish: ["nah"],
            quickStart: false,
            quickEnd: true,
            autoRestoreMode: .nonVietnamese,
            expectedOutput: "nh",
            expectedBackspaceCount: 1
        )
    }

    // MARK: - Wrong-spelling fallback removed

    func testKosovoDoesNotRestoreOnComma() {
        runWordBreakCase("koosvo", expectRestore: false, breakKey: KEY_COMMA)
    }

    func testKosovoDoesNotRestoreOnDot() {
        runWordBreakCase("koosvo", expectRestore: false)
    }

    func testRoothideDoesNotRestoreOnComma() {
        runWordBreakCase("roothide", expectRestore: false, breakKey: KEY_COMMA)
    }

    func testKosovoRestoresOnCommaInNonVietnameseMode() {
        runWordBreakCase("koosvo", expectRestore: true, autoRestoreMode: .nonVietnamese, breakKey: KEY_COMMA)
    }

    func testRoothideRestoresOnCommaInNonVietnameseMode() {
        runWordBreakCase("roothide", expectRestore: true, autoRestoreMode: .nonVietnamese, breakKey: KEY_COMMA)
    }

    func testNoobRestoresOnSpace() {
        // "noob" in Telex produces "nôb" (oo→ô). "noob" is in the English dictionary.
        runSpaceCase("noob", customEnglish: ["noob"], expectRestore: true)
    }

    func testBootDoesNotRestoreOnSpace() {
        runSpaceCase("boot", expectRestore: false)
    }

    func testDataDoesNotRestoreOnSpace() {
        runSpaceCase("data", expectRestore: false)
    }

    func testDataDoesNotRestoreOnComma() {
        runWordBreakCase("data", expectRestore: false, breakKey: KEY_COMMA)
    }

    func testNoobRestoresOnComma() {
        // "noob" is in the English dictionary; must restore on comma via main detection path.
        runWordBreakCase("noob", customEnglish: ["noob"], expectRestore: true, breakKey: KEY_COMMA)
    }

    func testGoodnotesRestoresOnSpace() {
        // "goodnotes" comes from the categorized modern tech source file and must remain restorable.
        runSpaceCase("goodnotes", customEnglish: ["goodnotes"], expectRestore: true)
    }

    func testGoodnotesRestoresOnComma() {
        // The same curated source should continue to work across word-break paths.
        runWordBreakCase("goodnotes", customEnglish: ["goodnotes"], expectRestore: true, breakKey: KEY_COMMA)
    }

    func testAlnumInt1234RestoresOnSpaceInNonVietnameseMode() {
        runSpaceCase("int1234", customEnglish: ["int"], expectRestore: true, autoRestoreMode: .nonVietnamese)
    }

    func testAlnumInt1234RestoresOnDotInNonVietnameseMode() {
        runWordBreakCase("int1234", customEnglish: ["int"], expectRestore: true, autoRestoreMode: .nonVietnamese)
    }

    func testUnknownNonEnglishWordRestoresOnlyInNonVietnameseMode() {
        runSpaceCase("qwrty", expectRestore: true, autoRestoreMode: .nonVietnamese)
        runSpaceCase("qwrty", expectRestore: false, autoRestoreMode: .englishOnly)
    }

    func testNonVietnameseModeDoesNotRestoreWhenTypingWordAlreadyBecomesEnglishOnSpace() {
        runSpaceCase("offfice", customEnglish: ["offfice"], expectRestore: false, autoRestoreMode: .nonVietnamese)
    }

    func testNonVietnameseModeDoesNotRestoreWhenTypingWordAlreadyBecomesEnglishOnComma() {
        runWordBreakCase("offfice", customEnglish: ["offfice"], expectRestore: false, autoRestoreMode: .nonVietnamese, breakKey: KEY_COMMA)
    }

    func testAllowConsonantDoesNotBlockEnglishRestoreForExtendedInitialOnSpace() {
        runSpaceCase("zoom", customEnglish: ["zoom"], expectRestore: true, allowConsonantZFWJ: true)
        runSpaceCase("zoom", customEnglish: ["zoom"], expectRestore: true, allowConsonantZFWJ: false)
    }

    func testAllowConsonantDoesNotBlockEnglishRestoreForExtendedInitialOnComma() {
        runWordBreakCase("zoom", customEnglish: ["zoom"], expectRestore: true,
                         allowConsonantZFWJ: true, breakKey: KEY_COMMA)
        runWordBreakCase("zoom", customEnglish: ["zoom"], expectRestore: true,
                         allowConsonantZFWJ: false, breakKey: KEY_COMMA)
    }

    func testNonVietnameseModeRespectsAllowedExtendedInitialOnSpace() {
        runSpaceCase("zoom", customEnglish: ["zoom"], expectRestore: false, autoRestoreMode: .nonVietnamese, allowConsonantZFWJ: true)
        runSpaceCase("zoom", customEnglish: ["zoom"], expectRestore: true, autoRestoreMode: .nonVietnamese, allowConsonantZFWJ: false)
    }

    func testNonVietnameseModeRespectsAllowedExtendedInitialOnComma() {
        runWordBreakCase("zoom", customEnglish: ["zoom"], expectRestore: false, autoRestoreMode: .nonVietnamese,
                         allowConsonantZFWJ: true, breakKey: KEY_COMMA)
        runWordBreakCase("zoom", customEnglish: ["zoom"], expectRestore: true, autoRestoreMode: .nonVietnamese,
                         allowConsonantZFWJ: false, breakKey: KEY_COMMA)
    }

    func testIssue160ForDoesNotRestoreOnSpaceWhenAllowConsonantIsDisabledInEnglishMode() {
        runSpaceCase("for", customEnglish: ["for"], expectRestore: false, allowConsonantZFWJ: false)
    }

    func testIssue160ForRestoresOnSpaceWhenAllowConsonantIsDisabledInNonVietnameseMode() {
        runSpaceCase("for", customEnglish: ["for"], expectRestore: true, autoRestoreMode: .nonVietnamese, allowConsonantZFWJ: false)
    }

    func testIssue160ForDoesNotRestoreOnCommaWhenAllowConsonantIsDisabledInEnglishMode() {
        runWordBreakCase("for", customEnglish: ["for"], expectRestore: false, allowConsonantZFWJ: false, breakKey: KEY_COMMA)
    }

    func testIssue160ForRestoresOnCommaWhenAllowConsonantIsDisabledInNonVietnameseMode() {
        runWordBreakCase("for", customEnglish: ["for"], expectRestore: true, autoRestoreMode: .nonVietnamese, allowConsonantZFWJ: false, breakKey: KEY_COMMA)
    }

    func testNonVietnameseModeKeepsAllowedFInitialOnSpace() {
        runSpaceCase("for", customEnglish: ["for"], expectRestore: false, autoRestoreMode: .nonVietnamese, allowConsonantZFWJ: true)
    }

    func testNonVietnameseModeKeepsAllowedFInitialOnComma() {
        runWordBreakCase("for", customEnglish: ["for"], expectRestore: false, autoRestoreMode: .nonVietnamese, allowConsonantZFWJ: true, breakKey: KEY_COMMA)
    }

    func testIssue160DetectorRecognizesForAsEnglishWord() {
        setCustomEnglishWords(["for"])
        defer { setCustomEnglishWords([]) }
        let keyStates = detectorKeyStates(for: "for")
        let isEnglish = keyStates.withUnsafeBufferPointer {
            phtvDetectorIsEnglishWordFromKeyStates($0.baseAddress, Int32($0.count))
        }
        XCTAssertEqual(isEnglish, 1)
    }

    func testDetectorRecognizesConfiguredAcronymsAndModelNamesAsEnglishWords() {
        let curated = ["hcmus", "huflit", "qwen", "ueh", "rmit"]
        setCustomEnglishWords(curated)
        defer { setCustomEnglishWords([]) }
        for token in curated {
            let keyStates = detectorKeyStates(for: token)
            let isEnglish = keyStates.withUnsafeBufferPointer {
                phtvDetectorIsEnglishWordFromKeyStates($0.baseAddress, Int32($0.count))
            }
            XCTAssertEqual(isEnglish, 1, "Expected detector to include \(token)")
        }
    }

    func testCuratedAcronymsAndModelNamesHaveExpectedWordBreakBehavior() {
        let curated = ["hcmus", "huflit", "qwen", "ueh", "rmit"]
        runSpaceCase("qwen", customEnglish: curated, expectRestore: true)
        runWordBreakCase("qwen", customEnglish: curated, expectRestore: true, breakKey: KEY_COMMA)
        runWordBreakCase("hcmus", customEnglish: curated, expectRestore: false, breakKey: KEY_COMMA)
        runWordBreakCase("huflit", customEnglish: curated, expectRestore: true, breakKey: KEY_DOT)
    }

    func testIssue160DetectorShouldRestoreForWhenAllowConsonantIsDisabled() {
        setCustomEnglishWords(["for"])
        defer { setCustomEnglishWords([]) }
        let savedAllowConsonantZFWJ = PHTVEngineRuntimeFacade.allowConsonantZFWJ()
        let savedQuickStart = PHTVEngineRuntimeFacade.quickStartConsonant()
        defer {
            PHTVEngineRuntimeFacade.setAllowConsonantZFWJ(savedAllowConsonantZFWJ)
            PHTVEngineRuntimeFacade.setQuickStartConsonant(savedQuickStart)
        }

        PHTVEngineRuntimeFacade.setAllowConsonantZFWJ(0)
        PHTVEngineRuntimeFacade.setQuickStartConsonant(0)

        let keyStates = detectorKeyStates(for: "for")
        let shouldRestore = keyStates.withUnsafeBufferPointer {
            phtvDetectorShouldRestoreEnglishWord($0.baseAddress, Int32($0.count))
        }
        XCTAssertEqual(shouldRestore, 1)
    }

    func testIssue160FastRestoresOnSpaceWhenAllowConsonantIsEnabled() {
        runSpaceCase("fast", customEnglish: ["fast"], expectRestore: true, allowConsonantZFWJ: true)
    }

    func testIssue160FixDoesNotRestoreOnCommaWhenAllowConsonantIsDisabled() {
        runWordBreakCase("fix", customEnglish: ["fix"], expectRestore: false, allowConsonantZFWJ: false, breakKey: KEY_COMMA)
    }

    func testNonVietnameseModeKeepsVietnameseDictionaryWord() {
        setCustomVietnameseWords(["xin"])
        defer { setCustomEnglishWords([]) }
        runSpaceCase("xin", expectRestore: false, autoRestoreMode: .nonVietnamese)
    }

    func testHoomDoesNotRestoreOnSpace() {
        runSpaceCase("hoom", expectRestore: false)
    }

    func testHoomDoesNotRestoreOnComma() {
        runWordBreakCase("hoom", expectRestore: false, breakKey: KEY_COMMA)
    }

    func testHoomProducesHom() {
        XCTAssertEqual(renderedToken("hoom"), "hôm")
    }

    func testHomoDoesNotRestoreOnSpace() {
        runSpaceCase("homo", expectRestore: false)
    }

    func testHomoDoesNotRestoreOnComma() {
        runWordBreakCase("homo", expectRestore: false, breakKey: KEY_COMMA)
    }

    func testHomoProducesHom() {
        XCTAssertEqual(renderedToken("homo"), "hôm")
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

    func testWafDoesNotRestoreOnSpace() {
        runSpaceCase("waf", expectRestore: false)
    }

    func testWafDoesNotRestoreOnComma() {
        runWordBreakCase("waf", expectRestore: false, breakKey: KEY_COMMA)
    }

    func testTreenDoesNotRestoreOnSpace() {
        runSpaceCase("treen", expectRestore: false)
    }

    func testTreenProducesTrenWithCircumflex() {
        XCTAssertEqual(renderedToken("treen"), "trên")
    }

    func testTheemProducesThemWithCircumflex() {
        XCTAssertEqual(renderedToken("theem"), "thêm")
    }

    func testTheseUsesStandardTelexToneBeforeShapeOrdering() {
        XCTAssertEqual(renderedToken("these"), "thế")
    }

    func testEFamilyToneBeforeShapeMatchesStandardTelexAcrossToneKeys() {
        XCTAssertEqual(renderedToken("these"), renderedToken("thees"))
        XCTAssertEqual(renderedToken("thefe"), renderedToken("theef"))
        XCTAssertEqual(renderedToken("there"), renderedToken("theer"))
        XCTAssertEqual(renderedToken("thexe"), renderedToken("theex"))
        XCTAssertEqual(renderedToken("theje"), renderedToken("theej"))
    }

    func testAFamilyToneBeforeShapeMatchesStandardTelexAcrossToneKeys() {
        XCTAssertEqual(renderedToken("casa"), renderedToken("caas"))
        XCTAssertEqual(renderedToken("cafa"), renderedToken("caaf"))
        XCTAssertEqual(renderedToken("cara"), renderedToken("caar"))
        XCTAssertEqual(renderedToken("caxa"), renderedToken("caax"))
        XCTAssertEqual(renderedToken("caja"), renderedToken("caaj"))
    }

    func testOFamilyToneBeforeShapeMatchesStandardTelexAcrossToneKeys() {
        XCTAssertEqual(renderedToken("oso"), renderedToken("oos"))
        XCTAssertEqual(renderedToken("ofo"), renderedToken("oof"))
        XCTAssertEqual(renderedToken("oro"), renderedToken("oor"))
        XCTAssertEqual(renderedToken("oxo"), renderedToken("oox"))
        XCTAssertEqual(renderedToken("ojo"), renderedToken("ooj"))
    }

    func testAWFamilyToneBeforeShapeMatchesStandardTelexAcrossToneKeys() {
        XCTAssertEqual(renderedToken("asw"), renderedToken("aws"))
        XCTAssertEqual(renderedToken("afw"), renderedToken("awf"))
        XCTAssertEqual(renderedToken("arw"), renderedToken("awr"))
        XCTAssertEqual(renderedToken("axw"), renderedToken("awx"))
        XCTAssertEqual(renderedToken("ajw"), renderedToken("awj"))
    }

    func testOWFamilyToneBeforeShapeMatchesStandardTelexAcrossToneKeys() {
        XCTAssertEqual(renderedToken("osw"), renderedToken("ows"))
        XCTAssertEqual(renderedToken("ofw"), renderedToken("owf"))
        XCTAssertEqual(renderedToken("orw"), renderedToken("owr"))
        XCTAssertEqual(renderedToken("oxw"), renderedToken("owx"))
        XCTAssertEqual(renderedToken("ojw"), renderedToken("owj"))
    }

    func testUWFamilyToneBeforeShapeMatchesStandardTelexAcrossToneKeys() {
        XCTAssertEqual(renderedToken("usw"), renderedToken("uws"))
        XCTAssertEqual(renderedToken("ufw"), renderedToken("uwf"))
        XCTAssertEqual(renderedToken("urw"), renderedToken("uwr"))
        XCTAssertEqual(renderedToken("uxw"), renderedToken("uwx"))
        XCTAssertEqual(renderedToken("ujw"), renderedToken("uwj"))
    }

    func testUOWFamilyToneBeforeShapeMatchesStandardTelexAcrossToneKeys() {
        XCTAssertEqual(renderedToken("uosw"), renderedToken("uows"))
        XCTAssertEqual(renderedToken("uofw"), renderedToken("uowf"))
        XCTAssertEqual(renderedToken("uorw"), renderedToken("uowr"))
        XCTAssertEqual(renderedToken("uoxw"), renderedToken("uowx"))
        XCTAssertEqual(renderedToken("uojw"), renderedToken("uowj"))
    }

    func testUYEEFamilyToneBeforeShapeMatchesStandardTelexAcrossToneKeys() {
        XCTAssertEqual(renderedToken("uyese"), renderedToken("uyees"))
        XCTAssertEqual(renderedToken("uyefe"), renderedToken("uyeef"))
        XCTAssertEqual(renderedToken("uyere"), renderedToken("uyeer"))
        XCTAssertEqual(renderedToken("uyexe"), renderedToken("uyeex"))
        XCTAssertEqual(renderedToken("uyeje"), renderedToken("uyeej"))
    }

    func testRepeatedToneKeyOnInvalidMarkedWordCancelsToneInsteadOfAppendingRawKey() {
        XCTAssertEqual(renderedToken("porr"), "por")
    }

    func testRuntimeRepeatedToneKeyOnInvalidMarkedWordCancelsToneInsteadOfAppendingRawKey() {
        XCTAssertEqual(runtimeRenderedToken("porr"), "por")
    }

    func testTheemDoesNotRestoreOnSpace() {
        runSpaceCase("theem", expectRestore: false)
    }

    func testSispDoesNotRestoreOnSpace() {
        runSpaceCase("sisp", expectRestore: false)
    }

    func testSipsProducesMarkedSyllable() {
        XCTAssertEqual(renderedToken("sips"), "síp")
    }

    func testWafProducesMarkedUa() {
        XCTAssertEqual(renderedToken("waf"), "ừa")
    }

    func testQwenProducesTelexTransformedTypingBeforeRestore() {
        XCTAssertEqual(renderedToken("qwen"), "qưen")
    }

    func testWuProducesUu() {
        XCTAssertEqual(renderedToken("wu"), "ưu")
    }

    func testWuDoesNotRestoreOnSpace() {
        runSpaceCase("wu", expectRestore: false)
    }

    func testWuDoesNotRestoreOnComma() {
        runWordBreakCase("wu", expectRestore: false, breakKey: KEY_COMMA)
    }

    func testIssue165EngineerStaysEnglishWhileTypingInSimpleTelex1() {
        setCustomEnglishWords(["engineer"])
        defer { setCustomEnglishWords([]) }
        withInputType(2) {
            XCTAssertEqual(renderedToken("engineer"), "engineer")
        }
    }

    func testIssue165EngineerDoesNotRestoreOnSpaceInSimpleTelex1() {
        withInputType(2) {
            runSpaceCase("engineer", customEnglish: ["engineer"], expectRestore: false)
        }
    }

    func testIssue165EngineerDoesNotRestoreOnCommaInSimpleTelex1() {
        withInputType(2) {
            runWordBreakCase("engineer", customEnglish: ["engineer"], expectRestore: false, breakKey: KEY_COMMA)
        }
    }

    func testSispProducesMarkedSyllable() {
        XCTAssertEqual(renderedToken("sisp"), "síp")
    }

    // MARK: - Issue #98: elongated vowels must preserve existing Vietnamese marks

    func testElongatedAcuteAAppendsRawVowels() {
        XCTAssertEqual(renderedToken("asaa"), "áaa")
    }

    func testElongatedAcuteEAfterNhePreservesMarkPlacement() {
        XCTAssertEqual(renderedToken("nhesee"), "nhéee")
    }

    func testMarkedODoubleKeyFollowsLegacyTelexCycle() {
        XCTAssertEqual(renderedToken("ojo"), "ộ")
        XCTAssertEqual(runtimeRenderedToken("ojo"), "ộ")
    }

    func testMarkedODoubleKeyThenReleaseHatAddsRawTail() {
        XCTAssertEqual(renderedToken("ojoo"), "ọo")
        XCTAssertEqual(runtimeRenderedToken("ojoo"), "ọo")
    }

    func testMarkedODoubleKeyCanStillStretchAfterLegacyCycle() {
        XCTAssertEqual(renderedToken("ojooo"), "ọoo")
        XCTAssertEqual(runtimeRenderedToken("ojooo"), "ọoo")
    }

    func testRuntimeElongatedAndMarkedVowelsKeepVisibleOutput() {
        XCTAssertEqual(runtimeRenderedToken("asaa"), "áaa")
        XCTAssertEqual(runtimeRenderedToken("nhesee"), "nhéee")
        XCTAssertEqual(runtimeRenderedToken("ooso"), "óo")
    }

    func testTrailingACycleAfterEarlierMarkedVowelKeepsOriginalTonePlacement() {
        XCTAssertEqual(renderedToken("curaa"), "củâ")
        XCTAssertEqual(renderedToken("curaaa"), "củaa")
    }

    func testPlainTelexEEEEKeepsLegacyRawOutput() {
        XCTAssertEqual(renderedToken("theee"), "thee")
    }

    func testPlainTelexOOOOKeepsLegacyRawOutput() {
        XCTAssertEqual(renderedToken("cooo"), "coo")
    }

    func testElongatedOiWithToneAfterStretchKeepsToneOnOriginalVowel() {
        XCTAssertEqual(renderedToken("choiiiif"), "chòiiii")
    }

    func testElongatedOiWithToneBeforeStretchKeepsToneOnOriginalVowel() {
        XCTAssertEqual(renderedToken("choifiii"), "chòiiii")
    }

}
