//
//  PHTVEngineRuntimeFacade.swift
//  PHTV
//
//  Swift facade over C++ interop runtime/engine functions.
//

import Foundation

@objcMembers
final class PHTVEngineRuntimeFacade: NSObject {
    @objc class func initializeAndGetKeyHookState() {
        phtvEngineInitializeAndGetKeyHookState()
    }

    @objc class func notifyTableCodeChanged() {
        phtvEngineNotifyTableCodeChanged()
    }

    class func eventMarkerValue() -> Int64 {
        Int64(phtvEventMarkerValue())
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

    class func handleKeyboardKeyDown(
        _ keyCode: UInt16,
        _ capsStatus: UInt8,
        _ hasOtherControlKey: Bool
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

    class func handleEnglishModeKeyDown(
        _ keyCode: UInt16,
        _ isCaps: Bool,
        _ hasOtherControlKey: Bool
    ) {
        phtvEngineHandleEnglishModeKeyDown(keyCode, isCaps, hasOtherControlKey)
    }

    class func primeUpperCaseFirstChar() {
        phtvEnginePrimeUpperCaseFirstChar()
    }

    class func restoreToRawKeys() -> Bool {
        phtvEngineRestoreToRawKeys()
    }

    class func tempOffSpellChecking() {
        phtvEngineTempOffSpellChecking()
    }

    class func tempOffEngineNow() {
        phtvEngineTempOffEngine()
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
        phtvRuntimeIsDoubleCode(codeTable)
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
        phtvEngineApplyCheckSpelling()
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
        Int32(phtvRuntimeDefaultSwitchHotkeyStatus())
    }

    class func defaultPauseKey() -> Int32 {
        Int32(phtvRuntimeDefaultPauseKey())
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

    class func convertToolDefaultHotKey() -> Int32 {
        Int32(phtvConvertToolDefaultHotKey())
    }

    class func convertToolResetOptions() {
        phtvConvertToolResetOptions()
    }

    class func convertToolSetOptions(
        _ dontAlertWhenCompleted: Bool,
        _ toAllCaps: Bool,
        _ toAllNonCaps: Bool,
        _ toCapsFirstLetter: Bool,
        _ toCapsEachWord: Bool,
        _ removeMark: Bool,
        _ fromCode: Int32,
        _ toCode: Int32,
        _ hotKey: Int32
    ) {
        phtvConvertToolSetOptions(
            dontAlertWhenCompleted,
            toAllCaps,
            toAllNonCaps,
            toCapsFirstLetter,
            toCapsEachWord,
            removeMark,
            fromCode,
            toCode,
            hotKey
        )
    }

    class func convertToolNormalizeOptions() {
        phtvConvertToolNormalizeOptions()
    }

    class func convertUtf8(_ source: UnsafePointer<CChar>) -> UnsafePointer<CChar>? {
        phtvEngineConvertUtf8(source)
    }

    class func initializeMacroMap(_ data: UnsafePointer<UInt8>?, _ count: Int32) {
        phtvEngineInitializeMacroMap(data, count)
    }

    class func initializeEnglishDictionary(_ path: UnsafePointer<CChar>) -> Bool {
        phtvEngineInitializeEnglishDictionary(path)
    }

    class func englishDictionarySize() -> Int32 {
        Int32(phtvEngineEnglishDictionarySize())
    }

    class func initializeVietnameseDictionary(_ path: UnsafePointer<CChar>) -> Bool {
        phtvEngineInitializeVietnameseDictionary(path)
    }

    class func vietnameseDictionarySize() -> Int32 {
        Int32(phtvEngineVietnameseDictionarySize())
    }

    class func initializeCustomDictionary(_ data: UnsafePointer<CChar>?, _ count: Int32) {
        phtvEngineInitializeCustomDictionary(data, count)
    }

    class func customEnglishWordCount() -> Int32 {
        Int32(phtvEngineCustomEnglishWordCount())
    }

    class func customVietnameseWordCount() -> Int32 {
        Int32(phtvEngineCustomVietnameseWordCount())
    }

    class func clearCustomDictionary() {
        phtvEngineClearCustomDictionary()
    }

    class func setCheckSpellingValue(_ value: Int32) {
        phtvEngineSetCheckSpellingValue(value)
    }

    class func hotkeyDisplayCharacter(_ keyCode: UInt16) -> UInt16 {
        UInt16(phtvEngineHotkeyDisplayCharacter(keyCode))
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
        UInt32(phtvEngineCapsMask())
    }

    class func charCodeMask() -> UInt32 {
        UInt32(phtvEngineCharCodeMask())
    }

    class func pureCharacterMask() -> UInt32 {
        UInt32(phtvEnginePureCharacterMask())
    }

    class func macroKeyCodeToCharacter(_ keyData: UInt32) -> UInt16 {
        UInt16(phtvEngineMacroKeyCodeToCharacter(keyData))
    }

    class func keyDeleteCode() -> Int32 {
        Int32(phtvEngineKeyDeleteCode())
    }

    class func keySlashCode() -> Int32 {
        Int32(phtvEngineKeySlashCode())
    }

    class func keyEnterCode() -> Int32 {
        Int32(phtvEngineKeyEnterCode())
    }

    class func keyReturnCode() -> Int32 {
        Int32(phtvEngineKeyReturnCode())
    }

    class func spaceKeyCode() -> Int32 {
        Int32(phtvEngineSpaceKeyCode())
    }

    class func engineDoNothingCode() -> Int32 {
        Int32(phtvEngineVDoNothingCode())
    }

    class func engineWillProcessCode() -> Int32 {
        Int32(phtvEngineVWillProcessCode())
    }

    class func engineReplaceMacroCode() -> Int32 {
        Int32(phtvEngineVReplaceMaroCode())
    }

    class func engineRestoreCode() -> Int32 {
        Int32(phtvEngineVRestoreCode())
    }

    class func engineRestoreAndStartNewSessionCode() -> Int32 {
        Int32(phtvEngineVRestoreAndStartNewSessionCode())
    }

    class func engineMaxBuffer() -> Int32 {
        Int32(phtvEngineMaxBuff())
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

    class func engineDataMacroDataPointer() -> UnsafePointer<UInt32>? {
        phtvEngineDataMacroDataPtr()
    }

    class func lowByte(_ value: UInt32) -> UInt16 {
        UInt16(phtvEngineLowByte(value))
    }

    class func hiByte(_ value: UInt32) -> UInt16 {
        UInt16(phtvEngineHiByte(value))
    }

    class func unicodeCompoundMarkAt(_ index: Int32) -> UInt16 {
        phtvEngineUnicodeCompoundMarkAt(index)
    }

    class func interopProbeValue() -> Int32 {
        Int32(phtvEngineInteropProbeValue())
    }

    class func interopAdd(_ lhs: Int32, _ rhs: Int32) -> Int32 {
        Int32(phtvEngineInteropAdd(lhs, rhs))
    }

    class func isNavigationKey(_ keyCode: UInt16) -> Bool {
        phtvMacKeyIsNavigation(keyCode)
    }
}
