// PHTVEngineCore.swift
// PHTV
//
// Ported from Engine.cpp + 53 .inc files (~3900 lines C++)
// Created by Phạm Hùng Tiến on 2026.

import Foundation

// MARK: - Processing Char Table (EngineInputKeyMacros.inc)

private let processingChar: [[UInt16]] = [
    // Telex (0): s f r x j a o e w d z
    [KEY_S, KEY_F, KEY_R, KEY_X, KEY_J, KEY_A, KEY_O, KEY_E, KEY_W, KEY_D, KEY_Z],
    // VNI (1): 1 2 3 4 5 6 6 7 8 9 0
    [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0],
    // Simple Telex 1 (2)
    [KEY_S, KEY_F, KEY_R, KEY_X, KEY_J, KEY_A, KEY_O, KEY_E, KEY_W, KEY_D, KEY_Z],
    // Simple Telex 2 (3)
    [KEY_S, KEY_F, KEY_R, KEY_X, KEY_J, KEY_A, KEY_O, KEY_E, KEY_W, KEY_D, KEY_Z],
]

private let kCharKeyCode: Set<UInt16> = [
    KEY_BACKQUOTE, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9,
    KEY_0, KEY_MINUS, KEY_EQUALS, KEY_LEFT_BRACKET, KEY_RIGHT_BRACKET, KEY_BACK_SLASH,
    KEY_SEMICOLON, KEY_QUOTE, KEY_COMMA, KEY_DOT, KEY_SLASH,
]

private let kBreakCode: Set<UInt16> = [
    KEY_ESC, KEY_TAB, KEY_ENTER, KEY_RETURN, KEY_LEFT, KEY_RIGHT, KEY_DOWN, KEY_UP,
    KEY_COMMA, KEY_DOT, KEY_SLASH, KEY_SEMICOLON, KEY_QUOTE, KEY_BACK_SLASH,
    KEY_MINUS, KEY_EQUALS, KEY_BACKQUOTE,
]

private let kMacroBreakCode: Set<UInt16> = [
    KEY_RETURN, KEY_COMMA, KEY_DOT, KEY_SLASH, KEY_SEMICOLON, KEY_QUOTE,
    KEY_BACK_SLASH, KEY_MINUS, KEY_EQUALS,
]

private let kAbbreviations: Set<String> = [
    "mr", "mrs", "ms", "dr", "prof", "sr", "jr", "st",
    "vs", "etc", "eg", "ie",
    "tp", "q", "p", "ths", "ts", "gs", "pgs",
]

// MARK: - Engine State

final class PHTVVietnameseEngine {

    // MARK: HookState output (corresponds to vKeyHookState)
    var hCode: Int32 = 0
    var hExt: Int32 = 0
    var hBPC: Int = 0
    var hNCC: Int = 0
    var hData: [UInt32] = Array(repeating: 0, count: ENGINE_MAX_BUFF)
    var hMacroKey: [UInt32] = []
    var hMacroData: [UInt32] = []

    // MARK: Core buffers
    var typingWord: [UInt32] = Array(repeating: 0, count: ENGINE_MAX_BUFF)
    var idx: Int = 0            // _index
    var longWordHelper: [UInt32] = []
    var typingStates: [[UInt32]] = []
    var typingStatesData: [UInt32] = []

    var keyStates: [UInt32] = Array(repeating: 0, count: ENGINE_MAX_BUFF)
    var stateIdx: Int = 0       // _stateIndex

    var tempDisableKey: Bool = false

    // MARK: Spelling state
    var spellingOK: Bool = false
    var spellingFlag: Bool = false
    var spellingVowelOK: Bool = false
    var spellingEndIndex: Int = 0

    // MARK: Session-scoped vars
    var capsElem: Int = 0
    var markElem: Int = 0
    var keyVal: Int = 0         // "key" in C++ (avoid keyword collision)
    var isCorect: Bool = false
    var isChanged: Bool = false
    var vowelCount: Int = 0
    var VSI: Int = 0            // vowelStartIndex
    var VEI: Int = 0            // vowelEndIndex
    var VWSM: Int = 0           // vowelWillSetMark
    var isRestoredW: Bool = false
    var keyForAEO: UInt16 = 0
    var isCheckedGrammar: Bool = false
    var isCaps: Bool = false

    var spaceCount: Int = 0
    var hasHandledMacro: Bool = false
    var hasHandleQuickConsonant: Bool = false
    var willTempOffEngine: Bool = false
    var useSpellCheckingBefore: Bool = false
    var shouldUpperCaseEnglishRestore: Bool = false
    var upperCaseStatus: UInt8 = 0
    var upperCaseNeedsSpaceConfirm: Bool = false
    var snapshotUpperCaseFirstChar: UInt8 = 0

    var isCharKeyCode: Bool = false
    var specialChar: [UInt32] = []

    // MARK: Runtime snapshots
    var runtimeInputTypeSnapshot: Int32 = 0
    var runtimeCodeTableSnapshot: Int32 = 0

    // MARK: - Inline key helpers

    @inline(__always)
    func chr(_ i: Int) -> UInt16 { UInt16(typingWord[i] & CHAR_MASK) }

    @inline(__always)
    func get(_ data: UInt32) -> UInt32 { getCharacterCode(data) }

    @inline(__always)
    func isKeyZ(_ k: UInt16) -> Bool { processingChar[Int(runtimeInputTypeSnapshot)][10] == k }
    @inline(__always)
    func isKeyD(_ k: UInt16) -> Bool { processingChar[Int(runtimeInputTypeSnapshot)][9] == k }
    @inline(__always)
    func isKeyS(_ k: UInt16) -> Bool { processingChar[Int(runtimeInputTypeSnapshot)][0] == k }
    @inline(__always)
    func isKeyF(_ k: UInt16) -> Bool { processingChar[Int(runtimeInputTypeSnapshot)][1] == k }
    @inline(__always)
    func isKeyR(_ k: UInt16) -> Bool { processingChar[Int(runtimeInputTypeSnapshot)][2] == k }
    @inline(__always)
    func isKeyX(_ k: UInt16) -> Bool { processingChar[Int(runtimeInputTypeSnapshot)][3] == k }
    @inline(__always)
    func isKeyJ(_ k: UInt16) -> Bool { processingChar[Int(runtimeInputTypeSnapshot)][4] == k }

    @inline(__always)
    func isKeyW(_ k: UInt16) -> Bool {
        if runtimeInputTypeSnapshot != 1 {
            return processingChar[Int(runtimeInputTypeSnapshot)][8] == k
        } else {
            return processingChar[1][8] == k || processingChar[1][7] == k
        }
    }

    @inline(__always)
    func isKeyDouble(_ k: UInt16) -> Bool {
        if runtimeInputTypeSnapshot != 1 {
            let pc = processingChar[Int(runtimeInputTypeSnapshot)]
            return pc[5] == k || pc[6] == k || pc[7] == k
        } else {
            return processingChar[1][6] == k
        }
    }

    @inline(__always)
    func isMarkKey(_ k: UInt16) -> Bool {
        if runtimeInputTypeSnapshot != 1 {
            return k == KEY_S || k == KEY_F || k == KEY_R || k == KEY_J || k == KEY_X
        } else {
            return k == KEY_1 || k == KEY_2 || k == KEY_3 || k == KEY_5 || k == KEY_4
        }
    }

    @inline(__always)
    func isBracketKey(_ k: UInt16) -> Bool { k == KEY_LEFT_BRACKET || k == KEY_RIGHT_BRACKET }

    @inline(__always)
    func isSpecialKey(_ k: UInt16) -> Bool {
        switch runtimeInputTypeSnapshot {
        case 0:
            return k == KEY_W || k == KEY_E || k == KEY_R || k == KEY_O ||
                   k == KEY_LEFT_BRACKET || k == KEY_RIGHT_BRACKET || k == KEY_A ||
                   k == KEY_S || k == KEY_D || k == KEY_F || k == KEY_J ||
                   k == KEY_Z || k == KEY_X
        case 1:
            return isNumberKey(k)
        case 2, 3:
            return k == KEY_W || k == KEY_E || k == KEY_R || k == KEY_O ||
                   k == KEY_A || k == KEY_S || k == KEY_D || k == KEY_F ||
                   k == KEY_J || k == KEY_Z || k == KEY_X
        default:
            return false
        }
    }

    @inline(__always)
    func isQuickTelexKey(_ k: UInt16) -> Bool { vnQuickTelex[UInt32(k)] != nil }

    // MARK: - Runtime bridge helpers

    @inline(__always)
    func isSpellCheckingEnabled() -> Bool { phtvRuntimeCheckSpellingValue() != 0 }

    @inline(__always)
    func setSpellCheckingEnabled(_ enabled: Bool) {
        phtvRuntimeSetCheckSpellingValue(enabled ? 1 : 0)
    }

    func refreshRuntimeLayoutSnapshot() {
        runtimeInputTypeSnapshot = phtvRuntimeInputTypeValue()
        runtimeCodeTableSnapshot = phtvRuntimeCodeTableValue()
    }

    func detectorIsEnglishWord(_ keyStatesPtr: [UInt32], _ count: Int) -> Bool {
        keyStatesPtr.withUnsafeBufferPointer { ptr in
            phtvDetectorIsEnglishWordFromKeyStates(ptr.baseAddress, Int32(count)) != 0
        }
    }

    func detectorIsVietnameseWord(_ keyStatesPtr: [UInt32], _ count: Int) -> Bool {
        keyStatesPtr.withUnsafeBufferPointer { ptr in
            phtvDetectorIsVietnameseWordFromKeyStates(ptr.baseAddress, Int32(count)) != 0
        }
    }

    func detectorShouldRestoreEnglish(_ keyStatesPtr: [UInt32], _ count: Int) -> Bool {
        keyStatesPtr.withUnsafeBufferPointer { ptr in
            phtvDetectorShouldRestoreEnglishWord(ptr.baseAddress, Int32(count)) != 0
        }
    }

    func detectorKeyStatesToString(_ keyStatesPtr: [UInt32], _ count: Int) -> String {
        var buf = [CChar](repeating: 0, count: count + 1)
        let written = keyStatesPtr.withUnsafeBufferPointer { ptr in
            phtvDetectorKeyStatesToAscii(ptr.baseAddress, Int32(count), &buf, Int32(buf.count))
        }
        guard written > 0 else { return "" }
        return String(bytes: buf.prefix(Int(written)).map { UInt8(bitPattern: $0) }, encoding: .utf8) ?? ""
    }

    func findMacro(_ macroKey: inout [UInt32], _ macroContent: inout [UInt32]) -> Bool {
        let normalized = macroKey.map { getCharacterCode($0) }
        let keyCount = Int32(normalized.count)
        let required = normalized.withUnsafeBufferPointer { ptr in
            phtvFindMacroContentForNormalizedKeys(ptr.baseAddress, keyCount, phtvRuntimeAutoCapsMacroValue(), nil, 0)
        }
        if required < 0 { macroContent = []; return false }
        if required == 0 { macroContent = []; return true }
        macroContent = [UInt32](repeating: 0, count: Int(required))
        let actual = normalized.withUnsafeBufferPointer { ptr in
            macroContent.withUnsafeMutableBufferPointer { outPtr in
                phtvFindMacroContentForNormalizedKeys(ptr.baseAddress, keyCount, phtvRuntimeAutoCapsMacroValue(), outPtr.baseAddress, required)
            }
        }
        if actual < 0 { macroContent = []; return false }
        if actual < required { macroContent = Array(macroContent.prefix(Int(actual))) }
        return true
    }

    // MARK: - Vietnamese word helpers (EngineVietnameseHelpers.inc)

    func isVietnameseWordFromTypingWord(_ length: Int) -> Bool {
        guard length > 0 else { return false }
        let len = min(length, 30)
        var buf = [UInt32](repeating: 0, count: len)
        for i in 0..<len { buf[i] = typingWord[i] & 0x3F }
        return buf.withUnsafeBufferPointer { ptr in
            phtvDetectorIsVietnameseWordFromKeyStates(ptr.baseAddress, Int32(len)) != 0
        }
    }

    func isVietnameseFromCanonicalTelex(_ length: Int) -> Bool {
        guard length > 0 else { return false }
        var buf = [UInt32](repeating: 0, count: 64)
        var len = 0
        var toneKey: UInt32 = 0
        for i in 0..<length where len < 60 {
            let tw = typingWord[i]
            let baseKey = tw & 0x3F
            if baseKey == UInt32(KEY_D) && (tw & TONE_MASK) != 0 {
                buf[len] = UInt32(KEY_D); len += 1
                buf[len] = UInt32(KEY_D); len += 1
            } else if (tw & STANDALONE_MASK) == 0 && (tw & TONE_MASK) != 0 && isConsonant(UInt16(baseKey)) == false {
                buf[len] = baseKey; len += 1
                buf[len] = baseKey; len += 1
            } else {
                buf[len] = baseKey; len += 1
            }
            if (tw & (TONEW_MASK | STANDALONE_MASK)) != 0 && len < 62 {
                buf[len] = UInt32(KEY_W); len += 1
            }
            if (tw & MARK1_MASK) != 0 { toneKey = UInt32(KEY_S) }
            else if (tw & MARK2_MASK) != 0 { toneKey = UInt32(KEY_F) }
            else if (tw & MARK3_MASK) != 0 { toneKey = UInt32(KEY_R) }
            else if (tw & MARK4_MASK) != 0 { toneKey = UInt32(KEY_X) }
            else if (tw & MARK5_MASK) != 0 { toneKey = UInt32(KEY_J) }
        }
        if toneKey != 0 && len < 62 { buf[len] = toneKey; len += 1 }
        guard len >= 2 else { return false }
        let slice = Array(buf.prefix(len))
        return slice.withUnsafeBufferPointer { ptr in
            phtvDetectorIsVietnameseWordFromKeyStates(ptr.baseAddress, Int32(len)) != 0
        }
    }

    // MARK: - Session operations (EngineSessionInsert.inc + EngineSessionPersist.inc)

    func setKeyData(_ index: Int, _ keyCode: UInt16, _ isCaps: Bool) {
        guard index >= 0 && index < ENGINE_MAX_BUFF else { return }
        typingWord[index] = UInt32(keyCode) | (isCaps ? CAPS_MASK : 0)
    }

    func insertKey(_ keyCode: UInt16, _ isCaps: Bool, _ isCheckSpelling: Bool = true) {
        if idx >= ENGINE_MAX_BUFF {
            longWordHelper.append(typingWord[0])
            for i in 0..<(ENGINE_MAX_BUFF - 1) { typingWord[i] = typingWord[i + 1] }
            setKeyData(ENGINE_MAX_BUFF - 1, keyCode, isCaps)
        } else {
            setKeyData(idx, keyCode, isCaps)
            idx += 1
        }
        if isSpellCheckingEnabled() && isCheckSpelling { checkSpelling() }
        if keyCode == KEY_D && idx - 2 >= 0 && isConsonant(chr(idx - 2)) {
            tempDisableKey = false
        }
    }

    func insertState(_ keyCode: UInt16, _ isCaps: Bool) {
        if stateIdx >= ENGINE_MAX_BUFF {
            for i in 0..<(ENGINE_MAX_BUFF - 1) { keyStates[i] = keyStates[i + 1] }
            keyStates[ENGINE_MAX_BUFF - 1] = UInt32(keyCode) | (isCaps ? CAPS_MASK : 0)
        } else {
            keyStates[stateIdx] = UInt32(keyCode) | (isCaps ? CAPS_MASK : 0)
            stateIdx += 1
        }
    }

    func saveWord() {
        if hCode != HookCodeState.replaceMacro.rawValue {
            if idx > 0 {
                if !longWordHelper.isEmpty {
                    typingStatesData.removeAll()
                    for (i, v) in longWordHelper.enumerated() {
                        if i != 0 && i % ENGINE_MAX_BUFF == 0 {
                            typingStates.append(typingStatesData)
                            typingStatesData.removeAll()
                        }
                        typingStatesData.append(v)
                    }
                    typingStates.append(typingStatesData)
                    longWordHelper.removeAll()
                }
                typingStatesData.removeAll()
                for i in 0..<idx { typingStatesData.append(typingWord[i]) }
                typingStates.append(typingStatesData)
            }
        } else {
            typingStatesData.removeAll()
            for (i, v) in hMacroData.enumerated() {
                if i != 0 && i % ENGINE_MAX_BUFF == 0 {
                    typingStates.append(typingStatesData)
                    typingStatesData.removeAll()
                }
                typingStatesData.append(v)
            }
            typingStates.append(typingStatesData)
        }
    }

    func saveWord(_ keyCode: UInt32, _ count: Int) {
        typingStatesData.removeAll()
        for _ in 0..<count { typingStatesData.append(keyCode) }
        typingStates.append(typingStatesData)
    }

    func saveSpecialChar() {
        typingStatesData.removeAll()
        for v in specialChar { typingStatesData.append(v) }
        typingStates.append(typingStatesData)
        specialChar.removeAll()
    }

    func restoreLastTypingState() {
        guard !typingStates.isEmpty else { return }
        typingStatesData = typingStates.removeLast()
        guard !typingStatesData.isEmpty else { return }
        let first = UInt16(typingStatesData[0] & CHAR_MASK)
        if first == KEY_SPACE {
            spaceCount = typingStatesData.count
            idx = 0
        } else if kCharKeyCode.contains(first) {
            idx = 0
            specialChar = typingStatesData
            checkSpelling()
        } else {
            for i in 0..<typingStatesData.count { typingWord[i] = typingStatesData[i] }
            idx = typingStatesData.count
            if isSpellCheckingEnabled() {
                checkSpelling()
            } else {
                tempDisableKey = false
            }
        }
    }

    func startNewSession() {
        idx = 0
        hBPC = 0
        hNCC = 0
        tempDisableKey = false
        stateIdx = 0
        hasHandledMacro = false
        hasHandleQuickConsonant = false
        shouldUpperCaseEnglishRestore = false
        spaceCount = 0
        longWordHelper.removeAll()
        upperCaseStatus = 0
        upperCaseNeedsSpaceConfirm = false
        snapshotUpperCaseFirstChar = UInt8(phtvRuntimeUpperCaseFirstCharEnabled())
    }

    // MARK: - Spelling check (EngineSpellingCheck.inc)

    func checkSpelling(forceCheckVowel: Bool = false) {
        if idx == 0 {
            spellingOK = true; spellingVowelOK = true; tempDisableKey = false; return
        }
        spellingOK = false; spellingVowelOK = true
        spellingEndIndex = idx
        if idx > 0 && chr(idx - 1) == KEY_RIGHT_BRACKET { spellingEndIndex = idx - 1 }

        if spellingEndIndex > 0 {
            let quickStart = phtvRuntimeQuickStartConsonantEnabled() != 0
            let allowZFWJ = phtvRuntimeAllowConsonantZFWJEnabled() != 0
            let quickEnd = phtvRuntimeQuickEndConsonantEnabled() != 0
            var j = 0
            if isConsonant(chr(0)) {
                var matched = false
                for row in vnConsonantTable {
                    spellingFlag = false
                    if spellingEndIndex < row.count { spellingFlag = true }
                    j = 0
                    while j < row.count {
                        let rc = row[j]
                        let noQuickStart = rc & ~(quickStart ? END_CONSONANT_MASK : 0)
                        let noAllowMask = rc & ~(allowZFWJ ? CONSONANT_ALLOW_MASK : 0)
                        if spellingEndIndex > j && noQuickStart != chr(j) && noAllowMask != chr(j) {
                            spellingFlag = true; break
                        }
                        j += 1
                    }
                    if spellingFlag { continue }
                    matched = true; break
                }
                if !matched { j = spellingEndIndex }
            }

            if j == spellingEndIndex { spellingOK = true }

            var k = j
            VSI = k
            if chr(VSI) == KEY_U && k > 0 && k < spellingEndIndex - 1 && chr(VSI - 1) == KEY_Q {
                k += 1; j = k; VSI = k
            } else if idx >= 2 && chr(0) == KEY_G && chr(1) == KEY_I && isConsonant(chr(2)) {
                VSI = 1; k = 1; j = 1
            }
            var l = 0
            while l < 3 {
                if k < spellingEndIndex && !isConsonant(chr(k)) { k += 1; VEI = k }
                l += 1
            }

            if k > j {
                spellingVowelOK = false
                if k - j > 1 && forceCheckVowel {
                    let vowelSet = vnVowelCombine[chr(j)] ?? []
                    var ii = 0
                    for pattern in vowelSet {
                        spellingFlag = false
                        for pi in 1..<pattern.count {
                            let idx2 = j + pi - 1
                            if idx2 < spellingEndIndex {
                                let expected = pattern[pi]
                                let actual = UInt32(chr(idx2)) | (typingWord[idx2] & TONEW_MASK) | (typingWord[idx2] & TONE_MASK)
                                if expected != actual { spellingFlag = true; break }
                            }
                        }
                        ii = pattern.count - 1
                        let hasEndConsonant = k < spellingEndIndex && pattern[0] == 0
                        let lastIsConsonant = (j + ii - 1 < spellingEndIndex) && isConsonant(chr(j + ii - 1))
                        if spellingFlag || hasEndConsonant || lastIsConsonant { continue }
                        spellingVowelOK = true; break
                    }
                } else if !isConsonant(chr(j)) {
                    spellingVowelOK = true
                }

                j = 0
                for row in vnEndConsonantTable {
                    spellingFlag = false
                    var jj = 0
                    while jj < row.count {
                        let rc = row[jj]
                        let noQuick = rc & ~(quickEnd ? END_CONSONANT_MASK : 0)
                        if spellingEndIndex > k + jj && noQuick != chr(k + jj) {
                            spellingFlag = true; break
                        }
                        jj += 1
                    }
                    if spellingFlag { continue }
                    if k + jj >= spellingEndIndex { spellingOK = true; break }
                    j = jj
                }

                if spellingOK {
                    if idx >= 3 && chr(idx - 1) == KEY_H && chr(idx - 2) == KEY_C {
                        let tw = typingWord[idx - 3]
                        let okMark = (tw & MARK1_MASK) != 0 || (tw & MARK5_MASK) != 0 || (tw & MARK_MASK) == 0
                        if !okMark { spellingOK = false }
                    } else if idx >= 2 && chr(idx - 1) == KEY_T {
                        let tw = typingWord[idx - 2]
                        let okMark = (tw & MARK1_MASK) != 0 || (tw & MARK5_MASK) != 0 || (tw & MARK_MASK) == 0
                        if !okMark { spellingOK = false }
                    }
                }
            }
        } else {
            spellingOK = true
        }
        tempDisableKey = !(spellingOK && spellingVowelOK)
    }

    // MARK: - Grammar check (EngineGrammarCheck.inc)

    func checkGrammar(deltaBackSpace: Int) {
        guard idx > 1 && idx < ENGINE_MAX_BUFF else { return }
        findAndCalculateVowel(forGrammar: true)
        guard vowelCount > 0 else { return }
        isCheckedGrammar = false
        let l = VSI

        if idx >= 3 {
            outer: for i in stride(from: idx - 1, through: 0, by: -1) {
                let c = chr(i)
                if c == KEY_N || c == KEY_C || c == KEY_I || c == KEY_M || c == KEY_P || c == KEY_T {
                    if i - 2 >= 0 && chr(i - 1) == KEY_O && chr(i - 2) == KEY_U {
                        let tonewI1 = typingWord[i - 1] & TONEW_MASK
                        let tonewI2 = typingWord[i - 2] & TONEW_MASK
                        if tonewI1 ^ tonewI2 != 0 {
                            typingWord[i - 2] |= TONEW_MASK
                            typingWord[i - 1] |= TONEW_MASK
                            isCheckedGrammar = true
                            break outer
                        }
                    }
                }
            }
        }

        if idx >= 2 {
            for i in l...VEI {
                if (typingWord[i] & MARK_MASK) == 0 { continue }

                let tailStart: Int = {
                    if VEI > VSI {
                        let tailVowel = chr(VEI)
                        var ts = VEI
                        while ts > VSI && chr(ts - 1) == tailVowel { ts -= 1 }
                        return ts
                    }
                    return VEI
                }()
                let tailLen = VEI - tailStart + 1
                if tailLen >= 2 && i <= tailStart { isCheckedGrammar = false; break }

                var isExtendedVowel = false
                if i < VEI && chr(i) == chr(i + 1) {
                    isExtendedVowel = true
                    for ci in (i + 1)...VEI where chr(ci) != chr(i) { isExtendedVowel = false; break }
                }
                if isExtendedVowel { isCheckedGrammar = false; break }

                let mark = typingWord[i] & MARK_MASK
                typingWord[i] &= ~MARK_MASK
                insertMark(mark, canModifyFlag: false)
                if i != VWSM { isCheckedGrammar = true }
                break
            }
        }

        if isCheckedGrammar {
            if hCode == HookCodeState.doNothing.rawValue { hCode = HookCodeState.willProcess.rawValue }
            hBPC = 0
            for i in stride(from: idx - 1, through: l, by: -1) {
                hBPC += 1
                hData[idx - 1 - i] = get(typingWord[i])
            }
            hNCC = hBPC
            hBPC += deltaBackSpace
            hExt = 4
        }
    }

    // MARK: - Vowel operations (EngineVowelOps.inc)

    func findAndCalculateVowel(forGrammar: Bool = false) {
        vowelCount = 0; VSI = 0; VEI = 0
        var iii = idx - 1
        while iii >= 0 {
            if isConsonant(chr(iii)) {
                if vowelCount > 0 { break }
            } else {
                if vowelCount == 0 { VEI = iii }
                if !forGrammar {
                    if (iii - 1 >= 0 && chr(iii) == KEY_I && chr(iii - 1) == KEY_G) ||
                       (iii - 1 >= 0 && chr(iii) == KEY_U && chr(iii - 1) == KEY_Q) { break }
                }
                VSI = iii; vowelCount += 1
            }
            iii -= 1
        }
        if VSI - 1 >= 0 && chr(VSI) == KEY_U && chr(VSI - 1) == KEY_Q {
            VSI += 1; vowelCount -= 1
        }
    }

    func removeMark() {
        findAndCalculateVowel(forGrammar: true)
        isChanged = false
        if idx > 0 {
            for i in VSI...VEI {
                if (typingWord[i] & MARK_MASK) != 0 {
                    typingWord[i] &= ~MARK_MASK; isChanged = true
                }
            }
        }
        if isChanged {
            hCode = HookCodeState.willProcess.rawValue; hBPC = 0
            for i in stride(from: idx - 1, through: VSI, by: -1) {
                hBPC += 1; hData[idx - 1 - i] = get(typingWord[i])
            }
            hNCC = hBPC
        } else {
            hCode = HookCodeState.doNothing.rawValue
        }
    }

    func canHasEndConsonant() -> Bool {
        let vo = vnVowelCombine[chr(VSI)] ?? []
        for pattern in vo {
            var kk = VSI
            var iii = 1
            while iii < pattern.count {
                let tw = typingWord[kk]
                if kk > VEI || (UInt32(chr(kk)) | (tw & TONE_MASK) | (tw & TONEW_MASK)) != pattern[iii] { break }
                kk += 1; iii += 1
            }
            if iii >= pattern.count { return pattern[0] == 1 }
        }
        return false
    }

    // MARK: - Mark handling vowel check (EngineMarkHandlingVowelCheck.inc)

    func canFixVowelWithDiacriticsForMark() -> Bool {
        let savedVowelCount = vowelCount, savedVSI = VSI, savedVEI = VEI
        findAndCalculateVowel()
        defer { vowelCount = savedVowelCount; VSI = savedVSI; VEI = savedVEI }
        guard vowelCount > 0 else { return false }
        guard let patterns = vnVowelCombine[chr(VSI)] else { return false }
        for pattern in patterns {
            let patternLen = pattern.count - 1
            if patternLen < vowelCount { continue }
            var match = true
            for pIdx in 0..<vowelCount {
                let expected = pattern[pIdx + 1]
                let expectedBase = UInt16(expected & CHAR_MASK)
                let currentBase = chr(VSI + pIdx)
                if currentBase != expectedBase { match = false; break }
                let expectedTone = expected & (TONE_MASK | TONEW_MASK)
                let currentTone = typingWord[VSI + pIdx] & (TONE_MASK | TONEW_MASK)
                if expectedTone == 0 {
                    if currentTone != 0 { match = false; break }
                } else {
                    if currentTone != 0 && currentTone != expectedTone { match = false; break }
                }
            }
            if match { return true }
        }
        return false
    }

    // MARK: - Character lookup (EngineCharacterLookup.inc)

    func checkCorrectVowel(_ charset: [[UInt16]], _ charsetIdx: Int, _ k: inout Int, _ markKey: UInt16) {
        if idx >= 2 && chr(idx - 1) == KEY_U && chr(idx - 2) == KEY_Q { isCorect = false; return }
        k = idx - 1
        let quickEnd = phtvRuntimeQuickEndConsonantEnabled() != 0
        let row = charset[charsetIdx]
        var j = row.count - 1
        while j >= 0 {
            let rc = row[j] & ~(quickEnd ? END_CONSONANT_MASK : 0)
            if rc != chr(k) { isCorect = false; return }
            k -= 1
            if k < 0 { break }
            j -= 1
        }
        if isCorect && row.count > 1 && (isKeyF(markKey) || isKeyX(markKey) || isKeyR(markKey)) {
            if row[1] == KEY_C || row[1] == KEY_T { isCorect = false; return }
            if row.count > 2 && row[2] == KEY_T { isCorect = false; return }
        }
        if isCorect && k >= 0 {
            if chr(k) == chr(k + 1) &&
               (typingWord[k] & (TONE_MASK | TONEW_MASK)) == 0 &&
               (typingWord[k + 1] & (TONE_MASK | TONEW_MASK)) == 0 {
                if isMarkKey(markKey) && k + 2 < idx && chr(k) == chr(k + 2) {
                    // Allow triple vowels
                } else {
                    isCorect = false
                }
            }
        }
    }

    func getCharacterCode(_ data: UInt32) -> UInt32 {
        let ct = Int(runtimeCodeTableSnapshot)
        capsElem = (data & CAPS_MASK) != 0 ? 0 : 1
        keyVal = Int(data & CHAR_MASK)
        let codeTable = vnCodeTable
        guard ct < codeTable.count else { return data }
        let table = codeTable[ct]

        if (data & MARK_MASK) != 0 {
            markElem = -2
            switch data & MARK_MASK {
            case MARK1_MASK: markElem = 0
            case MARK2_MASK: markElem = 2
            case MARK3_MASK: markElem = 4
            case MARK4_MASK: markElem = 6
            case MARK5_MASK: markElem = 8
            default: break
            }
            markElem += capsElem
            switch UInt16(keyVal) {
            case KEY_A, KEY_O, KEY_U, KEY_E:
                if (data & TONE_MASK) == 0 && (data & TONEW_MASK) == 0 { markElem += 4 }
            default: break
            }
            var lookupKey = UInt32(keyVal)
            if (data & TONE_MASK) != 0 { lookupKey |= TONE_MASK }
            else if (data & TONEW_MASK) != 0 { lookupKey |= TONEW_MASK }
            guard let vals = table[lookupKey], markElem >= 0 && markElem < vals.count else { return data }
            return UInt32(vals[markElem]) | CHAR_CODE_MASK
        } else {
            let lookupKey = UInt32(keyVal)
            guard let vals = table[lookupKey] else { return data }
            if (data & TONE_MASK) != 0 {
                guard capsElem < vals.count else { return data }
                return UInt32(vals[capsElem]) | CHAR_CODE_MASK
            } else if (data & TONEW_MASK) != 0 {
                guard capsElem + 2 < vals.count else { return data }
                return UInt32(vals[capsElem + 2]) | CHAR_CODE_MASK
            } else {
                return data
            }
        }
    }

    // MARK: - Modern mark (EngineMarkHandlingModernMark.inc)

    func handleModernMark() {
        let originalVEI = VEI, originalVowelCount = vowelCount
        var adjustedTrailing = false, preferLastRepeat = false
        if vowelCount >= 2 {
            let tailVowel = chr(VEI)
            var tailStart = VEI
            while tailStart > VSI && chr(tailStart - 1) == tailVowel { tailStart -= 1 }
            if VEI - tailStart + 1 >= 2 {
                var runHasDiacritic = false
                for id in tailStart...VEI {
                    if (typingWord[id] & (TONE_MASK | TONEW_MASK)) != 0 { runHasDiacritic = true; break }
                }
                if !runHasDiacritic && tailVowel == KEY_O && tailStart == VSI {
                    preferLastRepeat = true
                } else {
                    VEI = tailStart; vowelCount = 0
                    for id in VSI...VEI where !isConsonant(chr(id)) { vowelCount += 1 }
                    adjustedTrailing = true
                }
            }
        }

        VWSM = VEI; hBPC = idx - VEI

        if vowelCount == 3 && (
            (chr(VSI) == KEY_O && chr(VSI+1) == KEY_A && chr(VSI+2) == KEY_I) ||
            (chr(VSI) == KEY_U && chr(VSI+1) == KEY_Y && chr(VSI+2) == KEY_U) ||
            (chr(VSI) == KEY_O && chr(VSI+1) == KEY_E && chr(VSI+2) == KEY_O) ||
            (chr(VSI) == KEY_U && chr(VSI+1) == KEY_Y && chr(VSI+2) == KEY_A)) {
            VWSM = VSI + 1; hBPC = idx - VWSM
        } else if vowelCount >= 2 && chr(VEI) == KEY_Y {
            if vowelCount == 2 && chr(VSI) == KEY_U && chr(VSI + 1) == KEY_Y {
                VWSM = VEI; hBPC = idx - VWSM
            } else {
                var lastNonY = VEI
                while lastNonY >= VSI && chr(lastNonY) == KEY_Y { lastNonY -= 1 }
                if lastNonY >= VSI { VWSM = lastNonY; hBPC = idx - VWSM }
            }
        } else if (chr(VSI) == KEY_O && chr(VSI+1) == KEY_I) ||
                  (chr(VSI) == KEY_A && chr(VSI+1) == KEY_I) ||
                  (chr(VSI) == KEY_U && chr(VSI+1) == KEY_I) {
            VWSM = VSI; hBPC = idx - VWSM
        } else if VEI - 1 >= VSI && chr(VEI-1) == KEY_A && chr(VEI) == KEY_Y {
            VWSM = VEI - 1; hBPC = (idx - VEI) + 1
        } else if chr(VSI) == KEY_U && chr(VSI+1) == KEY_O {
            VWSM = VSI + 1; hBPC = idx - VWSM
        } else if VSI + 1 <= VEI && (chr(VSI+1) == KEY_O || chr(VSI+1) == KEY_U) {
            VWSM = VEI - 1; hBPC = (idx - VEI) + 1
        } else if chr(VSI) == KEY_O || chr(VSI) == KEY_U {
            VWSM = VEI; hBPC = idx - VEI
        }

        if VSI + 1 <= VEI {
            let tw1 = typingWord[VSI + 1]
            let condition31 =
                (chr(VSI) == KEY_I && (tw1 & (UInt32(KEY_E) | TONE_MASK)) != 0) ||
                (chr(VSI) == KEY_Y && (tw1 & (UInt32(KEY_E) | TONE_MASK)) != 0) ||
                (chr(VSI) == KEY_U && typingWord[VSI + 1] == (UInt32(KEY_O) | TONE_MASK)) ||
                ((typingWord[VSI] == (UInt32(KEY_U) | TONEW_MASK)) && (typingWord[VSI + 1] == (UInt32(KEY_O) | TONEW_MASK)))

            if condition31 {
                var forceSecond = false
                if (chr(VSI) == KEY_I || chr(VSI) == KEY_Y) && chr(VSI + 1) == KEY_E && (tw1 & TONE_MASK) != 0 { forceSecond = true }
                else if chr(VSI) == KEY_U && chr(VSI + 1) == KEY_O && (tw1 & TONE_MASK) != 0 { forceSecond = true }
                else if (typingWord[VSI] & TONEW_MASK) != 0 && (tw1 & TONEW_MASK) != 0 && chr(VSI) == KEY_U && chr(VSI + 1) == KEY_O { forceSecond = true }

                if forceSecond {
                    VWSM = VSI + 1; hBPC = idx - VWSM
                } else if VSI + 2 < idx {
                    let c2 = chr(VSI + 2)
                    if c2 == KEY_P || c2 == KEY_T || c2 == KEY_M || c2 == KEY_N ||
                       c2 == KEY_O || c2 == KEY_U || c2 == KEY_I || c2 == KEY_C {
                        VWSM = VSI + 1; hBPC = idx - VWSM
                    } else {
                        VWSM = VSI; hBPC = idx - VWSM
                    }
                } else {
                    VWSM = VSI; hBPC = idx - VWSM
                }
            }
        }

        if vowelCount == 2 {
            if ((chr(VSI) == KEY_I) && (chr(VSI+1) == KEY_A)) ||
               ((chr(VSI) == KEY_I) && (chr(VSI+1) == KEY_U)) ||
               ((chr(VSI) == KEY_I) && (chr(VSI+1) == KEY_O)) {
                if VSI == 0 || chr(VSI - 1) != KEY_G {
                    VWSM = VSI; hBPC = idx - VWSM
                } else {
                    VWSM = VSI + 1; hBPC = idx - VWSM
                }
            } else if chr(VSI) == KEY_U && chr(VSI+1) == KEY_A {
                if VSI == 0 || chr(VSI - 1) != KEY_Q {
                    if VEI + 1 >= idx || !canHasEndConsonant() {
                        VWSM = VSI; hBPC = idx - VWSM
                    }
                } else {
                    VWSM = VSI + 1; hBPC = idx - VWSM
                }
            } else if chr(VSI) == KEY_O && chr(VSI+1) == KEY_O {
                VWSM = VEI; hBPC = idx - VWSM
            }
        }

        if preferLastRepeat { VWSM = originalVEI; hBPC = idx - VWSM }
        if adjustedTrailing { VEI = originalVEI; vowelCount = originalVowelCount }
    }

    // MARK: - Old mark (EngineMarkHandlingOldMark.inc)

    func handleOldMark() {
        let originalVEI = VEI, originalVowelCount = vowelCount
        var adjustedTrailing = false
        if vowelCount >= 2 {
            let tailVowel = chr(VEI)
            var tailStart = VEI
            while tailStart > VSI && chr(tailStart - 1) == tailVowel { tailStart -= 1 }
            if VEI - tailStart + 1 >= 2 {
                VEI = tailStart; vowelCount = 0
                for id in VSI...VEI where !isConsonant(chr(id)) { vowelCount += 1 }
                adjustedTrailing = true
            }
        }

        if vowelCount == 0 && chr(VEI) == KEY_I { VWSM = VEI } else { VWSM = VSI }
        hBPC = idx - VWSM

        if vowelCount == 3 || (VEI + 1 < idx && isConsonant(chr(VEI + 1)) && canHasEndConsonant()) {
            VWSM = VSI + 1; hBPC = idx - VWSM
        }

        for ii in VSI...VEI {
            if (chr(ii) == KEY_E && (typingWord[ii] & TONE_MASK) != 0) ||
               (chr(ii) == KEY_O && (typingWord[ii] & TONEW_MASK) != 0) {
                VWSM = ii; hBPC = idx - VWSM; break
            }
        }

        hNCC = hBPC
        if adjustedTrailing { VEI = originalVEI; vowelCount = originalVowelCount }
    }

    // MARK: - Insert mark (EngineMarkHandlingOldMark.inc)

    func insertMark(_ markMask: UInt32, canModifyFlag: Bool = true) {
        vowelCount = 0
        if canModifyFlag { hCode = HookCodeState.willProcess.rawValue }
        hBPC = 0; hNCC = 0
        findAndCalculateVowel()
        VWSM = 0

        if vowelCount == 1 {
            VWSM = VEI; hBPC = idx - VEI
        } else {
            if phtvRuntimeUseModernOrthographyEnabled() == 0 { handleOldMark() } else { handleModernMark() }
            if (typingWord[VEI] & TONE_MASK) != 0 || (typingWord[VEI] & TONEW_MASK) != 0 {
                VWSM = VEI
            }
        }

        let kk0 = idx - 1 - VSI
        var kk = kk0
        if (typingWord[VWSM] & markMask) != 0 {
            typingWord[VWSM] &= ~MARK_MASK
            if canModifyFlag { hCode = HookCodeState.restore.rawValue }
            kk = kk0
            for ii in VSI..<idx {
                typingWord[ii] &= ~MARK_MASK
                hData[kk] = get(typingWord[ii])
                kk -= 1
            }
            tempDisableKey = true
        } else {
            typingWord[VWSM] &= ~MARK_MASK
            typingWord[VWSM] |= markMask
            kk = kk0
            for ii in VSI..<idx {
                if ii != VWSM { typingWord[ii] &= ~MARK_MASK }
                hData[kk] = get(typingWord[ii])
                kk -= 1
            }
            hBPC = idx - VSI
        }
        hNCC = hBPC
    }

    // MARK: - Insert D (EngineMarkHandlingInsertD.inc)

    func insertD(_ data: UInt16, _ isCaps: Bool) {
        hCode = HookCodeState.willProcess.rawValue; hBPC = 0
        var ii = idx - 1
        while ii >= 0 {
            hBPC += 1
            if chr(ii) == KEY_D {
                if (typingWord[ii] & TONE_MASK) != 0 {
                    hCode = HookCodeState.restore.rawValue
                    typingWord[ii] &= ~TONE_MASK
                    hData[idx - 1 - ii] = typingWord[ii]
                    tempDisableKey = true
                } else {
                    typingWord[ii] |= TONE_MASK
                    hData[idx - 1 - ii] = get(typingWord[ii])
                }
                break
            } else {
                hData[idx - 1 - ii] = get(typingWord[ii])
            }
            ii -= 1
        }
        hNCC = hBPC
    }

    // MARK: - Insert AOE (EngineMarkHandlingInsertAOE.inc)

    func insertAOE(_ data: UInt16, _ isCaps: Bool) {
        findAndCalculateVowel()
        for ii in VSI...VEI { typingWord[ii] &= ~TONEW_MASK }
        hCode = HookCodeState.willProcess.rawValue; hBPC = 0
        var ii = idx - 1
        while ii >= 0 {
            hBPC += 1
            if chr(ii) == data {
                if (typingWord[ii] & TONE_MASK) != 0 {
                    hCode = HookCodeState.restore.rawValue
                    typingWord[ii] &= ~TONE_MASK
                    hData[idx - 1 - ii] = typingWord[ii]
                    if data != KEY_O { tempDisableKey = true }
                } else {
                    typingWord[ii] |= TONE_MASK
                    if !isKeyD(data) { typingWord[ii] &= ~TONEW_MASK }
                    hData[idx - 1 - ii] = get(typingWord[ii])
                }
                break
            } else {
                hData[idx - 1 - ii] = get(typingWord[ii])
            }
            ii -= 1
        }
        hNCC = hBPC
    }

    // MARK: - Insert W (EngineMarkHandlingInsertW.inc)

    func insertW(_ data: UInt16, _ isCaps: Bool) {
        isRestoredW = false
        findAndCalculateVowel()
        for ii in VSI...VEI { typingWord[ii] &= ~TONE_MASK }

        if vowelCount > 1 {
            hBPC = idx - VSI; hNCC = hBPC
            let both = (typingWord[VSI] & TONEW_MASK) != 0 && (typingWord[VSI + 1] & TONEW_MASK) != 0
            let withI = (typingWord[VSI] & TONEW_MASK) != 0 && chr(VSI + 1) == KEY_I
            let withA = (typingWord[VSI] & TONEW_MASK) != 0 && chr(VSI + 1) == KEY_A
            if both || withI || withA {
                hCode = HookCodeState.restore.rawValue
                for ii in VSI..<idx {
                    typingWord[ii] &= ~TONEW_MASK
                    hData[idx - 1 - ii] = get(typingWord[ii]) & ~STANDALONE_MASK
                }
                isRestoredW = true; tempDisableKey = true
            } else {
                hCode = HookCodeState.willProcess.rawValue
                var shouldRestore = false
                if chr(VSI) == KEY_U && chr(VSI + 1) == KEY_O {
                    let isThu = VSI - 2 >= 0 && typingWord[VSI - 2] == UInt32(KEY_T) && typingWord[VSI - 1] == UInt32(KEY_H)
                    let isQuo = VSI - 1 >= 0 && typingWord[VSI - 1] == UInt32(KEY_Q)
                    if isThu {
                        if (typingWord[VSI + 1] & TONEW_MASK) != 0 { shouldRestore = true }
                        else {
                            typingWord[VSI + 1] |= TONEW_MASK
                            if VSI + 2 < idx && chr(VSI + 2) == KEY_N { typingWord[VSI] |= TONEW_MASK }
                        }
                    } else if isQuo {
                        if (typingWord[VSI + 1] & TONEW_MASK) != 0 { shouldRestore = true }
                        else { typingWord[VSI + 1] |= TONEW_MASK }
                    } else {
                        if (typingWord[VSI] & TONEW_MASK) != 0 && (typingWord[VSI + 1] & TONEW_MASK) == 0 {
                            typingWord[VSI + 1] |= TONEW_MASK
                        } else if (typingWord[VSI] & TONEW_MASK) != 0 || (typingWord[VSI + 1] & TONEW_MASK) != 0 {
                            shouldRestore = true
                        } else {
                            typingWord[VSI] |= TONEW_MASK; typingWord[VSI + 1] |= TONEW_MASK
                        }
                    }
                } else if (chr(VSI) == KEY_U && chr(VSI + 1) == KEY_A) ||
                          (chr(VSI) == KEY_U && chr(VSI + 1) == KEY_I) ||
                          (chr(VSI) == KEY_U && chr(VSI + 1) == KEY_U) ||
                          (chr(VSI) == KEY_O && chr(VSI + 1) == KEY_I) {
                    if (typingWord[VSI] & TONEW_MASK) != 0 { shouldRestore = true }
                    else { typingWord[VSI] |= TONEW_MASK }
                } else if (chr(VSI) == KEY_I && chr(VSI + 1) == KEY_O) ||
                          (chr(VSI) == KEY_O && chr(VSI + 1) == KEY_A) {
                    if (typingWord[VSI + 1] & TONEW_MASK) != 0 { shouldRestore = true }
                    else { typingWord[VSI + 1] |= TONEW_MASK }
                } else {
                    tempDisableKey = true; isChanged = false; hCode = HookCodeState.doNothing.rawValue
                }
                if shouldRestore {
                    hCode = HookCodeState.restore.rawValue
                    for ii in VSI..<idx {
                        typingWord[ii] &= ~TONEW_MASK
                        hData[idx - 1 - ii] = get(typingWord[ii]) & ~STANDALONE_MASK
                    }
                    isRestoredW = true; tempDisableKey = true
                } else if hCode == HookCodeState.willProcess.rawValue {
                    for ii in VSI..<idx { hData[idx - 1 - ii] = get(typingWord[ii]) }
                }
            }
            return
        }

        hCode = HookCodeState.willProcess.rawValue; hBPC = 0
        var ii = idx - 1
        while ii >= 0 {
            if ii < VSI { break }
            hBPC += 1
            switch chr(ii) {
            case KEY_A, KEY_U, KEY_O:
                if (typingWord[ii] & TONEW_MASK) != 0 {
                    if (typingWord[ii] & STANDALONE_MASK) != 0 {
                        hCode = HookCodeState.willProcess.rawValue
                        if chr(ii) == KEY_U {
                            typingWord[ii] = UInt32(KEY_W) | ((typingWord[ii] & CAPS_MASK) != 0 ? CAPS_MASK : 0)
                        } else if chr(ii) == KEY_O {
                            hCode = HookCodeState.restore.rawValue
                            typingWord[ii] = UInt32(KEY_O) | ((typingWord[ii] & CAPS_MASK) != 0 ? CAPS_MASK : 0)
                            isRestoredW = true
                        }
                        hData[idx - 1 - ii] = typingWord[ii]
                    } else {
                        hCode = HookCodeState.restore.rawValue
                        typingWord[ii] &= ~TONEW_MASK
                        hData[idx - 1 - ii] = typingWord[ii]
                        isRestoredW = true
                    }
                    tempDisableKey = true
                } else {
                    typingWord[ii] |= TONEW_MASK; typingWord[ii] &= ~TONE_MASK
                    hData[idx - 1 - ii] = get(typingWord[ii])
                }
            default:
                hData[idx - 1 - ii] = get(typingWord[ii])
            }
            ii -= 1
        }
        hNCC = hBPC
    }

    // MARK: - Standalone and caps (EngineStandaloneAndCaps.inc)

    func reverseLastStandaloneChar(_ keyCode: UInt32, _ isCaps: Bool) {
        hCode = HookCodeState.willProcess.rawValue
        hBPC = 0; hNCC = 1; hExt = 4
        typingWord[idx - 1] = keyCode | TONEW_MASK | STANDALONE_MASK | (isCaps ? CAPS_MASK : 0)
        hData[0] = get(typingWord[idx - 1])
    }

    func checkForStandaloneChar(_ data: UInt16, _ isCaps: Bool, _ keyWillReverse: UInt16) {
        if idx > 0 && chr(idx - 1) == keyWillReverse && (typingWord[idx - 1] & TONEW_MASK) != 0 {
            hCode = HookCodeState.willProcess.rawValue
            hBPC = 1; hNCC = 1
            typingWord[idx - 1] = UInt32(data) | (isCaps ? CAPS_MASK : 0)
            hData[0] = get(typingWord[idx - 1])
            return
        }
        if idx > 0 && chr(idx - 1) == KEY_U && keyWillReverse == KEY_O {
            insertKey(keyWillReverse, isCaps)
            reverseLastStandaloneChar(UInt32(keyWillReverse), isCaps)
            return
        }
        if idx == 0 {
            insertKey(data, isCaps, false)
            reverseLastStandaloneChar(UInt32(keyWillReverse), isCaps)
            return
        } else if idx == 1 {
            if vnStandaloneWBad.contains(chr(0)) {
                insertKey(data, isCaps)
                return
            }
            insertKey(data, isCaps, false)
            reverseLastStandaloneChar(UInt32(keyWillReverse), isCaps)
            return
        } else if idx == 2 {
            for pattern in vnDoubleWAllowed {
                if chr(0) == pattern[0] && chr(1) == pattern[1] {
                    insertKey(data, isCaps, false)
                    reverseLastStandaloneChar(UInt32(keyWillReverse), isCaps)
                    return
                }
            }
            insertKey(data, isCaps)
            return
        }
        insertKey(data, isCaps)
    }

    func upperCaseFirstCharacter() {
        if (typingWord[0] & CAPS_MASK) == 0 {
            hCode = HookCodeState.willProcess.rawValue
            hBPC = 0; hNCC = 1
            typingWord[0] |= CAPS_MASK
            hData[0] = get(typingWord[0])
            upperCaseStatus = 0
            if phtvRuntimeUseMacroEnabled() != 0 && !hMacroKey.isEmpty {
                hMacroKey[0] |= CAPS_MASK
            }
        }
    }

    // MARK: - Main key handling (EngineMainKeyHandling.inc)

    func handleMainKey(_ data: UInt16, _ isCaps: Bool) {
        if isKeyZ(data) {
            removeMark()
            if !isChanged {
                var hasToneW = false
                for ii in 0..<idx where (typingWord[ii] & TONEW_MASK) != 0 { hasToneW = true; break }
                if hasToneW {
                    if isSpellCheckingEnabled() { checkSpelling(forceCheckVowel: true) }
                    if spellingOK && spellingVowelOK {
                        if isKeyS(data) { insertMark(MARK1_MASK) }
                        else if isKeyF(data) { insertMark(MARK2_MASK) }
                        else if isKeyR(data) { insertMark(MARK3_MASK) }
                        else if isKeyX(data) { insertMark(MARK4_MASK) }
                        else if isKeyJ(data) { insertMark(MARK5_MASK) }
                        return
                    }
                    var markIndex = -1
                    for ii in stride(from: idx - 1, through: 0, by: -1) where (typingWord[ii] & TONEW_MASK) != 0 {
                        markIndex = ii; break
                    }
                    if markIndex >= 0 {
                        typingWord[markIndex] &= ~MARK_MASK
                        if isKeyS(data) { typingWord[markIndex] |= MARK1_MASK }
                        else if isKeyF(data) { typingWord[markIndex] |= MARK2_MASK }
                        else if isKeyR(data) { typingWord[markIndex] |= MARK3_MASK }
                        else if isKeyX(data) { typingWord[markIndex] |= MARK4_MASK }
                        else if isKeyJ(data) { typingWord[markIndex] |= MARK5_MASK }
                        hCode = HookCodeState.willProcess.rawValue; hBPC = 0
                        for ii in stride(from: idx - 1, through: 0, by: -1) { hBPC += 1; hData[idx - 1 - ii] = get(typingWord[ii]) }
                        hNCC = hBPC; return
                    }
                }
                insertKey(data, isCaps)
            }
            return
        }

        if data == KEY_LEFT_BRACKET { checkForStandaloneChar(data, isCaps, KEY_O); return }
        if data == KEY_RIGHT_BRACKET { checkForStandaloneChar(data, isCaps, KEY_U); return }

        if isKeyD(data) {
            isCorect = false; isChanged = false
            var k = idx
            for (i, row) in vnConsonantD.enumerated() {
                if idx < row.count { continue }
                isCorect = true
                checkCorrectVowel(vnConsonantD, i, &k, data)
                if !isCorect && idx - 2 >= 0 && chr(idx - 1) == KEY_D && isConsonant(chr(idx - 2)) { isCorect = true }
                if isCorect { isChanged = true; insertD(data, isCaps); break }
            }
            if !isChanged { insertKey(data, isCaps) }
            return
        }

        if isMarkKey(data) {
            if idx >= 2 && chr(idx - 1) == KEY_U && chr(idx - 2) == KEY_U &&
               (typingWord[idx - 2] & TONEW_MASK) != 0 && (typingWord[idx - 1] & TONEW_MASK) == 0 {
                typingWord[idx - 2] &= ~MARK_MASK
                if isKeyS(data) { typingWord[idx - 2] |= MARK1_MASK }
                else if isKeyF(data) { typingWord[idx - 2] |= MARK2_MASK }
                else if isKeyR(data) { typingWord[idx - 2] |= MARK3_MASK }
                else if isKeyX(data) { typingWord[idx - 2] |= MARK4_MASK }
                else if isKeyJ(data) { typingWord[idx - 2] |= MARK5_MASK }
                hCode = HookCodeState.willProcess.rawValue; hBPC = 0
                for ii in stride(from: idx - 1, through: 0, by: -1) { hBPC += 1; hData[idx - 1 - ii] = get(typingWord[ii]) }
                hNCC = hBPC; return
            }
            for (_, patterns) in vnVowelForMark {
                isCorect = false; isChanged = false
                var k = idx
                for (l, row) in patterns.enumerated() {
                    if idx < row.count { continue }
                    isCorect = true
                    checkCorrectVowel(patterns, l, &k, data)
                    if isCorect {
                        isChanged = true
                        if isKeyS(data) { insertMark(MARK1_MASK) }
                        else if isKeyF(data) { insertMark(MARK2_MASK) }
                        else if isKeyR(data) { insertMark(MARK3_MASK) }
                        else if isKeyX(data) { insertMark(MARK4_MASK) }
                        else if isKeyJ(data) { insertMark(MARK5_MASK) }
                        break
                    }
                }
                if isCorect { break }
            }
            if !isChanged {
                var markIndex = -1
                for ii in stride(from: idx - 1, through: 0, by: -1) where (typingWord[ii] & TONEW_MASK) != 0 {
                    markIndex = ii
                    break
                }
                if markIndex >= 0 {
                    typingWord[markIndex] &= ~MARK_MASK
                    if isKeyS(data) { typingWord[markIndex] |= MARK1_MASK }
                    else if isKeyF(data) { typingWord[markIndex] |= MARK2_MASK }
                    else if isKeyR(data) { typingWord[markIndex] |= MARK3_MASK }
                    else if isKeyX(data) { typingWord[markIndex] |= MARK4_MASK }
                    else if isKeyJ(data) { typingWord[markIndex] |= MARK5_MASK }
                    hCode = HookCodeState.willProcess.rawValue
                    hBPC = 0
                    for ii in stride(from: idx - 1, through: 0, by: -1) {
                        hBPC += 1
                        hData[idx - 1 - ii] = get(typingWord[ii])
                    }
                    hNCC = hBPC
                } else {
                    insertKey(data, isCaps)
                }
            }
            return
        }

        if runtimeInputTypeSnapshot == 1 { // VNI
            for i in stride(from: idx - 1, through: 0, by: -1) {
                let c = chr(i)
                if c == KEY_O || c == KEY_A || c == KEY_E { VEI = i; break }
            }
        }

        keyForAEO = runtimeInputTypeSnapshot != 1 ? data :
            (data == KEY_7 || data == KEY_8 ? KEY_W : (data == KEY_6 ? chr(VEI) : data))

        guard let charset = vnVowelPatterns[keyForAEO] else {
            if data == KEY_W && runtimeInputTypeSnapshot != 2 {
                checkForStandaloneChar(data, isCaps, KEY_U)
            } else {
                insertKey(data, isCaps)
            }
            return
        }

        isCorect = false; isChanged = false
        var k = idx
        for (i, row) in charset.enumerated() {
            if idx < row.count { continue }
            isCorect = true
            checkCorrectVowel(charset, i, &k, data)
            if isCorect {
                isChanged = true
                if isKeyDouble(data) {
                    insertAOE(keyForAEO, isCaps)
                } else if isKeyW(data) {
                    if runtimeInputTypeSnapshot == 1 {
                        for j in stride(from: idx - 1, through: 0, by: -1) {
                            let c = chr(j)
                            if c == KEY_O || c == KEY_U || c == KEY_A || c == KEY_E { VEI = j; break }
                        }
                        let cond7 = data == KEY_7 && chr(VEI) == KEY_A && (VEI - 1 >= 0 ? chr(VEI - 1) != KEY_U : true)
                        let cond8 = data == KEY_8 && (chr(VEI) == KEY_O || chr(VEI) == KEY_U)
                        if cond7 || cond8 { break }
                    }
                    insertW(keyForAEO, isCaps)
                }
                break
            }
        }
        if !isChanged {
            if data == KEY_W && runtimeInputTypeSnapshot != 2 {
                checkForStandaloneChar(data, isCaps, KEY_U)
            } else {
                insertKey(data, isCaps)
            }
        }
    }

    // MARK: - Restore operations (EngineRestoreOps.inc)

    func handleQuickTelex(_ data: UInt16, _ isCaps: Bool) {
        guard let qt = vnQuickTelex[UInt32(data)] else { return }
        hCode = HookCodeState.willProcess.rawValue; hBPC = 1; hNCC = 2
        hData[1] = UInt32(qt[0]) | (isCaps ? CAPS_MASK : 0)
        hData[0] = UInt32(qt[1]) | (isCaps ? CAPS_MASK : 0)
        insertKey(qt[1], isCaps, false)
    }

    func restoreToRawKeys() -> Bool {
        guard stateIdx > 0 && idx > 0 else { return false }
        var hasTransforms = false
        for ii in 0..<idx where (typingWord[ii] & (MARK_MASK | TONE_MASK | TONEW_MASK | STANDALONE_MASK)) != 0 {
            hasTransforms = true; break
        }
        guard hasTransforms else { return false }
        hCode = HookCodeState.restore.rawValue
        hBPC = idx; hNCC = stateIdx
        for i in 0..<stateIdx {
            typingWord[i] = keyStates[i]
            hData[stateIdx - 1 - i] = keyStates[i]
        }
        idx = stateIdx
        return true
    }

    func checkRestoreIfWrongSpelling(_ handleCode: Int32) -> Bool {
        for ii in 0..<idx {
            if !isConsonant(chr(ii)) &&
               ((typingWord[ii] & MARK_MASK) != 0 || (typingWord[ii] & TONE_MASK) != 0 || (typingWord[ii] & TONEW_MASK) != 0) {
                hCode = handleCode; hBPC = idx; hNCC = stateIdx
                for i in 0..<stateIdx {
                    typingWord[i] = keyStates[i]
                    hData[stateIdx - 1 - i] = typingWord[i]
                }
                idx = stateIdx; return true
            }
        }
        return false
    }

    // MARK: - Quick consonant (EngineQuickConsonant.inc)

    func checkQuickConsonant() -> Bool {
        guard idx > 1 else { return false }
        let quickStart = phtvRuntimeQuickStartConsonantEnabled() != 0
        let quickEnd = phtvRuntimeQuickEndConsonantEnabled() != 0
        var l = 0
        if idx > 0 {
            if quickStart, let qsc = vnQuickStartConsonant[chr(0)] {
                hCode = HookCodeState.restore.rawValue
                hBPC = idx; hNCC = idx + 1
                if idx < ENGINE_MAX_BUFF - 1 { idx += 1 }
                for i in stride(from: idx - 1, through: 2, by: -1) { typingWord[i] = typingWord[i - 1] }
                typingWord[1] = UInt32(qsc[1]) | ((typingWord[0] & CAPS_MASK) != 0 && (typingWord[2] & CAPS_MASK) != 0 ? CAPS_MASK : 0)
                typingWord[0] = UInt32(qsc[0]) | ((typingWord[0] & CAPS_MASK) != 0 ? CAPS_MASK : 0)
                l = 1
            }
            if quickEnd && idx - 2 >= 0 && !isConsonant(chr(idx - 2)),
               let qec = vnQuickEndConsonant[chr(idx - 1)] {
                hCode = HookCodeState.restore.rawValue
                if l == 1 { hNCC += 1 } else { hBPC = 1; hNCC = 2 }
                if idx < ENGINE_MAX_BUFF - 1 { idx += 1 }
                typingWord[idx - 1] = UInt32(qec[1]) | ((typingWord[idx - 2] & CAPS_MASK) != 0 ? CAPS_MASK : 0)
                typingWord[idx - 2] = UInt32(qec[0]) | ((typingWord[idx - 2] & CAPS_MASK) != 0 ? CAPS_MASK : 0)
                l = 1
            }
            if l == 1 {
                hasHandleQuickConsonant = true
                for i in stride(from: idx - 1, through: 0, by: -1) { hData[idx - 1 - i] = get(typingWord[i]) }
                return true
            }
        }
        return false
    }

    func vTempOffSpellChecking() {
        if useSpellCheckingBefore { setSpellCheckingEnabled(!isSpellCheckingEnabled()) }
    }

    func vSetCheckSpelling() { useSpellCheckingBefore = isSpellCheckingEnabled() }
    func vTempOffEngine(_ off: Bool) { willTempOffEngine = off }
    func vRestoreToRawKeys() -> Bool { restoreToRawKeys() }

    // MARK: - Restore session (EngineRestoreSession.inc)

    func getEngineCharFromUnicode(_ ch: UInt16) -> UInt32 {
        refreshRuntimeLayoutSnapshot()
        let ct = Int(runtimeCodeTableSnapshot)
        guard ct < vnCodeTable.count else { return UInt32(ch) | PURE_CHARACTER_MASK }
        let table = vnCodeTable[ct]
        for (key, vals) in table {
            for (i, v) in vals.enumerated() where v == ch {
                var engineChar = key & CHAR_MASK
                let isCaps = (i % 2 == 0)
                if isCaps { engineChar |= CAPS_MASK }
                if (key & TONE_MASK) != 0 { engineChar |= TONE_MASK }
                if (key & TONEW_MASK) != 0 { engineChar |= TONEW_MASK }
                if (key & (TONE_MASK | TONEW_MASK)) == 0 {
                    if i <= 1 { engineChar |= TONE_MASK }
                    else if i <= 3 { engineChar |= TONEW_MASK }
                    else if i <= 5 { engineChar |= MARK1_MASK }
                    else if i <= 7 { engineChar |= MARK2_MASK }
                    else if i <= 9 { engineChar |= MARK3_MASK }
                    else if i <= 11 { engineChar |= MARK4_MASK }
                    else if i <= 13 { engineChar |= MARK5_MASK }
                } else {
                    if i <= 1 { engineChar |= MARK1_MASK }
                    else if i <= 3 { engineChar |= MARK2_MASK }
                    else if i <= 5 { engineChar |= MARK3_MASK }
                    else if i <= 7 { engineChar |= MARK4_MASK }
                    else if i <= 9 { engineChar |= MARK5_MASK }
                }
                engineChar |= CHAR_CODE_MASK
                return engineChar
            }
        }
        if ch < 128, let mapped = vnCharacterMap[UInt32(ch)] { return mapped }
        return UInt32(ch) | PURE_CHARACTER_MASK
    }

    func vRestoreSessionWithWord(_ word: [UInt16]) {
        let pendingKeys = Array(keyStates.prefix(stateIdx))
        startNewSession()
        for (_, ch) in word.prefix(ENGINE_MAX_BUFF).enumerated() {
            let engineChar = getEngineCharFromUnicode(ch)
            typingWord[idx] = engineChar
            keyStates[stateIdx] = engineChar
            idx += 1; stateIdx += 1
        }
        saveWord()
        checkSpelling()
        for keyData in pendingKeys {
            let keyCode = UInt16(keyData & CHAR_MASK)
            let wasCaps = (keyData & CAPS_MASK) != 0
            vKeyHandleEvent(
                event: VKeyEvent.keyboard,
                state: VKeyEventState.keyDown,
                data: keyCode,
                capsStatus: wasCaps ? 1 : 0,
                otherControlKey: false
            )
        }
    }

    // MARK: - Session bootstrap (EngineSessionBootstrap.inc)

    func vPrimeUpperCaseFirstChar() {
        if phtvRuntimeUpperCaseFirstCharEnabled() != 0 && phtvRuntimeUpperCaseExcludedForCurrentApp() == 0 {
            upperCaseStatus = 2
        }
    }

    func vKeyInit() {
        refreshRuntimeLayoutSnapshot()
        idx = 0; stateIdx = 0
        useSpellCheckingBefore = isSpellCheckingEnabled()
        typingStatesData.removeAll(); typingStates.removeAll(); longWordHelper.removeAll()
        vPrimeUpperCaseFirstChar()
    }

    // MARK: - Word break helpers (EngineWordBreakHelpers.inc)

    func isWordBreak(event: VKeyEvent, state: VKeyEventState, data: UInt16) -> Bool {
        if event == .mouse { return true }
        return kBreakCode.contains(data)
    }

    func isMacroBreakCode(_ data: UInt16) -> Bool { kMacroBreakCode.contains(data) }

    func isBracketPunctuationBreak(_ data: UInt16) -> Bool {
        data == KEY_LEFT_BRACKET || data == KEY_RIGHT_BRACKET
    }

    func isShiftedNumericPunctuationBreak(_ data: UInt16, _ capsStatus: UInt8) -> Bool {
        guard capsStatus == 1 else { return false }
        return data == KEY_1 || data == KEY_9 || data == KEY_0
    }

    func isAutoRestoreWordBreak(event: VKeyEvent, state: VKeyEventState, data: UInt16, capsStatus: UInt8) -> Bool {
        isWordBreak(event: event, state: state, data: data) ||
        isShiftedNumericPunctuationBreak(data, capsStatus)
    }

    func isLikelyUppercaseAbbreviation(_ keyStatesPtr: [UInt32], _ count: Int) -> Bool {
        guard count > 0 && count <= 12 else { return false }
        var allDigits = true
        for i in 0..<count where !isNumberKey(UInt16(keyStatesPtr[i] & 0x3F)) { allDigits = false; break }
        if allDigits { return true }
        if count == 1 { return true }
        if count <= 5 {
            let word = detectorKeyStatesToString(keyStatesPtr, count)
            if word.count == count && kAbbreviations.contains(word) { return true }
        }
        return false
    }

    func isSentenceTerminator(_ data: UInt16, _ capsStatus: UInt8) -> Bool {
        if data == KEY_ENTER || data == KEY_RETURN { return true }
        if data == KEY_DOT && capsStatus != 1 {
            if isLikelyUppercaseAbbreviation(Array(keyStates.prefix(stateIdx)), stateIdx) { return false }
            return true
        }
        if capsStatus == 1 && (data == KEY_SLASH || data == KEY_1) { return true }
        return false
    }

    func isUppercaseSkippablePunctuation(_ data: UInt16, _ capsStatus: UInt8) -> Bool {
        if data == KEY_QUOTE { return true }
        if data == KEY_LEFT_BRACKET || data == KEY_RIGHT_BRACKET { return true }
        if capsStatus == 1 && (data == KEY_9 || data == KEY_0) { return true }
        return false
    }

    func isEnglishLetterKeyCode(_ keyCode: UInt16) -> Bool {
        switch keyCode {
        case KEY_A, KEY_B, KEY_C, KEY_D, KEY_E, KEY_F, KEY_G, KEY_H, KEY_I, KEY_J,
             KEY_K, KEY_L, KEY_M, KEY_N, KEY_O, KEY_P, KEY_Q, KEY_R, KEY_S, KEY_T,
             KEY_U, KEY_V, KEY_W, KEY_X, KEY_Y, KEY_Z: return true
        default: return false
        }
    }

    func isDigitKeyCode(_ keyCode: UInt16) -> Bool {
        switch keyCode {
        case KEY_0, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9: return true
        default: return false
        }
    }

    func getEnglishLookupStateLength() -> Int {
        var lookupLen = stateIdx
        while lookupLen > 0 {
            let kc = UInt16(keyStates[lookupLen - 1] & UInt32(CHAR_MASK))
            if isEnglishLetterKeyCode(kc) { break }
            lookupLen -= 1
        }
        return lookupLen
    }

    func hasOnlyTrailingDigitKeyStates(_ startIndex: Int) -> Bool {
        guard startIndex >= 0 && startIndex < stateIdx else { return false }
        for idx2 in startIndex..<stateIdx {
            if !isDigitKeyCode(UInt16(keyStates[idx2] & UInt32(CHAR_MASK))) { return false }
        }
        return true
    }

    func hasOnlyEnglishLetterKeyStates(_ length: Int) -> Bool {
        guard length > 0 else { return false }
        for idx2 in 0..<length {
            if !isEnglishLetterKeyCode(UInt16(keyStates[idx2] & UInt32(CHAR_MASK))) { return false }
        }
        return true
    }

    func hasVietnameseTransformsInTypingWord(_ length: Int) -> Bool {
        guard length > 0 else { return false }
        for idx2 in 0..<min(length, ENGINE_MAX_BUFF) {
            if (typingWord[idx2] & (MARK_MASK | TONE_MASK | TONEW_MASK | STANDALONE_MASK)) != 0 { return true }
        }
        return false
    }

    func shouldSuppressAutoRestoreForVietnameseTelexConflict(_ englishStateIndex: Int) -> Bool {
        guard englishStateIndex >= 4 else { return false }
        let keySlice = Array(keyStates.prefix(englishStateIndex))
        let token = detectorKeyStatesToString(keySlice, englishStateIndex)
        guard token.count == englishStateIndex else { return false }
        let chars = Array(token)

        let toneKeys: Set<Character> = ["s", "f", "r", "x", "j"]
        let codaKeys: Set<Character> = ["c", "k", "m", "n", "p", "t"]
        let vietnameseInitials: Set<Character> = [
            "a", "b", "c", "d", "e", "g", "h", "i", "k", "l", "m", "n",
            "o", "p", "r", "s", "t", "u", "v", "x", "y"
        ]
        let nonVietnameseStarts: Set<String> = [
            "bl", "br", "cl", "cr", "dr", "fl", "fr", "gl", "gr", "pl", "pr",
            "sc", "sk", "sl", "sm", "sn", "sp", "st", "sw", "tw", "wr"
        ]

        guard vietnameseInitials.contains(chars[0]) else { return false }
        if chars.count >= 2 {
            let first2 = String([chars[0], chars[1]])
            if nonVietnameseStarts.contains(first2) { return false }
        }

        let last = chars[chars.count - 1]
        let hasVietnameseCodaAtEnd = codaKeys.contains(last) ||
            (toneKeys.contains(last) && chars.count >= 2 && codaKeys.contains(chars[chars.count - 2]))
        guard hasVietnameseCodaAtEnd else { return false }

        var hasAWPattern = false
        for i in 0..<(chars.count - 1) {
            if chars[i] != "a" { continue }
            if chars[i + 1] == "w" {
                hasAWPattern = true
                break
            }
            if i + 2 < chars.count && toneKeys.contains(chars[i + 1]) && chars[i + 2] == "w" {
                hasAWPattern = true
                break
            }
        }

        return hasAWPattern
    }

    // MARK: - English mode (EngineEnglishMode.inc)

    func vEnglishMode(state: VKeyEventState, data: UInt16, isCaps: Bool, otherControlKey: Bool) {
        refreshRuntimeLayoutSnapshot()
        hCode = HookCodeState.doNothing.rawValue
        if state == .mouseDown || (otherControlKey && !isCaps) {
            hMacroKey.removeAll(); hasHandledMacro = false; willTempOffEngine = false
        } else if data == KEY_SPACE || isMacroBreakCode(data) {
            if !hasHandledMacro && findMacro(&hMacroKey, &hMacroData) {
                hCode = HookCodeState.replaceMacro.rawValue
                hBPC = hMacroKey.count
            }
            hMacroKey.removeAll(); hasHandledMacro = false; willTempOffEngine = false
        } else if data == KEY_DELETE {
            if !hMacroKey.isEmpty { hMacroKey.removeLast() } else { willTempOffEngine = false }
        } else {
            if isWordBreak(event: .keyboard, state: state, data: data) && !kCharKeyCode.contains(data) {
                hMacroKey.removeAll(); hasHandledMacro = false; willTempOffEngine = false
            } else {
                if !willTempOffEngine { hMacroKey.append(UInt32(data) | (isCaps ? CAPS_MASK : 0)) }
            }
        }
    }

    // MARK: - Main key handle event (EngineKeyHandleEvent.inc)

    func vKeyHandleEvent(event: VKeyEvent, state: VKeyEventState, data: UInt16, capsStatus: UInt8, otherControlKey: Bool) {
        refreshRuntimeLayoutSnapshot()
        if phtvRuntimeRestoreOnEscapeEnabled() != 0 && idx > 0 && data == KEY_ESC {
            if restoreToRawKeys() { return }
        }

        isCaps = (capsStatus == 1 || capsStatus == 2)
        let isAutoRestoreBreakKey = isAutoRestoreWordBreak(event: event, state: state, data: data, capsStatus: capsStatus)
        // Brackets trigger auto-restore only when there are more than 2 trailing English
        // letters in keyStates. getEnglishLookupStateLength() stops counting at any non-letter
        // key (including a previous bracket), so:
        //   - ph] → phư:  getEnglishLookupStateLength=2, not >2 → handleMainFlow ✓
        //   - phư[→ phươ: last keyState is KEY_RIGHT_BRACKET (not a letter) → returns 2, not >2 → handleMainFlow ✓
        //   - ][ → ươ:    last keyState is KEY_RIGHT_BRACKET → returns 0, not >2 → handleMainFlow ✓
        //   - terminal[ → auto-restore: returns 8 >2 → handleWordBreak ✓
        let isBracketAutoRestore = isBracketPunctuationBreak(data) && getEnglishLookupStateLength() > 2

        if (isNumberKey(data) && capsStatus == 1) || otherControlKey || isAutoRestoreBreakKey || isBracketAutoRestore || (idx == 0 && isNumberKey(data)) {
            handleWordBreak(event: event, state: state, data: data, capsStatus: capsStatus, otherControlKey: otherControlKey, isAutoRestoreBreakKey: isAutoRestoreBreakKey || isBracketAutoRestore)
        } else if data == KEY_SPACE {
            handleSpace(state: state, data: data)
        } else if data == KEY_DELETE {
            handleDelete()
        } else {
            handleMainFlow(state: state, data: data, otherControlKey: otherControlKey)
        }
    }

    // MARK: - Word break handler

    func handleWordBreak(event: VKeyEvent, state: VKeyEventState, data: UInt16, capsStatus: UInt8, otherControlKey: Bool, isAutoRestoreBreakKey: Bool) {
        hCode = HookCodeState.doNothing.rawValue
        hBPC = 0; hNCC = 0; hExt = 1

        if phtvRuntimeUseMacroEnabled() != 0 && isMacroBreakCode(data) && !hasHandledMacro && findMacro(&hMacroKey, &hMacroData) {
            hCode = HookCodeState.replaceMacro.rawValue
            hBPC = hMacroKey.count
            hasHandledMacro = true
        } else if phtvRuntimeAutoRestoreEnglishWordEnabled() != 0 && isAutoRestoreBreakKey {
            if isSpellCheckingEnabled() { checkSpelling(forceCheckVowel: true) }
            var shouldRestoreEnglish = false
            var suppressVietnameseTelexRestore = false
            let englishStateIndex = getEnglishLookupStateLength()
            let isPureLetter = englishStateIndex == stateIdx && hasOnlyEnglishLetterKeyStates(stateIdx)
            let isWithNumSuffix = englishStateIndex > 0 && englishStateIndex < stateIdx &&
                hasOnlyEnglishLetterKeyStates(englishStateIndex) &&
                hasOnlyTrailingDigitKeyStates(englishStateIndex)
            let canAutoRestore = isPureLetter || isWithNumSuffix
            let restoreStateIndex = isWithNumSuffix ? stateIdx : englishStateIndex
            let shouldSuppressVietnameseTelexConflict =
                englishStateIndex > 1 && shouldSuppressAutoRestoreForVietnameseTelexConflict(englishStateIndex)

            if englishStateIndex > 1 && canAutoRestore {
                let keySlice = Array(keyStates.prefix(englishStateIndex))
                shouldRestoreEnglish = detectorShouldRestoreEnglish(keySlice, englishStateIndex)
                if !shouldRestoreEnglish {
                    if detectorIsEnglishWord(keySlice, englishStateIndex) &&
                       !detectorIsVietnameseWord(keySlice, englishStateIndex) &&
                       !isVietnameseWordFromTypingWord(idx) {
                        shouldRestoreEnglish = true
                    }
                }
                if shouldRestoreEnglish && idx == 1 {
                    if (typingWord[0] & (MARK_MASK | TONE_MASK | TONEW_MASK | STANDALONE_MASK)) != 0 {
                        shouldRestoreEnglish = false
                    }
                }
                if shouldRestoreEnglish {
                    var hasVietnameseMarks = false
                    for k2 in 0..<idx where (typingWord[k2] & (MARK_MASK | TONE_MASK | TONEW_MASK | STANDALONE_MASK)) != 0 {
                        hasVietnameseMarks = true; break
                    }
                    if hasVietnameseMarks && isVietnameseFromCanonicalTelex(idx) { shouldRestoreEnglish = false }
                }
                if shouldRestoreEnglish {
                    var isPureEnglish = true
                    for k2 in 0..<idx where (typingWord[k2] & (MARK_MASK | TONE_MASK | TONEW_MASK | STANDALONE_MASK)) != 0 {
                        isPureEnglish = false; break
                    }
                    let twSlice = Array(typingWord.prefix(idx))
                    if isPureEnglish && detectorIsEnglishWord(twSlice, idx) { shouldRestoreEnglish = false }
                }
                if shouldRestoreEnglish && isWithNumSuffix && !hasVietnameseTransformsInTypingWord(idx) {
                    shouldRestoreEnglish = false
                }
                if shouldRestoreEnglish && shouldSuppressVietnameseTelexConflict {
                    shouldRestoreEnglish = false
                }
            }
            if shouldSuppressVietnameseTelexConflict {
                suppressVietnameseTelexRestore = true
            }

            if idx > 0 && restoreStateIndex > 1 && canAutoRestore && shouldRestoreEnglish {
                hCode = HookCodeState.restoreAndStartNewSession.rawValue
                hBPC = idx; hNCC = restoreStateIndex; hExt = 5
                for i in 0..<restoreStateIndex {
                    typingWord[i] = keyStates[i]
                    hData[restoreStateIndex - 1 - i] = keyStates[i]
                }
                if snapshotUpperCaseFirstChar != 0 && phtvRuntimeUpperCaseExcludedForCurrentApp() == 0 &&
                   shouldUpperCaseEnglishRestore && restoreStateIndex > 0 {
                    hData[restoreStateIndex - 1] |= CAPS_MASK
                }
                shouldUpperCaseEnglishRestore = false
                idx = 0; stateIdx = 0
            } else if tempDisableKey && !suppressVietnameseTelexRestore && phtvRuntimeRestoreIfWrongSpellingEnabled() != 0 {
                _ = checkRestoreIfWrongSpelling(HookCodeState.restoreAndStartNewSession.rawValue)
            }
        } else if (phtvRuntimeQuickStartConsonantEnabled() != 0 || phtvRuntimeQuickEndConsonantEnabled() != 0) && !tempDisableKey && isMacroBreakCode(data) {
            _ = checkQuickConsonant()
        } else if isAutoRestoreBreakKey {
            if !tempDisableKey && isSpellCheckingEnabled() { checkSpelling(forceCheckVowel: true) }
            if tempDisableKey && !(phtvRuntimeRestoreIfWrongSpellingEnabled() != 0 && checkRestoreIfWrongSpelling(HookCodeState.restoreAndStartNewSession.rawValue)) {
                hCode = HookCodeState.doNothing.rawValue
            }
        }

        // EngineKeyHandleEventWordBreakPost.inc
        isCharKeyCode = state == .keyDown && kCharKeyCode.contains(data)
        if !isCharKeyCode {
            specialChar.removeAll(); typingStates.removeAll()
        } else {
            if spaceCount > 0 { saveWord(UInt32(KEY_SPACE), spaceCount); spaceCount = 0 } else { saveWord() }
            specialChar.append(UInt32(data) | (isCaps ? CAPS_MASK : 0))
            hExt = 3
        }

        if hCode == HookCodeState.doNothing.rawValue {
            startNewSession(); setSpellCheckingEnabled(useSpellCheckingBefore); willTempOffEngine = false
        } else if hCode == HookCodeState.replaceMacro.rawValue || hasHandleQuickConsonant {
            idx = 0; hasHandledMacro = false
        }

        if phtvRuntimeUseMacroEnabled() != 0 {
            if isCharKeyCode {
                hMacroKey.append(UInt32(data) | (isCaps ? CAPS_MASK : 0))
            } else {
                hMacroKey.removeAll(); hasHandledMacro = false
            }
        }

        if snapshotUpperCaseFirstChar != 0 && phtvRuntimeUpperCaseExcludedForCurrentApp() == 0 {
            if isSentenceTerminator(data, capsStatus) {
                upperCaseStatus = 2
                upperCaseNeedsSpaceConfirm = (data != KEY_ENTER && data != KEY_RETURN)
            } else if upperCaseStatus > 0 && isUppercaseSkippablePunctuation(data, capsStatus) {
                // Keep pending
            } else {
                upperCaseStatus = 0
            }
        }
    }

    // MARK: - Space handler

    func handleSpace(state: VKeyEventState, data: UInt16) {
        if isSpellCheckingEnabled() { checkSpelling(forceCheckVowel: true) }
        var shouldRestoreEnglish = false
        var suppressVietnameseTelexRestore = false
        let englishStateIndex = getEnglishLookupStateLength()
        let isPureLetter = englishStateIndex == stateIdx && hasOnlyEnglishLetterKeyStates(stateIdx)
        let isWithNumSuffix = englishStateIndex > 0 && englishStateIndex < stateIdx &&
            hasOnlyEnglishLetterKeyStates(englishStateIndex) &&
            hasOnlyTrailingDigitKeyStates(englishStateIndex)
        let canAutoRestore = isPureLetter || isWithNumSuffix
        let restoreStateIndex = isWithNumSuffix ? stateIdx : englishStateIndex
        let shouldSuppressVietnameseTelexConflict =
            englishStateIndex > 1 && shouldSuppressAutoRestoreForVietnameseTelexConflict(englishStateIndex)

        if phtvRuntimeAutoRestoreEnglishWordEnabled() != 0 && idx > 0 && englishStateIndex > 1 && canAutoRestore {
            let keySlice = Array(keyStates.prefix(englishStateIndex))
            shouldRestoreEnglish = detectorShouldRestoreEnglish(keySlice, englishStateIndex)
            if !shouldRestoreEnglish {
                if detectorIsEnglishWord(keySlice, englishStateIndex) &&
                   !detectorIsVietnameseWord(keySlice, englishStateIndex) &&
                   !isVietnameseWordFromTypingWord(idx) { shouldRestoreEnglish = true }
            }
            if shouldRestoreEnglish && idx == 1 {
                if (typingWord[0] & (MARK_MASK | TONE_MASK | TONEW_MASK | STANDALONE_MASK)) != 0 { shouldRestoreEnglish = false }
            }
            if shouldRestoreEnglish {
                var hasVietnameseMarks = false
                for k2 in 0..<idx where (typingWord[k2] & (MARK_MASK | TONE_MASK | TONEW_MASK | STANDALONE_MASK)) != 0 {
                    hasVietnameseMarks = true; break
                }
                if hasVietnameseMarks && isVietnameseFromCanonicalTelex(idx) { shouldRestoreEnglish = false }
            }
            if shouldRestoreEnglish {
                var isPureEnglish = true
                for k2 in 0..<idx where (typingWord[k2] & (MARK_MASK | TONE_MASK | TONEW_MASK | STANDALONE_MASK)) != 0 {
                    isPureEnglish = false; break
                }
                let twSlice = Array(typingWord.prefix(idx))
                if isPureEnglish && detectorIsEnglishWord(twSlice, idx) { shouldRestoreEnglish = false }
            }
            if shouldRestoreEnglish && isWithNumSuffix && !hasVietnameseTransformsInTypingWord(idx) {
                shouldRestoreEnglish = false
            }
            if shouldRestoreEnglish && shouldSuppressVietnameseTelexConflict {
                shouldRestoreEnglish = false
            }
        }
        if shouldSuppressVietnameseTelexConflict {
            suppressVietnameseTelexRestore = true
        }

        // EngineKeyHandleEventSpaceDecision.inc
        if phtvRuntimeUseMacroEnabled() != 0 && !hasHandledMacro && findMacro(&hMacroKey, &hMacroData) {
            hCode = HookCodeState.replaceMacro.rawValue
            hBPC = hMacroKey.count; spaceCount += 1
        } else if phtvRuntimeAutoRestoreEnglishWordEnabled() != 0 && idx > 0 && restoreStateIndex > 1 && canAutoRestore && shouldRestoreEnglish {
            hCode = HookCodeState.restore.rawValue
            hBPC = idx; hNCC = restoreStateIndex; hExt = 5
            for i in 0..<restoreStateIndex {
                typingWord[i] = keyStates[i]
                hData[restoreStateIndex - 1 - i] = keyStates[i]
            }
            if snapshotUpperCaseFirstChar != 0 && phtvRuntimeUpperCaseExcludedForCurrentApp() == 0 &&
               shouldUpperCaseEnglishRestore && restoreStateIndex > 0 {
                hData[restoreStateIndex - 1] |= CAPS_MASK
            }
            shouldUpperCaseEnglishRestore = false
            spaceCount += 1; idx = 0; stateIdx = 0
        } else if (phtvRuntimeQuickStartConsonantEnabled() != 0 || phtvRuntimeQuickEndConsonantEnabled() != 0) && !tempDisableKey && checkQuickConsonant() {
            spaceCount += 1
        } else if tempDisableKey && !hasHandledMacro {
            if suppressVietnameseTelexRestore {
                hCode = HookCodeState.doNothing.rawValue
            } else if !(phtvRuntimeRestoreIfWrongSpellingEnabled() != 0 && checkRestoreIfWrongSpelling(HookCodeState.restore.rawValue)) {
                hCode = HookCodeState.doNothing.rawValue
            }
            spaceCount += 1
        } else {
            hCode = HookCodeState.doNothing.rawValue; spaceCount += 1
        }

        // EngineKeyHandleEventSpaceFinalize.inc
        if phtvRuntimeUseMacroEnabled() != 0 { hMacroKey.removeAll(); hasHandledMacro = false }
        if snapshotUpperCaseFirstChar != 0 && phtvRuntimeUpperCaseExcludedForCurrentApp() == 0 && upperCaseNeedsSpaceConfirm {
            upperCaseNeedsSpaceConfirm = false
        }
        if spaceCount == 1 {
            if !specialChar.isEmpty { saveSpecialChar() } else { saveWord() }
        }
        setSpellCheckingEnabled(useSpellCheckingBefore)
        willTempOffEngine = false
    }

    // MARK: - Delete handler

    func handleDelete() {
        hCode = HookCodeState.doNothing.rawValue; hExt = 2; tempDisableKey = false
        if !specialChar.isEmpty {
            specialChar.removeLast()
            if specialChar.isEmpty { restoreLastTypingState() }
        } else if spaceCount > 0 {
            spaceCount -= 1
            if spaceCount == 0 { restoreLastTypingState() }
        } else {
            if stateIdx > 0 { stateIdx -= 1 }
            if idx > 0 {
                idx -= 1
                if !longWordHelper.isEmpty {
                    for i in stride(from: ENGINE_MAX_BUFF - 1, through: 1, by: -1) { typingWord[i] = typingWord[i - 1] }
                    typingWord[0] = longWordHelper.removeLast()
                    idx += 1
                }
                if isSpellCheckingEnabled() { checkSpelling() }
            }
            if phtvRuntimeUseMacroEnabled() != 0 && !hMacroKey.isEmpty { hMacroKey.removeLast() }
            hBPC = 0; hNCC = 0; hExt = 2
            if idx == 0 {
                let savedStatus = upperCaseStatus, savedSpaceConfirm = upperCaseNeedsSpaceConfirm
                startNewSession()
                upperCaseStatus = savedStatus; upperCaseNeedsSpaceConfirm = savedSpaceConfirm
                specialChar.removeAll(); restoreLastTypingState()
            } else {
                checkGrammar(deltaBackSpace: 1)
            }
        }
    }

    // MARK: - Main flow handler

    func handleMainFlow(state: VKeyEventState, data: UInt16, otherControlKey: Bool) {
        if willTempOffEngine { hCode = HookCodeState.doNothing.rawValue; hExt = 3; return }

        if spaceCount > 0 {
            hBPC = 0; hNCC = 0; hExt = 0
            let savedSpaceCount = spaceCount
            let savedUpperCaseStatus = upperCaseStatus, savedSpaceConfirm = upperCaseNeedsSpaceConfirm
            startNewSession()
            upperCaseStatus = savedUpperCaseStatus; upperCaseNeedsSpaceConfirm = savedSpaceConfirm
            saveWord(UInt32(KEY_SPACE), savedSpaceCount)
        } else if !specialChar.isEmpty {
            saveSpecialChar()
        }

        insertState(data, isCaps)

        // Spell gate (EngineKeyHandleEventMainFlowSpellGate.inc)
        let allowMarkDespiteTempDisable = isMarkKey(data)
        var allowVowelChangeDespiteTempDisable = false
        if tempDisableKey && isSpecialKey(data) && !allowMarkDespiteTempDisable {
            if isKeyDouble(data) || isKeyW(data) || isBracketKey(data) {
                var hasToneOrDiacritic = false
                for scan in 0..<idx where (typingWord[scan] & (MARK_MASK | TONE_MASK | TONEW_MASK)) != 0 {
                    hasToneOrDiacritic = true; break
                }
                allowVowelChangeDespiteTempDisable = hasToneOrDiacritic
            }
        }
        var allowSpecialDespiteTempDisable = allowMarkDespiteTempDisable || allowVowelChangeDespiteTempDisable
        if isSpellCheckingEnabled() && allowSpecialDespiteTempDisable {
            checkSpelling(forceCheckVowel: true)
            if tempDisableKey && allowMarkDespiteTempDisable {
                var hasToneWTransform = false
                if idx > 0 {
                    for scan in 0..<idx where (typingWord[scan] & TONEW_MASK) != 0 {
                        hasToneWTransform = true
                        break
                    }
                }
                let allowToneOnInvalidVowel = spellingOK && !spellingVowelOK && canFixVowelWithDiacriticsForMark()
                let allowToneOnInvalidEndConsonant = !spellingOK && spellingVowelOK && hasToneWTransform
                let allowToneOnInvalid = allowToneOnInvalidVowel || allowToneOnInvalidEndConsonant || hasToneWTransform
                if !allowToneOnInvalid { allowSpecialDespiteTempDisable = false }
            }
        }

        // Decision (EngineKeyHandleEventMainFlowDecision.inc)
        let quickTelexEnabled = phtvRuntimeQuickTelexEnabled() != 0
        let freeMarkEnabled = phtvRuntimeFreeMarkEnabled() != 0

        if !isSpecialKey(data) || (tempDisableKey && !allowSpecialDespiteTempDisable) {
            if quickTelexEnabled && isQuickTelexKey(data) {
                handleQuickTelex(data, isCaps); return
            } else {
                hCode = HookCodeState.doNothing.rawValue; hBPC = 0; hNCC = 0; hExt = 3
                insertKey(data, isCaps)
            }
        } else {
            hCode = HookCodeState.doNothing.rawValue; hExt = 3
            handleMainKey(data, isCaps)
        }

        // Post (EngineKeyHandleEventMainFlowPost.inc)
        if !freeMarkEnabled && !isKeyD(data) {
            if hCode == HookCodeState.doNothing.rawValue { checkGrammar(deltaBackSpace: -1) } else { checkGrammar(deltaBackSpace: 0) }
        }

        if hCode == HookCodeState.restore.rawValue { insertKey(data, isCaps) }

        if phtvRuntimeUseMacroEnabled() != 0 {
            if hCode == HookCodeState.doNothing.rawValue {
                hMacroKey.append(UInt32(data) | (isCaps ? CAPS_MASK : 0))
            } else if hCode == HookCodeState.willProcess.rawValue || hCode == HookCodeState.restore.rawValue {
                for _ in 0..<hBPC where !hMacroKey.isEmpty { hMacroKey.removeLast() }
                for i in (idx - hBPC)..<(hNCC + idx - hBPC) { hMacroKey.append(typingWord[i]) }
            }
        }

        if snapshotUpperCaseFirstChar != 0 && phtvRuntimeUpperCaseExcludedForCurrentApp() == 0 {
            if idx == 1 && upperCaseStatus == 2 && !upperCaseNeedsSpaceConfirm {
                upperCaseFirstCharacter(); shouldUpperCaseEnglishRestore = true
            }
            upperCaseStatus = 0; upperCaseNeedsSpaceConfirm = false
        }

        if isBracketKey(data) && (isBracketKey(UInt16(hData[0] & CHAR_MASK)) || runtimeInputTypeSnapshot == 2 || runtimeInputTypeSnapshot == 3) {
            if idx - (hCode == HookCodeState.willProcess.rawValue ? hBPC : 0) > 0 {
                idx -= 1; saveWord()
            }
            idx = 0; tempDisableKey = false; stateIdx = 0; hExt = 3
            specialChar.append(UInt32(data) | (isCaps ? CAPS_MASK : 0))
        }
    }
}

// MARK: - Module-level singleton + lock

private final class EngineStateBox: @unchecked Sendable {
    let lock = NSLock()
    let engine = PHTVVietnameseEngine()
}

private let engineState = EngineStateBox()

private func withEngineState<T>(_ body: (PHTVVietnameseEngine) -> T) -> T {
    engineState.lock.lock()
    defer { engineState.lock.unlock() }
    return body(engineState.engine)
}

// MARK: - Public C bridge functions (called from PHTVEngineBridgeExports.swift via @_cdecl)

func engineHandleEvent(_ event: Int32, _ state: Int32, _ data: UInt16, _ capsStatus: UInt8, _ otherControlKey: Int32) {
    withEngineState { engine in
        guard let ev = VKeyEvent(rawValue: event), let st = VKeyEventState(rawValue: state) else { return }
        engine.vKeyHandleEvent(event: ev, state: st, data: data, capsStatus: capsStatus, otherControlKey: otherControlKey != 0)
    }
}

func engineHandleEnglishMode(_ state: Int32, _ data: UInt16, _ isCaps: Int32, _ otherControlKey: Int32) {
    withEngineState { engine in
        guard let st = VKeyEventState(rawValue: state) else { return }
        engine.vEnglishMode(state: st, data: data, isCaps: isCaps != 0, otherControlKey: otherControlKey != 0)
    }
}

func enginePrimeUpperCaseFirstChar() {
    withEngineState { engine in
        engine.vPrimeUpperCaseFirstChar()
    }
}

func engineRestoreToRawKeys() -> Int32 {
    withEngineState { engine in
        engine.vRestoreToRawKeys() ? 1 : 0
    }
}

func engineTempOffSpellChecking() {
    withEngineState { engine in
        engine.vTempOffSpellChecking()
    }
}

func engineTempOff(_ off: Int32) {
    withEngineState { engine in
        engine.vTempOffEngine(off != 0)
    }
}

func engineSetCheckSpelling() {
    withEngineState { engine in
        engine.vSetCheckSpelling()
    }
}

func engineStartNewSession() {
    withEngineState { engine in
        engine.startNewSession()
    }
}

func engineInitialize() {
    withEngineState { engine in
        engine.vKeyInit()
    }
}

func engineHookCode() -> Int32 {
    withEngineState { engine in
        engine.hCode
    }
}
func engineHookExtCode() -> Int32 {
    withEngineState { engine in
        engine.hExt
    }
}
func engineHookBackspaceCount() -> Int32 {
    withEngineState { engine in
        Int32(engine.hBPC)
    }
}
func engineHookSetBackspaceCount(_ count: UInt8) {
    withEngineState { engine in
        engine.hBPC = Int(count)
    }
}
func engineHookNewCharCount() -> Int32 {
    withEngineState { engine in
        Int32(engine.hNCC)
    }
}
func engineHookCharAt(_ index: Int32) -> UInt32 {
    withEngineState { engine in
        guard index >= 0 && Int(index) < ENGINE_MAX_BUFF else { return 0 }
        return engine.hData[Int(index)]
    }
}
func engineHookMacroDataSize() -> Int32 {
    withEngineState { engine in
        Int32(engine.hMacroData.count)
    }
}
func engineHookMacroDataAt(_ index: Int32) -> UInt32 {
    withEngineState { engine in
        guard index >= 0 && Int(index) < engine.hMacroData.count else { return 0 }
        return engine.hMacroData[Int(index)]
    }
}
