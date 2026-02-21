//
//  PHTVManager+RuntimeState.swift
//  PHTV
//
//  Runtime state bridge methods for PHTVManager.
//

import Foundation

@objc extension PHTVManager {
    private static let smartSwitchSpotlightCacheDurationMs: UInt64 = 150

    private class func smartSwitchFocusedBundleId() -> String? {
        PHTVAppContextService.focusedBundleId(
            forSafeMode: phtvRuntimeSafeMode(),
            cacheDurationMs: smartSwitchSpotlightCacheDurationMs
        )
    }

    @objc(phtv_requestNewSession)
    class func phtv_requestNewSession() {
        phtvRuntimeRequestNewSession()
    }

    @objc(phtv_invalidateLayoutCache)
    class func phtv_invalidateLayoutCache() {
        PHTVHotkeyService.invalidateLayoutCache()
    }

    @objc(phtv_notifyInputMethodChanged)
    class func phtv_notifyInputMethodChanged() {
        PHTVSmartSwitchBridgeService.handleInputMethodChanged(
            forBundleId: smartSwitchFocusedBundleId(),
            useSmartSwitchKey: phtv_isSmartSwitchKeyEnabled() ? 1 : 0,
            currentLanguage: phtv_currentLanguage(),
            currentCodeTable: phtv_currentCodeTable()
        )
    }

    @objc(phtv_notifyTableCodeChanged)
    class func phtv_notifyTableCodeChanged() {
        phtvEngineNotifyTableCodeChanged()
        PHTVSmartSwitchBridgeService.handleTableCodeChanged(
            forBundleId: smartSwitchFocusedBundleId(),
            rememberCode: Int32(phtvRuntimeRememberCode()),
            currentLanguage: phtv_currentLanguage(),
            currentCodeTable: phtv_currentCodeTable()
        )
    }

    @objc(phtv_notifyActiveAppChanged)
    class func phtv_notifyActiveAppChanged() {
        PHTVSmartSwitchBridgeService.handleActiveAppChanged(
            forBundleId: smartSwitchFocusedBundleId(),
            useSmartSwitchKey: phtv_isSmartSwitchKeyEnabled() ? 1 : 0,
            rememberCode: Int32(phtvRuntimeRememberCode()),
            currentLanguage: phtv_currentLanguage(),
            currentCodeTable: phtv_currentCodeTable()
        )
    }

    @objc(phtv_currentLanguage)
    class func phtv_currentLanguage() -> Int32 {
        Int32(phtvRuntimeCurrentLanguage())
    }

    @objc(phtv_setCurrentLanguage:)
    class func phtv_setCurrentLanguage(_ language: Int32) {
        phtvRuntimeSetCurrentLanguage(language)
    }

    @objc(phtv_otherLanguageMode)
    class func phtv_otherLanguageMode() -> Int32 {
        Int32(phtvRuntimeOtherLanguage())
    }

    @objc(phtv_currentInputType)
    class func phtv_currentInputType() -> Int32 {
        Int32(phtvRuntimeCurrentInputType())
    }

    @objc(phtv_setCurrentInputType:)
    class func phtv_setCurrentInputType(_ inputType: Int32) {
        phtvRuntimeSetCurrentInputType(inputType)
    }

    @objc(phtv_currentCodeTable)
    class func phtv_currentCodeTable() -> Int32 {
        Int32(phtvRuntimeCurrentCodeTable())
    }

    @objc(phtv_setCurrentCodeTable:)
    class func phtv_setCurrentCodeTable(_ codeTable: Int32) {
        phtvRuntimeSetCurrentCodeTable(codeTable)
    }

    @objc(phtv_isSmartSwitchKeyEnabled)
    class func phtv_isSmartSwitchKeyEnabled() -> Bool {
        phtvRuntimeIsSmartSwitchKeyEnabled()
    }

    @objc(phtv_isSendKeyStepByStepEnabled)
    class func phtv_isSendKeyStepByStepEnabled() -> Bool {
        phtvRuntimeIsSendKeyStepByStepEnabled()
    }

    @objc(phtv_setSendKeyStepByStepEnabled:)
    class func phtv_setSendKeyStepByStepEnabled(_ enabled: Bool) {
        phtvRuntimeSetSendKeyStepByStepEnabled(enabled)
    }

    @objc(phtv_setUpperCaseExcludedForCurrentApp:)
    class func phtv_setUpperCaseExcludedForCurrentApp(_ excluded: Bool) {
        phtvRuntimeSetUpperCaseExcludedForCurrentApp(excluded)
    }

    @objc(phtv_currentSwitchKeyStatus)
    class func phtv_currentSwitchKeyStatus() -> Int32 {
        Int32(phtvRuntimeSwitchKeyStatus())
    }

    @objc(phtv_setSwitchKeyStatus:)
    class func phtv_setSwitchKeyStatus(_ status: Int32) {
        phtvRuntimeSetSwitchKeyStatus(status)
    }

    @objc(phtv_setDockIconRuntimeVisible:)
    class func phtv_setDockIconRuntimeVisible(_ visible: Bool) {
        phtvRuntimeSetShowIconOnDock(visible)
    }
}
