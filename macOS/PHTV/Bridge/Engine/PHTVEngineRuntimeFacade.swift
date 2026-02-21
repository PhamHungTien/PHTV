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

    class func handleMouseDown() {
        phtvEngineHandleMouseDown()
    }

    class func primeUpperCaseFirstChar() {
        phtvEnginePrimeUpperCaseFirstChar()
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
}
