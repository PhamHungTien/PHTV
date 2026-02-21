//
//  PHTVEngineRuntimeFacade.swift
//  PHTV
//
//  Swift facade over C++ interop runtime/engine functions.
//

import Foundation

@objcMembers
final class PHTVEngineRuntimeFacade: NSObject {
    private static let eventMarker: Int64 = 0x5048_5456 // "PHTV"
    private static let unicodeCompoundMarks: [UInt16] = [0x0301, 0x0300, 0x0309, 0x0303, 0x0323]
    // Mirror constants in Core/Engine/DataType.h.
    private static let engineCapsMask: UInt32 = 0x0001_0000
    private static let engineCharCodeMask: UInt32 = 0x0200_0000
    private static let enginePureCharacterMask: UInt32 = 0x8000_0000
    private static let engineDoNothingCodeValue: Int32 = 0
    private static let engineWillProcessCodeValue: Int32 = 1
    private static let engineRestoreCodeValue: Int32 = 3
    private static let engineReplaceMacroCodeValue: Int32 = 4
    private static let engineRestoreAndStartNewSessionCodeValue: Int32 = 5
    private static let engineMaxBufferValue: Int32 = 32
    private static let navigationKeyCodes: Set<UInt16> = [
        KeyCode.leftArrow,
        KeyCode.rightArrow,
        KeyCode.upArrow,
        KeyCode.downArrow,
        KeyCode.home,
        KeyCode.end,
        KeyCode.pageUp,
        KeyCode.pageDown
    ]
    // Mirror keyCodeToCharacter mapping in Core/Engine/Vietnamese.cpp.
    private static let macroKeyToCharacterUnshifted: [UInt16: UInt16] = [
        0: 0x0061, 11: 0x0062, 8: 0x0063, 2: 0x0064, 14: 0x0065, 3: 0x0066, 5: 0x0067, 4: 0x0068,
        34: 0x0069, 38: 0x006A, 40: 0x006B, 37: 0x006C, 46: 0x006D, 45: 0x006E, 31: 0x006F, 35: 0x0070,
        12: 0x0071, 15: 0x0072, 1: 0x0073, 17: 0x0074, 32: 0x0075, 9: 0x0076, 13: 0x0077, 7: 0x0078,
        16: 0x0079, 6: 0x007A,
        18: 0x0031, 19: 0x0032, 20: 0x0033, 21: 0x0034, 23: 0x0035, 22: 0x0036, 26: 0x0037, 28: 0x0038,
        25: 0x0039, 29: 0x0030,
        50: 0x0060, 27: 0x002D, 24: 0x003D, 33: 0x005B, 30: 0x005D, 42: 0x005C, 41: 0x003B, 39: 0x0027,
        43: 0x002C, 47: 0x002E, 44: 0x002F,
        49: 0x0020
    ]
    private static let macroKeyToCharacterShifted: [UInt16: UInt16] = [
        0: 0x0041, 11: 0x0042, 8: 0x0043, 2: 0x0044, 14: 0x0045, 3: 0x0046, 5: 0x0047, 4: 0x0048,
        34: 0x0049, 38: 0x004A, 40: 0x004B, 37: 0x004C, 46: 0x004D, 45: 0x004E, 31: 0x004F, 35: 0x0050,
        12: 0x0051, 15: 0x0052, 1: 0x0053, 17: 0x0054, 32: 0x0055, 9: 0x0056, 13: 0x0057, 7: 0x0058,
        16: 0x0059, 6: 0x005A,
        18: 0x0021, 19: 0x0040, 20: 0x0023, 21: 0x0024, 23: 0x0025, 22: 0x005E, 26: 0x0026, 28: 0x002A,
        25: 0x0028, 29: 0x0029,
        50: 0x007E, 27: 0x005F, 24: 0x002B, 33: 0x007B, 30: 0x007D, 42: 0x007C, 41: 0x003A, 39: 0x0022,
        43: 0x003C, 47: 0x003E, 44: 0x003F
    ]

    @objc class func initializeAndGetKeyHookState() {
        phtvEngineInitializeAndGetKeyHookState()
    }

    @objc class func notifyTableCodeChanged() {
        let macros = MacroStorage.load(defaults: .standard)
        let macroData = MacroStorage.engineBinaryData(from: macros)
        PHTVEngineDataBridge.initializeMacroMap(with: macroData)
    }

    class func eventMarkerValue() -> Int64 {
        eventMarker
    }

    class func handleMouseDown() {
        phtvEngineHandleMouseDown()
    }

    class func handleKeyboardKeyDown(
        keyCode: UInt16,
        capsStatus: UInt8,
        hasOtherControlKey: Bool
    ) {
        phtvEngineHandleKeyboardKeyDown(keyCode, capsStatus, hasOtherControlKey)
    }

    class func handleEnglishModeKeyDown(
        keyCode: UInt16,
        isCaps: Bool,
        hasOtherControlKey: Bool
    ) {
        phtvEngineHandleEnglishModeKeyDown(keyCode, isCaps, hasOtherControlKey)
    }

    class func primeUpperCaseFirstChar() {
        vPrimeUpperCaseFirstChar()
    }

    class func restoreToRawKeys() -> Bool {
        vRestoreToRawKeys()
    }

    class func tempOffSpellChecking() {
        vTempOffSpellChecking()
    }

    class func tempOffEngineNow() {
        vTempOffEngine(true)
    }

    class func barrier() {
        phtvRuntimeBarrier()
    }

    class func safeModeEnabled() -> Bool {
        phtvRuntimeSafeMode()
    }

    class func rememberCode() -> Int32 {
        Int32(phtvRuntimeRememberCode())
    }

    class func setRememberCode(_ value: Int32) {
        phtvRuntimeSetRememberCode(value)
    }

    class func currentLanguage() -> Int32 {
        Int32(phtvRuntimeCurrentLanguage())
    }

    class func setCurrentLanguage(_ language: Int32) {
        phtvRuntimeSetCurrentLanguage(language)
    }

    class func otherLanguageMode() -> Int32 {
        Int32(phtvRuntimeOtherLanguage())
    }

    class func setOtherLanguageMode(_ value: Int32) {
        phtvRuntimeSetOtherLanguage(value)
    }

    class func currentInputType() -> Int32 {
        Int32(phtvRuntimeCurrentInputType())
    }

    class func setCurrentInputType(_ inputType: Int32) {
        phtvRuntimeSetCurrentInputType(inputType)
    }

    class func currentCodeTable() -> Int32 {
        Int32(phtvRuntimeCurrentCodeTable())
    }

    class func setCurrentCodeTable(_ codeTable: Int32) {
        phtvRuntimeSetCurrentCodeTable(codeTable)
    }

    class func isDoubleCode(_ codeTable: Int32) -> Bool {
        codeTable == 2 || codeTable == 3
    }

    class func isSmartSwitchKeyEnabled() -> Bool {
        phtvRuntimeIsSmartSwitchKeyEnabled()
    }

    class func setSmartSwitchKeyEnabled(_ enabled: Bool) {
        phtvRuntimeSetUseSmartSwitchKey(enabled)
    }

    class func isSendKeyStepByStepEnabled() -> Bool {
        phtvRuntimeIsSendKeyStepByStepEnabled()
    }

    class func setSendKeyStepByStepEnabled(_ enabled: Bool) {
        phtvRuntimeSetSendKeyStepByStepEnabled(enabled)
    }

    class func setUpperCaseExcludedForCurrentApp(_ excluded: Bool) {
        phtvRuntimeSetUpperCaseExcludedForCurrentApp(excluded)
    }

    class func switchKeyStatus() -> Int32 {
        Int32(phtvRuntimeSwitchKeyStatus())
    }

    class func setSwitchKeyStatus(_ status: Int32) {
        phtvRuntimeSetSwitchKeyStatus(status)
    }

    class func setShowIconOnDock(_ visible: Bool) {
        phtvRuntimeSetShowIconOnDock(visible)
    }

    class func showIconOnDock() -> Int32 {
        Int32(phtvRuntimeShowIconOnDock())
    }

    class func upperCaseFirstChar() -> Int32 {
        Int32(phtvRuntimeUpperCaseFirstChar())
    }

    class func setUpperCaseFirstChar(_ value: Int32) {
        phtvRuntimeSetUpperCaseFirstChar(value)
    }

    class func upperCaseExcludedForCurrentApp() -> Int32 {
        Int32(phtvRuntimeUpperCaseExcludedForCurrentApp())
    }

    class func checkSpelling() -> Int32 {
        Int32(phtvRuntimeCheckSpelling())
    }

    class func setCheckSpelling(_ value: Int32) {
        phtvRuntimeSetCheckSpelling(value)
    }

    class func applyCheckSpelling() {
        vSetCheckSpelling()
    }

    class func useModernOrthography() -> Int32 {
        Int32(phtvRuntimeUseModernOrthography())
    }

    class func setUseModernOrthography(_ value: Int32) {
        phtvRuntimeSetUseModernOrthography(value)
    }

    class func quickTelex() -> Int32 {
        Int32(phtvRuntimeQuickTelex())
    }

    class func setQuickTelex(_ value: Int32) {
        phtvRuntimeSetQuickTelex(value)
    }

    class func freeMark() -> Int32 {
        Int32(phtvRuntimeFreeMark())
    }

    class func setFreeMark(_ value: Int32) {
        phtvRuntimeSetFreeMark(value)
    }

    class func useMacro() -> Int32 {
        Int32(phtvRuntimeUseMacro())
    }

    class func setUseMacro(_ value: Int32) {
        phtvRuntimeSetUseMacro(value)
    }

    class func useMacroInEnglishMode() -> Int32 {
        Int32(phtvRuntimeUseMacroInEnglishMode())
    }

    class func setUseMacroInEnglishMode(_ value: Int32) {
        phtvRuntimeSetUseMacroInEnglishMode(value)
    }

    class func autoCapsMacro() -> Int32 {
        Int32(phtvRuntimeAutoCapsMacro())
    }

    class func setAutoCapsMacro(_ value: Int32) {
        phtvRuntimeSetAutoCapsMacro(value)
    }

    class func allowConsonantZFWJ() -> Int32 {
        Int32(phtvRuntimeAllowConsonantZFWJ())
    }

    class func setAllowConsonantZFWJ(_ value: Int32) {
        phtvRuntimeSetAllowConsonantZFWJ(value)
    }

    class func quickStartConsonant() -> Int32 {
        Int32(phtvRuntimeQuickStartConsonant())
    }

    class func setQuickStartConsonant(_ value: Int32) {
        phtvRuntimeSetQuickStartConsonant(value)
    }

    class func quickEndConsonant() -> Int32 {
        Int32(phtvRuntimeQuickEndConsonant())
    }

    class func setQuickEndConsonant(_ value: Int32) {
        phtvRuntimeSetQuickEndConsonant(value)
    }

    class func performLayoutCompat() -> Int32 {
        Int32(phtvRuntimePerformLayoutCompat())
    }

    class func setPerformLayoutCompat(_ value: Int32) {
        phtvRuntimeSetPerformLayoutCompat(value)
    }

    class func restoreOnEscape() -> Int32 {
        Int32(phtvRuntimeRestoreOnEscape())
    }

    class func setRestoreOnEscape(_ value: Int32) {
        phtvRuntimeSetRestoreOnEscape(value)
    }

    class func customEscapeKey() -> Int32 {
        Int32(phtvRuntimeCustomEscapeKey())
    }

    class func setCustomEscapeKey(_ value: Int32) {
        phtvRuntimeSetCustomEscapeKey(value)
    }

    class func pauseKeyEnabled() -> Int32 {
        Int32(phtvRuntimePauseKeyEnabled())
    }

    class func setPauseKeyEnabled(_ value: Int32) {
        phtvRuntimeSetPauseKeyEnabled(value)
    }

    class func pauseKey() -> Int32 {
        Int32(phtvRuntimePauseKey())
    }

    class func setPauseKey(_ value: Int32) {
        phtvRuntimeSetPauseKey(value)
    }

    class func autoRestoreEnglishWord() -> Int32 {
        Int32(phtvRuntimeAutoRestoreEnglishWord())
    }

    class func setAutoRestoreEnglishWord(_ value: Int32) {
        phtvRuntimeSetAutoRestoreEnglishWord(value)
    }

    class func enableEmojiHotkey() -> Int32 {
        Int32(phtvRuntimeEnableEmojiHotkey())
    }

    class func emojiHotkeyModifiers() -> Int32 {
        Int32(phtvRuntimeEmojiHotkeyModifiers())
    }

    class func emojiHotkeyKeyCode() -> Int32 {
        Int32(phtvRuntimeEmojiHotkeyKeyCode())
    }

    class func setEmojiHotkeySettings(_ enabled: Int32, _ modifiers: Int32, _ keyCode: Int32) {
        phtvRuntimeSetEmojiHotkeySettings(enabled, modifiers, keyCode)
    }

    class func defaultSwitchHotkeyStatus() -> Int32 {
        Int32(Defaults.defaultSwitchKeyStatus)
    }

    class func defaultPauseKey() -> Int32 {
        Int32(KeyCode.leftOption)
    }

    class func setFixRecommendBrowser(_ value: Int32) {
        phtvRuntimeSetFixRecommendBrowser(value)
    }

    class func setTempOffSpelling(_ value: Int32) {
        phtvRuntimeSetTempOffSpelling(value)
    }

    class func setTempOffEngine(_ value: Int32) {
        phtvRuntimeSetTempOffPHTV(value)
    }

    class func setSafeMode(_ enabled: Bool) {
        phtvRuntimeSetSafeMode(enabled)
    }

    class func tempOffSpelling() -> Int32 {
        Int32(phtvRuntimeTempOffSpelling())
    }

    class func tempOffEngine() -> Int32 {
        Int32(phtvRuntimeTempOffPHTV())
    }

    class func fixRecommendBrowser() -> Int32 {
        Int32(phtvRuntimeFixRecommendBrowser())
    }

    class func startNewSession() {
        phtvRuntimeStartNewSession()
    }

    class func initializeMacroMap(_ data: UnsafePointer<UInt8>?, _ count: Int32) {
        initMacroMap(data, count)
    }

    class func initializeEnglishDictionary(_ path: UnsafePointer<CChar>) -> Bool {
        phtvEngineInitializeEnglishDictionary(path)
    }

    class func englishDictionarySize() -> Int32 {
        Int32(getEnglishDictionarySize())
    }

    class func initializeVietnameseDictionary(_ path: UnsafePointer<CChar>) -> Bool {
        phtvEngineInitializeVietnameseDictionary(path)
    }

    class func vietnameseDictionarySize() -> Int32 {
        Int32(getVietnameseDictionarySize())
    }

    class func initializeCustomDictionary(_ data: UnsafePointer<CChar>?, _ count: Int32) {
        initCustomDictionary(data, count)
    }

    class func customEnglishWordCount() -> Int32 {
        Int32(getCustomEnglishWordCount())
    }

    class func customVietnameseWordCount() -> Int32 {
        Int32(getCustomVietnameseWordCount())
    }

    class func clearCustomDictionary() {
        phtvEngineClearCustomDictionary()
    }

    class func hotkeyDisplayCharacter(_ keyCode: UInt16) -> UInt16 {
        macroKeyCodeToCharacter(UInt32(keyCode) | capsMask())
    }

    class func findCodeTableSourceKey(
        codeTable: Int32,
        character: UInt16
    ) -> (keyCode: UInt32, variantIndex: Int32)? {
        var keyCode: UInt32 = 0
        var variantIndex: Int32 = 0
        let found = phtvEngineFindCodeTableSourceKey(
            codeTable,
            character,
            &keyCode,
            &variantIndex
        )
        return found ? (keyCode, variantIndex) : nil
    }

    class func codeTableVariantCount(
        codeTable: Int32,
        keyCode: UInt32
    ) -> Int32 {
        Int32(phtvEngineCodeTableVariantCountForKey(codeTable, keyCode))
    }

    class func codeTableCharacterForKey(
        codeTable: Int32,
        keyCode: UInt32,
        variantIndex: Int32
    ) -> UInt16? {
        var character: UInt16 = 0
        let found = phtvEngineCodeTableCharacterForKey(
            codeTable,
            keyCode,
            variantIndex,
            &character
        )
        return found ? character : nil
    }

    class func capsMask() -> UInt32 {
        engineCapsMask
    }

    class func charCodeMask() -> UInt32 {
        engineCharCodeMask
    }

    class func pureCharacterMask() -> UInt32 {
        enginePureCharacterMask
    }

    class func macroKeyCodeToCharacter(_ keyData: UInt32) -> UInt16 {
        let allowedMask = UInt32(KeyCode.keyMask) | engineCapsMask
        guard (keyData & ~allowedMask) == 0 else {
            return 0
        }

        let keyCode = UInt16(truncatingIfNeeded: keyData & UInt32(KeyCode.keyMask))
        if (keyData & engineCapsMask) != 0 {
            return macroKeyToCharacterShifted[keyCode] ?? 0
        }
        return macroKeyToCharacterUnshifted[keyCode] ?? 0
    }

    class func keyDeleteCode() -> Int32 {
        Int32(KeyCode.delete)
    }

    class func keySlashCode() -> Int32 {
        Int32(KeyCode.slash)
    }

    class func keyEnterCode() -> Int32 {
        Int32(KeyCode.enter)
    }

    class func keyReturnCode() -> Int32 {
        Int32(KeyCode.returnKey)
    }

    class func spaceKeyCode() -> Int32 {
        Int32(KeyCode.space)
    }

    class func engineDoNothingCode() -> Int32 {
        engineDoNothingCodeValue
    }

    class func engineWillProcessCode() -> Int32 {
        engineWillProcessCodeValue
    }

    class func engineReplaceMacroCode() -> Int32 {
        engineReplaceMacroCodeValue
    }

    class func engineRestoreCode() -> Int32 {
        engineRestoreCodeValue
    }

    class func engineRestoreAndStartNewSessionCode() -> Int32 {
        engineRestoreAndStartNewSessionCodeValue
    }

    class func engineMaxBuffer() -> Int32 {
        engineMaxBufferValue
    }

    class func engineDataCode() -> Int32 {
        Int32(phtvEngineDataCode())
    }

    class func engineDataExtCode() -> Int32 {
        Int32(phtvEngineDataExtCode())
    }

    class func engineDataBackspaceCount() -> Int32 {
        Int32(phtvEngineDataBackspaceCount())
    }

    class func setEngineDataBackspaceCount(_ count: UInt8) {
        phtvEngineDataSetBackspaceCount(count)
    }

    class func engineDataNewCharCount() -> Int32 {
        Int32(phtvEngineDataNewCharCount())
    }

    class func engineDataCharAt(_ index: Int32) -> UInt32 {
        UInt32(phtvEngineDataCharAt(index))
    }

    class func engineDataMacroDataSize() -> Int32 {
        Int32(phtvEngineDataMacroDataSize())
    }

    class func engineDataMacroDataAt(_ index: Int32) -> UInt32 {
        UInt32(phtvEngineDataMacroDataAt(index))
    }

    class func lowByte(_ value: UInt32) -> UInt16 {
        UInt16(truncatingIfNeeded: value & 0x00FF)
    }

    class func hiByte(_ value: UInt32) -> UInt16 {
        UInt16(truncatingIfNeeded: (value >> 8) & 0x00FF)
    }

    class func unicodeCompoundMarkAt(_ index: Int32) -> UInt16 {
        let safeIndex = Int(index)
        guard unicodeCompoundMarks.indices.contains(safeIndex) else {
            return 0
        }
        return unicodeCompoundMarks[safeIndex]
    }

    class func isNavigationKey(_ keyCode: UInt16) -> Bool {
        navigationKeyCodes.contains(keyCode)
    }
}
