//
//  PHTVManager+RuntimeState.swift
//  PHTV
//
//  Runtime state bridge methods for PHTVManager.
//

import Foundation

@objc extension PHTVManager {
    @objc(phtv_requestNewSession)
    class func phtv_requestNewSession() {
        RequestNewSession()
    }

    @objc(phtv_invalidateLayoutCache)
    class func phtv_invalidateLayoutCache() {
        InvalidateLayoutCache()
    }

    @objc(phtv_notifyInputMethodChanged)
    class func phtv_notifyInputMethodChanged() {
        OnInputMethodChanged()
    }

    @objc(phtv_notifyTableCodeChanged)
    class func phtv_notifyTableCodeChanged() {
        OnTableCodeChange()
    }

    @objc(phtv_notifyActiveAppChanged)
    class func phtv_notifyActiveAppChanged() {
        OnActiveAppChanged()
    }

    @objc(phtv_currentLanguage)
    class func phtv_currentLanguage() -> Int32 {
        Int32(PHTVGetCurrentLanguage())
    }

    @objc(phtv_setCurrentLanguage:)
    class func phtv_setCurrentLanguage(_ language: Int32) {
        PHTVSetCurrentLanguage(language)
    }

    @objc(phtv_otherLanguageMode)
    class func phtv_otherLanguageMode() -> Int32 {
        Int32(PHTVGetOtherLanguage())
    }

    @objc(phtv_currentInputType)
    class func phtv_currentInputType() -> Int32 {
        Int32(PHTVGetCurrentInputType())
    }

    @objc(phtv_setCurrentInputType:)
    class func phtv_setCurrentInputType(_ inputType: Int32) {
        PHTVSetCurrentInputType(inputType)
    }

    @objc(phtv_currentCodeTable)
    class func phtv_currentCodeTable() -> Int32 {
        Int32(PHTVGetCurrentCodeTable())
    }

    @objc(phtv_setCurrentCodeTable:)
    class func phtv_setCurrentCodeTable(_ codeTable: Int32) {
        PHTVSetCurrentCodeTable(codeTable)
    }

    @objc(phtv_isSmartSwitchKeyEnabled)
    class func phtv_isSmartSwitchKeyEnabled() -> Bool {
        PHTVIsSmartSwitchKeyEnabled()
    }

    @objc(phtv_isSendKeyStepByStepEnabled)
    class func phtv_isSendKeyStepByStepEnabled() -> Bool {
        PHTVIsSendKeyStepByStepEnabled()
    }

    @objc(phtv_setSendKeyStepByStepEnabled:)
    class func phtv_setSendKeyStepByStepEnabled(_ enabled: Bool) {
        PHTVSetSendKeyStepByStepEnabled(enabled)
    }

    @objc(phtv_setUpperCaseExcludedForCurrentApp:)
    class func phtv_setUpperCaseExcludedForCurrentApp(_ excluded: Bool) {
        PHTVSetUpperCaseExcludedForCurrentApp(excluded)
    }

    @objc(phtv_currentSwitchKeyStatus)
    class func phtv_currentSwitchKeyStatus() -> Int32 {
        Int32(PHTVGetSwitchKeyStatus())
    }

    @objc(phtv_setSwitchKeyStatus:)
    class func phtv_setSwitchKeyStatus(_ status: Int32) {
        PHTVSetSwitchKeyStatus(status)
    }

    @objc(phtv_setDockIconRuntimeVisible:)
    class func phtv_setDockIconRuntimeVisible(_ visible: Bool) {
        PHTVSetShowIconOnDock(visible)
    }
}
