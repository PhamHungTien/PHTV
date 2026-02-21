//
//  PHTVManager+PublicAPI.swift
//  PHTV
//
//  Public Objective-C API surface for PHTVManager implemented in Swift.
//

import AppKit
import Foundation

@objc extension PHTVManager {
    private class func resolvedBuildDateString() -> String {
        guard let executableURL = Bundle.main.executableURL,
              let attributes = try? FileManager.default.attributesOfItem(atPath: executableURL.path),
              let modifiedAt = attributes[.modificationDate] as? Date else {
            return ""
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d yyyy"
        return formatter.string(from: modifiedAt)
    }

    @objc(hasPermissionLost)
    class func hasPermissionLost() -> Bool {
        PHTVEventTapService.hasPermissionLost()
    }

    @objc(markPermissionLost)
    class func markPermissionLost() {
        PHTVEventTapService.markPermissionLost()
    }

    @objc(invalidatePermissionCache)
    class func invalidatePermissionCache() {
        PHTVPermissionService.invalidatePermissionCache()
    }

    @objc(isTCCEntryCorrupt)
    class func isTCCEntryCorrupt() -> Bool {
        phtv_isTCCEntryCorrupt()
    }

    @objc(autoFixTCCEntryWithError:)
    class func autoFixTCCEntry(withError error: AutoreleasingUnsafeMutablePointer<NSError?>?) -> Bool {
        phtv_autoFixTCCEntry(withError: error)
    }

    @objc(restartTCCDaemon)
    class func restartTCCDaemon() {
        phtv_restartTCCDaemon()
    }

    @objc(startTCCNotificationListener)
    class func startTCCNotificationListener() {
        phtv_startTCCNotificationListener()
    }

    @objc(stopTCCNotificationListener)
    class func stopTCCNotificationListener() {
        phtv_stopTCCNotificationListener()
    }

    @objc(canCreateEventTap)
    class func canCreateEventTap() -> Bool {
        PHTVPermissionService.canCreateEventTap()
    }

    @objc(forcePermissionCheck)
    class func forcePermissionCheck() -> Bool {
        PHTVPermissionService.forcePermissionCheck()
    }

    @objc(isInited)
    class func isInited() -> Bool {
        PHTVEventTapService.isEventTapInited()
    }

    @objc(initEventTap)
    @discardableResult
    class func initEventTap() -> Bool {
        PHTVEventTapService.initEventTap()
    }

    @objc(stopEventTap)
    @discardableResult
    class func stopEventTap() -> Bool {
        PHTVEventTapService.stopEventTap()
    }

    @objc(handleEventTapDisabled:)
    class func handleEventTapDisabled(_ type: CGEventType) {
        PHTVEventTapService.handleEventTapDisabled(type)
    }

    @objc(isEventTapEnabled)
    class func isEventTapEnabled() -> Bool {
        PHTVEventTapService.isEventTapEnabled()
    }

    @objc(ensureEventTapAlive)
    class func ensureEventTapAlive() {
        PHTVEventTapService.ensureEventTapAlive()
    }

    @objc(getTableCodes)
    class func getTableCodes() -> [String] {
        phtv_getTableCodes()
    }

    @objc(getBuildDate)
    class func getBuildDate() -> String {
        resolvedBuildDateString()
    }

    @objc(showMessage:message:subMsg:)
    @MainActor
    class func showMessage(_ window: NSWindow?, message msg: String, subMsg: String) {
        let alert = NSAlert()
        alert.messageText = msg
        alert.informativeText = subMsg
        alert.addButton(withTitle: "OK")
        if let window {
            alert.beginSheetModal(for: window) { _ in }
        } else {
            alert.runModal()
        }
    }

    @objc(requestNewSession)
    class func requestNewSession() {
        phtv_requestNewSession()
    }

    @objc(invalidateLayoutCache)
    class func invalidateLayoutCache() {
        phtv_invalidateLayoutCache()
    }

    @objc(currentLanguage)
    class func currentLanguage() -> Int32 {
        phtv_currentLanguage()
    }

    @objc(setCurrentLanguage:)
    class func setCurrentLanguage(_ language: Int32) {
        phtv_setCurrentLanguage(language)
    }

    @objc(otherLanguageMode)
    class func otherLanguageMode() -> Int32 {
        phtv_otherLanguageMode()
    }

    @objc(currentInputType)
    class func currentInputType() -> Int32 {
        phtv_currentInputType()
    }

    @objc(setCurrentInputType:)
    class func setCurrentInputType(_ inputType: Int32) {
        phtv_setCurrentInputType(inputType)
    }

    @objc(currentCodeTable)
    class func currentCodeTable() -> Int32 {
        phtv_currentCodeTable()
    }

    @objc(setCurrentCodeTable:)
    class func setCurrentCodeTable(_ codeTable: Int32) {
        phtv_setCurrentCodeTable(codeTable)
    }

    @objc(isSmartSwitchKeyEnabled)
    class func isSmartSwitchKeyEnabled() -> Bool {
        phtv_isSmartSwitchKeyEnabled()
    }

    @objc(notifyInputMethodChanged)
    class func notifyInputMethodChanged() {
        phtv_notifyInputMethodChanged()
    }

    @objc(notifyTableCodeChanged)
    class func notifyTableCodeChanged() {
        phtv_notifyTableCodeChanged()
    }

    @objc(notifyActiveAppChanged)
    class func notifyActiveAppChanged() {
        phtv_notifyActiveAppChanged()
    }

    @objc(isSendKeyStepByStepEnabled)
    class func isSendKeyStepByStepEnabled() -> Bool {
        phtv_isSendKeyStepByStepEnabled()
    }

    @objc(setSendKeyStepByStepEnabled:)
    class func setSendKeyStepByStepEnabled(_ enabled: Bool) {
        phtv_setSendKeyStepByStepEnabled(enabled)
    }

    @objc(setUpperCaseExcludedForCurrentApp:)
    class func setUpperCaseExcludedForCurrentApp(_ excluded: Bool) {
        phtv_setUpperCaseExcludedForCurrentApp(excluded)
    }

    @objc(runtimeSettingsSnapshot)
    class func runtimeSettingsSnapshot() -> [String: NSNumber] {
        phtv_runtimeSettingsSnapshot()
    }

    @objc(currentSwitchKeyStatus)
    class func currentSwitchKeyStatus() -> Int32 {
        phtv_currentSwitchKeyStatus()
    }

    @objc(setSwitchKeyStatus:)
    class func setSwitchKeyStatus(_ status: Int32) {
        phtv_setSwitchKeyStatus(status)
    }

    @objc(loadEmojiHotkeySettingsFromDefaults)
    class func loadEmojiHotkeySettingsFromDefaults() {
        phtv_loadEmojiHotkeySettingsFromDefaults()
    }

    @objc(syncSpellingSetting)
    class func syncSpellingSetting() {
        let defaults = UserDefaults.standard
        let spellingEnabled: Int32
        if defaults.object(forKey: "Spelling") == nil {
            spellingEnabled = Int32(phtvRuntimeCheckSpelling())
        } else {
            spellingEnabled = defaults.bool(forKey: "Spelling") ? 1 : 0
        }

        phtvRuntimeSetCheckSpelling(spellingEnabled)
        phtvEngineApplyCheckSpelling()
    }

    @objc(setDockIconRuntimeVisible:)
    class func setDockIconRuntimeVisible(_ visible: Bool) {
        phtv_setDockIconRuntimeVisible(visible)
    }

    @objc(toggleSpellCheckSetting)
    class func toggleSpellCheckSetting() -> Int32 {
        phtv_toggleSpellCheckSetting()
    }

    @objc(toggleAllowConsonantZFWJSetting)
    class func toggleAllowConsonantZFWJSetting() -> Int32 {
        phtv_toggleAllowConsonantZFWJSetting()
    }

    @objc(toggleModernOrthographySetting)
    class func toggleModernOrthographySetting() -> Int32 {
        phtv_toggleModernOrthographySetting()
    }

    @objc(toggleQuickTelexSetting)
    class func toggleQuickTelexSetting() -> Int32 {
        phtv_toggleQuickTelexSetting()
    }

    @objc(toggleUpperCaseFirstCharSetting)
    class func toggleUpperCaseFirstCharSetting() -> Int32 {
        phtv_toggleUpperCaseFirstCharSetting()
    }

    @objc(toggleAutoRestoreEnglishWordSetting)
    class func toggleAutoRestoreEnglishWordSetting() -> Int32 {
        phtv_toggleAutoRestoreEnglishWordSetting()
    }

    @objc(loadRuntimeSettingsFromUserDefaults)
    class func loadRuntimeSettingsFromUserDefaults() -> UInt {
        phtv_loadRuntimeSettingsFromUserDefaults()
    }

    @objc(loadDefaultConfig)
    class func loadDefaultConfig() {
        phtv_loadDefaultConfig()
    }

    @objc(quickConvert)
    class func quickConvert() -> Bool {
        phtv_quickConvert()
    }

    @objc(getApplicationSupportFolder)
    class func getApplicationSupportFolder() -> String {
        phtv_getApplicationSupportFolder()
    }

    @objc(isSafeModeEnabled)
    class func isSafeModeEnabled() -> Bool {
        phtv_isSafeModeEnabled()
    }

    @objc(setSafeModeEnabled:)
    class func setSafeModeEnabled(_ enabled: Bool) {
        phtv_setSafeModeEnabled(enabled)
    }

    @objc(clearAXTestFlag)
    class func clearAXTestFlag() {
        phtv_clearAXTestFlag()
    }

    @objc(getBinaryArchitectures)
    class func getBinaryArchitectures() -> String {
        phtv_getBinaryArchitectures()
    }

    @objc(getBinaryHash)
    class func getBinaryHash() -> String? {
        phtv_getBinaryHash()
    }

    @objc(hasBinaryChangedSinceLastRun)
    class func hasBinaryChangedSinceLastRun() -> Bool {
        phtv_hasBinaryChangedSinceLastRun()
    }

    @objc(checkBinaryIntegrity)
    class func checkBinaryIntegrity() -> Bool {
        phtv_checkBinaryIntegrity()
    }
}
