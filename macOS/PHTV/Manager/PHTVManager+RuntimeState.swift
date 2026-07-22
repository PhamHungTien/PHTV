//
//  PHTVManager+RuntimeState.swift
//  PHTV
//
//  Runtime state bridge methods for PHTVManager.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation

private final class PHTVSessionRequestState: @unchecked Sendable {
    private let lock = NSLock()
    private var lastRequestTime: CFAbsoluteTime = 0
    private var skippedRequestCount = 0

    /// Returns the number of coalesced calls, or nil when this call should be skipped.
    func beginRequest(now: CFAbsoluteTime, minimumInterval: CFAbsoluteTime) -> Int? {
        lock.lock()
        defer { lock.unlock() }

        guard (now - lastRequestTime) >= minimumInterval else {
            skippedRequestCount += 1
            return nil
        }

        let skipped = skippedRequestCount
        skippedRequestCount = 0
        lastRequestTime = now
        return skipped
    }
}

@objc extension PHTVManager {
    private static let smartSwitchSpotlightCacheDurationMs: UInt64 = 150

    // Coalesces rapid-fire session resets that carry identical engine state.
    // Direct callers (event tap, input callbacks) use requestNewSessionInternal
    // and are not affected by this throttle.
    @nonobjc private static let sessionRequestState = PHTVSessionRequestState()
    private static let sessionRequestMinInterval: CFAbsoluteTime = 0.05 // 50ms

    private class func smartSwitchFocusedBundleId() -> String? {
        PHTVAppContextService.focusedBundleId(
            forSafeMode: PHTVEngineRuntimeFacade.safeModeEnabled(),
            cacheDurationMs: smartSwitchSpotlightCacheDurationMs
        )
    }

    @objc(phtv_requestNewSession)
    class func phtv_requestNewSession() {
        let now = CFAbsoluteTimeGetCurrent()
        guard let skippedRequestCount = sessionRequestState.beginRequest(
            now: now,
            minimumInterval: sessionRequestMinInterval
        ) else { return }
        #if DEBUG
        if skippedRequestCount > 0 {
            NSLog("[RequestNewSession] Coalesced %d duplicate call(s) within %.0fms window",
                  skippedRequestCount, sessionRequestMinInterval * 1000)
        }
        #endif
        PHTVEngineSessionService.requestNewSession()
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
        let macros = MacroStorage.load(defaults: .standard)
        let macroData = MacroStorage.engineBinaryData(from: macros)
        PHTVEngineDataBridge.initializeMacroMap(with: macroData)
        PHTVSmartSwitchBridgeService.handleTableCodeChanged(
            forBundleId: smartSwitchFocusedBundleId(),
            rememberCode: PHTVEngineRuntimeFacade.rememberCode(),
            currentLanguage: phtv_currentLanguage(),
            currentCodeTable: phtv_currentCodeTable()
        )
    }

    @objc(phtv_notifyActiveAppChanged)
    class func phtv_notifyActiveAppChanged() {
        PHTVSmartSwitchBridgeService.handleActiveAppChanged(
            forBundleId: smartSwitchFocusedBundleId(),
            useSmartSwitchKey: phtv_isSmartSwitchKeyEnabled() ? 1 : 0,
            rememberCode: PHTVEngineRuntimeFacade.rememberCode(),
            currentLanguage: phtv_currentLanguage(),
            currentCodeTable: phtv_currentCodeTable()
        )
    }

    @objc(phtv_currentLanguage)
    class func phtv_currentLanguage() -> Int32 {
        PHTVEngineRuntimeFacade.currentLanguage()
    }

    @objc(phtv_setCurrentLanguage:)
    class func phtv_setCurrentLanguage(_ language: Int32) {
        PHTVEngineRuntimeFacade.setCurrentLanguage(language)
    }

    @objc(phtv_otherLanguageMode)
    class func phtv_otherLanguageMode() -> Int32 {
        PHTVEngineRuntimeFacade.otherLanguageMode()
    }

    @objc(phtv_currentInputType)
    class func phtv_currentInputType() -> Int32 {
        PHTVEngineRuntimeFacade.currentInputType()
    }

    @objc(phtv_setCurrentInputType:)
    class func phtv_setCurrentInputType(_ inputType: Int32) {
        PHTVEngineRuntimeFacade.setCurrentInputType(inputType)
    }

    @objc(phtv_currentCodeTable)
    class func phtv_currentCodeTable() -> Int32 {
        PHTVEngineRuntimeFacade.currentCodeTable()
    }

    @objc(phtv_setCurrentCodeTable:)
    class func phtv_setCurrentCodeTable(_ codeTable: Int32) {
        PHTVEngineRuntimeFacade.setCurrentCodeTable(codeTable)
    }

    @objc(phtv_isSmartSwitchKeyEnabled)
    class func phtv_isSmartSwitchKeyEnabled() -> Bool {
        PHTVEngineRuntimeFacade.isSmartSwitchKeyEnabled()
    }

    @objc(phtv_isSendKeyStepByStepEnabled)
    class func phtv_isSendKeyStepByStepEnabled() -> Bool {
        PHTVEngineRuntimeFacade.isSendKeyStepByStepEnabled()
    }

    @objc(phtv_setSendKeyStepByStepEnabled:)
    class func phtv_setSendKeyStepByStepEnabled(_ enabled: Bool) {
        PHTVEngineRuntimeFacade.setSendKeyStepByStepEnabled(enabled)
    }

    @objc(phtv_setUpperCaseExcludeScope:)
    class func phtv_setUpperCaseExcludeScope(_ scope: Int32) {
        PHTVEngineRuntimeFacade.setUpperCaseExcludeScope(scope)
    }

    @objc(phtv_currentSwitchKeyStatus)
    class func phtv_currentSwitchKeyStatus() -> Int32 {
        PHTVEngineRuntimeFacade.switchKeyStatus()
    }

    @objc(phtv_setSwitchKeyStatus:)
    class func phtv_setSwitchKeyStatus(_ status: Int32) {
        PHTVEngineRuntimeFacade.setSwitchKeyStatus(status)
    }

    @objc(phtv_setDockIconRuntimeVisible:)
    class func phtv_setDockIconRuntimeVisible(_ visible: Bool) {
        PHTVEngineRuntimeFacade.setShowIconOnDock(visible)
    }
}
