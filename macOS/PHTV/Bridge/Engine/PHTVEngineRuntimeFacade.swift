//
//  PHTVEngineRuntimeFacade.swift
//  PHTV
//
//  Swift facade over C++ interop runtime/engine functions.
//

import Foundation

private let macroLookupLock = NSLock()

private struct MacroLookupEntry {
    let snippetType: Int32
    let snippetFormat: String
    let staticContentCode: [UInt32]
}

nonisolated(unsafe) private var macroLookupMap: [[UInt32]: MacroLookupEntry] = [:]
nonisolated(unsafe) private var runtimeInputType: Int32 = 0
nonisolated(unsafe) private var runtimeCodeTable: Int32 = 0
nonisolated(unsafe) private var runtimeLanguage: Int32 = 1
nonisolated(unsafe) private var runtimeSwitchKeyStatus: Int32 = Int32(Defaults.defaultSwitchKeyStatus)
nonisolated(unsafe) private var runtimeFixRecommendBrowser: Int32 = 1
nonisolated(unsafe) private var runtimeUseMacro: Int32 = 1
nonisolated(unsafe) private var runtimeUseMacroInEnglishMode: Int32 = 0
nonisolated(unsafe) private var runtimeUseSmartSwitchKey: Int32 = 1
nonisolated(unsafe) private var runtimeAutoCapsMacro: Int32 = 0
nonisolated(unsafe) private var runtimeCheckSpelling: Int32 = 1
nonisolated(unsafe) private var runtimeUseModernOrthography: Int32 = 1
nonisolated(unsafe) private var runtimeQuickTelex: Int32 = 0
nonisolated(unsafe) private var runtimeFreeMark: Int32 = 0
nonisolated(unsafe) private var runtimeAllowConsonantZFWJ: Int32 = 1
nonisolated(unsafe) private var runtimeQuickStartConsonant: Int32 = 0
nonisolated(unsafe) private var runtimeQuickEndConsonant: Int32 = 0
nonisolated(unsafe) private var runtimeUpperCaseFirstChar: Int32 = 0
nonisolated(unsafe) private var runtimeUpperCaseExcludedForCurrentApp: Int32 = 0
nonisolated(unsafe) private var runtimeRememberCode: Int32 = 1
nonisolated(unsafe) private var runtimeOtherLanguage: Int32 = 1
nonisolated(unsafe) private var runtimeTempOffSpelling: Int32 = 0
nonisolated(unsafe) private var runtimeTempOffEngine: Int32 = 0
nonisolated(unsafe) private var runtimeRestoreOnEscape: Int32 = 1
nonisolated(unsafe) private var runtimeAutoRestoreEnglishWord: Int32 = 1
nonisolated(unsafe) private var runtimeCustomEscapeKey: Int32 = 0
nonisolated(unsafe) private var runtimePauseKeyEnabled: Int32 = 0
nonisolated(unsafe) private var runtimePauseKey: Int32 = Int32(KeyCode.leftOption)
nonisolated(unsafe) private var runtimeSendKeyStepByStep: Int32 = 0
nonisolated(unsafe) private var runtimeEnableEmojiHotkey: Int32 = 1
nonisolated(unsafe) private var runtimeEmojiHotkeyModifiers: Int32 = 1 << 20
nonisolated(unsafe) private var runtimeEmojiHotkeyKeyCode: Int32 = Int32(KeyCode.eKey)
nonisolated(unsafe) private var runtimeShowIconOnDock: Int32 = 0
nonisolated(unsafe) private var runtimePerformLayoutCompat: Int32 = 0
nonisolated(unsafe) private var runtimeSafeMode: Int32 = 0
private let macroCharacterToKeyState: [UInt16: UInt32] = {
    var mapping: [UInt16: UInt32] = [:]
    let capsMask = EngineBitMask.caps

    for rawKeyCode: UInt32 in 0..<256 {
        let unshifted = EngineMacroKeyMap.character(for: rawKeyCode)
        if unshifted != 0 && mapping[unshifted] == nil {
            mapping[unshifted] = rawKeyCode
        }

        let shiftedKeyCode = rawKeyCode | capsMask
        let shifted = EngineMacroKeyMap.character(for: shiftedKeyCode)
        if shifted != 0 && mapping[shifted] == nil {
            mapping[shifted] = shiftedKeyCode
        }
    }

    return mapping
}()

private func caseTransformedScalar(_ character: UInt16, upper: Bool) -> UInt16 {
    guard let scalar = UnicodeScalar(Int(character)) else {
        return character
    }
    let transformed = upper ? String(scalar).uppercased() : String(scalar).lowercased()
    guard transformed.utf16.count == 1, let value = transformed.utf16.first else {
        return character
    }
    return value
}

private func convertedMacroCodes(from text: String, activeCodeTable: Int32) -> [UInt32] {
    guard !text.isEmpty else {
        return []
    }

    let charCodeMask = EngineBitMask.charCode
    let pureCharacterMask = EngineBitMask.pureCharacter
    var converted: [UInt32] = []
    converted.reserveCapacity(text.unicodeScalars.count)

    for scalar in text.unicodeScalars {
        let scalarValue = scalar.value
        if scalarValue <= UInt32(UInt16.max) {
            let character = UInt16(scalarValue)

            if let keyState = macroCharacterToKeyState[character] {
                converted.append(keyState)
                continue
            }

            if let source = EngineCodeTableLookup.findSourceKey(
                codeTable: 0,
                character: character
            ),
               let mappedCharacter = EngineCodeTableLookup.characterForKey(
                   codeTable: activeCodeTable,
                   keyCode: source.keyCode,
                   variantIndex: source.variantIndex
               ) {
                converted.append(UInt32(mappedCharacter) | charCodeMask)
                continue
            }
        }

        converted.append(scalarValue | pureCharacterMask)
    }

    return converted
}

private func readUInt16LE(from data: UnsafePointer<UInt8>, cursor: inout Int, size: Int) -> UInt16? {
    guard cursor + 2 <= size else {
        return nil
    }
    let value = UInt16(data[cursor]) | (UInt16(data[cursor + 1]) << 8)
    cursor += 2
    return value
}

private func macroMapFromBinaryData(_ data: UnsafePointer<UInt8>, size: Int) -> [[UInt32]: MacroLookupEntry] {
    guard size >= 2 else {
        return [:]
    }

    let activeCodeTable = PHTVEngineRuntimeFacade.currentCodeTable()
    var result: [[UInt32]: MacroLookupEntry] = [:]
    var cursor = 0
    guard let macroCountRaw = readUInt16LE(from: data, cursor: &cursor, size: size) else {
        return [:]
    }

    let macroCount = Int(macroCountRaw)
    for _ in 0..<macroCount {
        guard cursor < size else {
            break
        }

        let textLength = Int(data[cursor])
        cursor += 1
        guard cursor + textLength <= size else {
            break
        }
        let macroText = String(
            decoding: UnsafeBufferPointer(start: data.advanced(by: cursor), count: textLength),
            as: UTF8.self
        )
        cursor += textLength

        guard let contentLengthRaw = readUInt16LE(from: data, cursor: &cursor, size: size) else {
            break
        }
        let contentLength = Int(contentLengthRaw)
        guard cursor + contentLength <= size else {
            break
        }
        let macroContent = String(
            decoding: UnsafeBufferPointer(start: data.advanced(by: cursor), count: contentLength),
            as: UTF8.self
        )
        cursor += contentLength

        let snippetType: Int32
        if cursor < size {
            snippetType = Int32(data[cursor])
            cursor += 1
        } else {
            snippetType = EngineMacroSnippetType.staticContent
        }

        let key = convertedMacroCodes(
            from: macroText,
            activeCodeTable: activeCodeTable
        )
        guard !key.isEmpty else {
            continue
        }

        let staticContentCode: [UInt32]
        if snippetType == EngineMacroSnippetType.staticContent {
            staticContentCode = convertedMacroCodes(
                from: macroContent,
                activeCodeTable: activeCodeTable
            )
        } else {
            staticContentCode = []
        }

        result[key] = MacroLookupEntry(
            snippetType: snippetType,
            snippetFormat: macroContent,
            staticContentCode: staticContentCode
        )
    }

    return result
}

private func lowercasedMacroLookupCode(_ code: UInt32, codeTable: Int32) -> UInt32? {
    let charCodeMask = EngineBitMask.charCode
    let capsMask = EngineBitMask.caps

    if (code & charCodeMask) == 0 {
        let lowered = code & ~capsMask
        return lowered == code ? nil : lowered
    }

    let character = UInt16(truncatingIfNeeded: code)
    guard let source = EngineCodeTableLookup.findSourceKey(
        codeTable: codeTable,
        character: character
    ) else {
        return nil
    }

    let variantIndex = source.variantIndex
    guard variantIndex % 2 == 0 else {
        return nil
    }
    let loweredVariantIndex = variantIndex + 1
    guard loweredVariantIndex < EngineCodeTableLookup.variantCount(
        codeTable: codeTable,
        keyCode: source.keyCode
    ),
    let loweredCharacter = EngineCodeTableLookup.characterForKey(
        codeTable: codeTable,
        keyCode: source.keyCode,
        variantIndex: loweredVariantIndex
    ) else {
        return nil
    }
    return UInt32(loweredCharacter) | charCodeMask
}

private func uppercasedMacroOutputCode(_ code: UInt32, codeTable: Int32) -> UInt32 {
    let charCodeMask = EngineBitMask.charCode

    let keyCharacter = EngineMacroKeyMap.character(for: code)
    if keyCharacter != 0 {
        let upperCharacter = caseTransformedScalar(keyCharacter, upper: true)
        if let mappedKeyState = macroCharacterToKeyState[upperCharacter] {
            return mappedKeyState
        }
    }

    guard (code & charCodeMask) != 0 else {
        return code
    }

    let character = UInt16(truncatingIfNeeded: code)
    guard let source = EngineCodeTableLookup.findSourceKey(
        codeTable: codeTable,
        character: character
    ) else {
        return code
    }

    let variantIndex = source.variantIndex
    guard variantIndex % 2 != 0 else {
        return code
    }
    let upperVariantIndex = variantIndex - 1
    guard upperVariantIndex >= 0,
          let upperCharacter = EngineCodeTableLookup.characterForKey(
              codeTable: codeTable,
              keyCode: source.keyCode,
              variantIndex: upperVariantIndex
          ) else {
        return code
    }
    return UInt32(upperCharacter) | charCodeMask
}

private func macroContentCode(
    for entry: MacroLookupEntry,
    codeTable: Int32
) -> [UInt32] {
    if entry.snippetType == EngineMacroSnippetType.staticContent {
        return entry.staticContentCode
    }
    if entry.snippetType == EngineMacroSnippetType.clipboard {
        return []
    }

    let dynamicContent = EngineMacroSnippetRuntime.content(
        snippetType: entry.snippetType,
        format: entry.snippetFormat
    )
    return convertedMacroCodes(from: dynamicContent, activeCodeTable: codeTable)
}

private func applyAutoCapsToMacroContent(
    _ content: [UInt32],
    allCaps: Bool,
    codeTable: Int32
) -> [UInt32] {
    guard !content.isEmpty else {
        return content
    }

    var output = content
    for index in output.indices {
        if index == 0 || allCaps {
            output[index] = uppercasedMacroOutputCode(output[index], codeTable: codeTable)
        }
    }
    return output
}

private func findMacroContentForNormalizedKeys(
    _ keys: [UInt32],
    autoCapsEnabled: Bool,
    codeTable: Int32
) -> [UInt32]? {
    macroLookupLock.lock()
    defer {
        macroLookupLock.unlock()
    }

    if let directEntry = macroLookupMap[keys] {
        return macroContentCode(for: directEntry, codeTable: codeTable)
    }

    guard autoCapsEnabled, !keys.isEmpty else {
        return nil
    }

    var candidate = keys
    guard let firstLowerCode = lowercasedMacroLookupCode(candidate[0], codeTable: codeTable) else {
        return nil
    }
    candidate[0] = firstLowerCode

    var allCaps = false
    if candidate.count > 1,
       let secondLowerCode = lowercasedMacroLookupCode(candidate[1], codeTable: codeTable) {
        candidate[1] = secondLowerCode
        allCaps = true
        if candidate.count > 2 {
            for index in 2..<candidate.count {
                if let lowered = lowercasedMacroLookupCode(candidate[index], codeTable: codeTable) {
                    candidate[index] = lowered
                }
            }
        }
    }

    guard let entry = macroLookupMap[candidate] else {
        return nil
    }
    let baseContent = macroContentCode(for: entry, codeTable: codeTable)
    return applyAutoCapsToMacroContent(baseContent, allCaps: allCaps, codeTable: codeTable)
}

@_cdecl("phtvLoadMacroMapFromBinary")
func phtvLoadMacroMapFromBinary(
    _ data: UnsafePointer<UInt8>?,
    _ size: Int32
) {
    guard let data, size > 0 else {
        macroLookupLock.lock()
        macroLookupMap = [:]
        macroLookupLock.unlock()
        return
    }

    let parsedMap = macroMapFromBinaryData(data, size: Int(size))
    macroLookupLock.lock()
    macroLookupMap = parsedMap
    macroLookupLock.unlock()
}

@_cdecl("phtvFindMacroContentForNormalizedKeys")
func phtvFindMacroContentForNormalizedKeys(
    _ normalizedKeyBuffer: UnsafePointer<UInt32>?,
    _ keyCount: Int32,
    _ autoCapsEnabled: Int32,
    _ outputBuffer: UnsafeMutablePointer<UInt32>?,
    _ outputCapacity: Int32
) -> Int32 {
    guard keyCount >= 0 else {
        return -1
    }

    let keys: [UInt32]
    if keyCount == 0 {
        keys = []
    } else {
        guard let normalizedKeyBuffer else {
            return -1
        }
        keys = Array(
            UnsafeBufferPointer(
                start: normalizedKeyBuffer,
                count: Int(keyCount)
            )
        )
    }
    let codeTable = PHTVEngineRuntimeFacade.currentCodeTable()
    guard let content = findMacroContentForNormalizedKeys(
        keys,
        autoCapsEnabled: autoCapsEnabled != 0,
        codeTable: codeTable
    ) else {
        return -1
    }

    let requiredLength = Int32(content.count)
    guard let outputBuffer, outputCapacity > 0 else {
        return requiredLength
    }

    let copiedLength = min(Int(outputCapacity), content.count)
    if copiedLength > 0 {
        for index in 0..<copiedLength {
            outputBuffer[index] = content[index]
        }
    }

    return requiredLength
}

@_cdecl("phtvRuntimeRestoreOnEscapeEnabled")
func phtvRuntimeRestoreOnEscapeEnabled() -> Int32 {
    runtimeRestoreOnEscape
}

@_cdecl("phtvRuntimeAutoCapsMacroValue")
func phtvRuntimeAutoCapsMacroValue() -> Int32 {
    runtimeAutoCapsMacro
}

@_cdecl("phtvRuntimeAutoRestoreEnglishWordEnabled")
func phtvRuntimeAutoRestoreEnglishWordEnabled() -> Int32 {
    runtimeAutoRestoreEnglishWord
}

@_cdecl("phtvRuntimeUpperCaseFirstCharEnabled")
func phtvRuntimeUpperCaseFirstCharEnabled() -> Int32 {
    runtimeUpperCaseFirstChar
}

@_cdecl("phtvRuntimeUpperCaseExcludedForCurrentApp")
func phtvRuntimeUpperCaseExcludedForCurrentApp() -> Int32 {
    runtimeUpperCaseExcludedForCurrentApp
}

@_cdecl("phtvRuntimeUseMacroEnabled")
func phtvRuntimeUseMacroEnabled() -> Int32 {
    runtimeUseMacro
}

@_cdecl("phtvRuntimeInputTypeValue")
func phtvRuntimeInputTypeValue() -> Int32 {
    runtimeInputType
}

@_cdecl("phtvRuntimeCodeTableValue")
func phtvRuntimeCodeTableValue() -> Int32 {
    runtimeCodeTable
}

@_cdecl("phtvRuntimeCheckSpellingValue")
func phtvRuntimeCheckSpellingValue() -> Int32 {
    runtimeCheckSpelling
}

@_cdecl("phtvRuntimeSetCheckSpellingValue")
func phtvRuntimeSetCheckSpellingValue(_ value: Int32) {
    runtimeCheckSpelling = value
    OSMemoryBarrier()
}

@_cdecl("phtvRuntimeUseModernOrthographyEnabled")
func phtvRuntimeUseModernOrthographyEnabled() -> Int32 {
    runtimeUseModernOrthography
}

@_cdecl("phtvRuntimeQuickTelexEnabled")
func phtvRuntimeQuickTelexEnabled() -> Int32 {
    runtimeQuickTelex
}

@_cdecl("phtvRuntimeFreeMarkEnabled")
func phtvRuntimeFreeMarkEnabled() -> Int32 {
    runtimeFreeMark
}

@_cdecl("phtvRuntimeAllowConsonantZFWJEnabled")
func phtvRuntimeAllowConsonantZFWJEnabled() -> Int32 {
    runtimeAllowConsonantZFWJ
}

@_cdecl("phtvRuntimeQuickStartConsonantEnabled")
func phtvRuntimeQuickStartConsonantEnabled() -> Int32 {
    runtimeQuickStartConsonant
}

@_cdecl("phtvRuntimeQuickEndConsonantEnabled")
func phtvRuntimeQuickEndConsonantEnabled() -> Int32 {
    runtimeQuickEndConsonant
}

@objcMembers
final class PHTVEngineRuntimeFacade: NSObject {
    @objc class func initializeAndGetKeyHookState() {
        phtvEngineInitialize()
    }

    class func safeModeEnabled() -> Bool {
        runtimeSafeMode != 0
    }

    class func rememberCode() -> Int32 {
        runtimeRememberCode
    }

    class func setRememberCode(_ value: Int32) {
        runtimeRememberCode = value
        OSMemoryBarrier()
    }

    class func currentLanguage() -> Int32 {
        runtimeLanguage
    }

    class func setCurrentLanguage(_ language: Int32) {
        runtimeLanguage = language
        OSMemoryBarrier()
    }

    class func otherLanguageMode() -> Int32 {
        runtimeOtherLanguage
    }

    class func setOtherLanguageMode(_ value: Int32) {
        runtimeOtherLanguage = value
        OSMemoryBarrier()
    }

    class func currentInputType() -> Int32 {
        runtimeInputType
    }

    class func setCurrentInputType(_ inputType: Int32) {
        runtimeInputType = inputType
        OSMemoryBarrier()
    }

    class func currentCodeTable() -> Int32 {
        runtimeCodeTable
    }

    class func setCurrentCodeTable(_ codeTable: Int32) {
        runtimeCodeTable = codeTable
        OSMemoryBarrier()
    }

    class func isSmartSwitchKeyEnabled() -> Bool {
        runtimeUseSmartSwitchKey != 0
    }

    class func setSmartSwitchKeyEnabled(_ enabled: Bool) {
        runtimeUseSmartSwitchKey = enabled ? 1 : 0
        OSMemoryBarrier()
    }

    class func isSendKeyStepByStepEnabled() -> Bool {
        runtimeSendKeyStepByStep != 0
    }

    class func setSendKeyStepByStepEnabled(_ enabled: Bool) {
        runtimeSendKeyStepByStep = enabled ? 1 : 0
        OSMemoryBarrier()
    }

    class func setUpperCaseExcludedForCurrentApp(_ excluded: Bool) {
        runtimeUpperCaseExcludedForCurrentApp = excluded ? 1 : 0
    }

    class func switchKeyStatus() -> Int32 {
        runtimeSwitchKeyStatus
    }

    class func setSwitchKeyStatus(_ status: Int32) {
        runtimeSwitchKeyStatus = status
        OSMemoryBarrier()
    }

    class func setShowIconOnDock(_ visible: Bool) {
        runtimeShowIconOnDock = visible ? 1 : 0
        OSMemoryBarrier()
    }

    class func showIconOnDock() -> Int32 {
        runtimeShowIconOnDock
    }

    class func upperCaseFirstChar() -> Int32 {
        runtimeUpperCaseFirstChar
    }

    class func setUpperCaseFirstChar(_ value: Int32) {
        runtimeUpperCaseFirstChar = value
        OSMemoryBarrier()
    }

    class func upperCaseExcludedForCurrentApp() -> Int32 {
        runtimeUpperCaseExcludedForCurrentApp
    }

    class func checkSpelling() -> Int32 {
        runtimeCheckSpelling
    }

    class func setCheckSpelling(_ value: Int32) {
        runtimeCheckSpelling = value
        OSMemoryBarrier()
    }

    class func useModernOrthography() -> Int32 {
        runtimeUseModernOrthography
    }

    class func setUseModernOrthography(_ value: Int32) {
        runtimeUseModernOrthography = value
        OSMemoryBarrier()
    }

    class func quickTelex() -> Int32 {
        runtimeQuickTelex
    }

    class func setQuickTelex(_ value: Int32) {
        runtimeQuickTelex = value
        OSMemoryBarrier()
    }

    class func freeMark() -> Int32 {
        runtimeFreeMark
    }

    class func setFreeMark(_ value: Int32) {
        runtimeFreeMark = value
        OSMemoryBarrier()
    }

    class func useMacro() -> Int32 {
        runtimeUseMacro
    }

    class func setUseMacro(_ value: Int32) {
        runtimeUseMacro = value
        OSMemoryBarrier()
    }

    class func useMacroInEnglishMode() -> Int32 {
        runtimeUseMacroInEnglishMode
    }

    class func setUseMacroInEnglishMode(_ value: Int32) {
        runtimeUseMacroInEnglishMode = value
        OSMemoryBarrier()
    }

    class func autoCapsMacro() -> Int32 {
        runtimeAutoCapsMacro
    }

    class func setAutoCapsMacro(_ value: Int32) {
        runtimeAutoCapsMacro = value
        OSMemoryBarrier()
    }

    class func allowConsonantZFWJ() -> Int32 {
        runtimeAllowConsonantZFWJ
    }

    class func setAllowConsonantZFWJ(_ value: Int32) {
        runtimeAllowConsonantZFWJ = value
        OSMemoryBarrier()
    }

    class func quickStartConsonant() -> Int32 {
        runtimeQuickStartConsonant
    }

    class func setQuickStartConsonant(_ value: Int32) {
        runtimeQuickStartConsonant = value
        OSMemoryBarrier()
    }

    class func quickEndConsonant() -> Int32 {
        runtimeQuickEndConsonant
    }

    class func setQuickEndConsonant(_ value: Int32) {
        runtimeQuickEndConsonant = value
        OSMemoryBarrier()
    }

    class func performLayoutCompat() -> Int32 {
        runtimePerformLayoutCompat
    }

    class func setPerformLayoutCompat(_ value: Int32) {
        runtimePerformLayoutCompat = value
        OSMemoryBarrier()
    }

    class func restoreOnEscape() -> Int32 {
        runtimeRestoreOnEscape
    }

    class func setRestoreOnEscape(_ value: Int32) {
        runtimeRestoreOnEscape = value
        OSMemoryBarrier()
    }

    class func customEscapeKey() -> Int32 {
        runtimeCustomEscapeKey
    }

    class func setCustomEscapeKey(_ value: Int32) {
        runtimeCustomEscapeKey = value
        OSMemoryBarrier()
    }

    class func pauseKeyEnabled() -> Int32 {
        runtimePauseKeyEnabled
    }

    class func setPauseKeyEnabled(_ value: Int32) {
        runtimePauseKeyEnabled = value
        OSMemoryBarrier()
    }

    class func pauseKey() -> Int32 {
        runtimePauseKey
    }

    class func setPauseKey(_ value: Int32) {
        runtimePauseKey = value
        OSMemoryBarrier()
    }

    class func autoRestoreEnglishWord() -> Int32 {
        runtimeAutoRestoreEnglishWord
    }

    class func setAutoRestoreEnglishWord(_ value: Int32) {
        runtimeAutoRestoreEnglishWord = value
        OSMemoryBarrier()
    }

    class func enableEmojiHotkey() -> Int32 {
        runtimeEnableEmojiHotkey
    }

    class func emojiHotkeyModifiers() -> Int32 {
        runtimeEmojiHotkeyModifiers
    }

    class func emojiHotkeyKeyCode() -> Int32 {
        runtimeEmojiHotkeyKeyCode
    }

    class func setEmojiHotkeySettings(_ enabled: Int32, _ modifiers: Int32, _ keyCode: Int32) {
        runtimeEnableEmojiHotkey = enabled
        runtimeEmojiHotkeyModifiers = modifiers
        runtimeEmojiHotkeyKeyCode = keyCode
        OSMemoryBarrier()
    }

    class func setFixRecommendBrowser(_ value: Int32) {
        runtimeFixRecommendBrowser = value
        OSMemoryBarrier()
    }

    class func setTempOffSpelling(_ value: Int32) {
        runtimeTempOffSpelling = value
        OSMemoryBarrier()
    }

    class func setTempOffEngine(_ value: Int32) {
        runtimeTempOffEngine = value
        OSMemoryBarrier()
    }

    class func setSafeMode(_ enabled: Bool) {
        runtimeSafeMode = enabled ? 1 : 0
        OSMemoryBarrier()
    }

    class func tempOffSpelling() -> Int32 {
        runtimeTempOffSpelling
    }

    class func tempOffEngine() -> Int32 {
        runtimeTempOffEngine
    }

    class func fixRecommendBrowser() -> Int32 {
        runtimeFixRecommendBrowser
    }

    class func engineDataCode() -> Int32 {
        Int32(phtvEngineHookCode())
    }

    class func engineDataExtCode() -> Int32 {
        Int32(phtvEngineHookExtCode())
    }

    class func engineDataBackspaceCount() -> Int32 {
        Int32(phtvEngineHookBackspaceCount())
    }

    class func setEngineDataBackspaceCount(_ count: UInt8) {
        phtvEngineHookSetBackspaceCount(count)
    }

    class func engineDataNewCharCount() -> Int32 {
        Int32(phtvEngineHookNewCharCount())
    }

    class func engineDataCharAt(_ index: Int32) -> UInt32 {
        guard index >= 0, index < EngineSignalCode.maxBuffer else {
            return 0
        }
        return phtvEngineHookCharAt(Int32(index))
    }

    class func engineDataMacroDataSize() -> Int32 {
        Int32(phtvEngineHookMacroDataSize())
    }

    class func engineDataMacroDataAt(_ index: Int32) -> UInt32 {
        guard index >= 0 else {
            return 0
        }
        return phtvEngineHookMacroDataAt(index)
    }

}
