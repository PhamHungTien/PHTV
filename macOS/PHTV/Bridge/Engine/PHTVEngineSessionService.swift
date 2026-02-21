//
//  PHTVEngineSessionService.swift
//  PHTV
//
//  Engine initialization and session management.
//  Migrated from PHTV.mm (PHTVInit, RequestNewSessionInternal, RequestNewSession).
//

import ApplicationServices
import Darwin
import Foundation

@objc(PHTVEngineSessionService)
final class PHTVEngineSessionService: NSObject {

    private static let kSyncKeyReserveSize: Int32 = 256
    private static let keyEventMouse: Int32 = Int32(PHTV_ENGINE_EVENT_MOUSE)
    private static let keyEventStateMouseDown: Int32 = Int32(PHTV_ENGINE_EVENT_STATE_MOUSE_DOWN)

    @objc class func boot() {
        PHTVCoreSettingsBootstrapService.loadFromUserDefaults()
        PHTVSafeModeStartupService.recoverAndValidateAccessibilityState()
        PHTVLayoutCompatibilityService.autoEnableIfNeeded()
        PHTVKeyEventSenderService.initializeEventSource()
        PHTVEngineRuntimeFacade.initializeAndGetKeyHookState()
        PHTVTypingSyncStateService.setupSyncKeyCapacity(kSyncKeyReserveSize)
        PHTVEngineStartupDataService.loadFromUserDefaults()
    }

    @objc class func requestNewSession() {
        requestNewSessionInternal(allowUppercasePrime: true)
    }

    static func requestNewSessionInternal(allowUppercasePrime: Bool) {
        // Reset AX context caches on new session (often triggered by mouse click/focus change).
        PHTVEventContextBridgeService.invalidateAccessibilityContextCaches()

        // Acquire barrier: ensure we see latest config changes before processing
        OSMemoryBarrier()

        #if DEBUG
        let dbgInputType = PHTVEngineRuntimeFacade.currentInputType()
        let dbgCodeTable = PHTVEngineRuntimeFacade.currentCodeTable()
        let dbgLanguage = PHTVEngineRuntimeFacade.currentLanguage()
        NSLog("[RequestNewSession] vInputType=%d, vCodeTable=%d, vLanguage=%d",
              dbgInputType, dbgCodeTable, dbgLanguage)
        #endif

        // Must use Mouse event, NOT startNewSession directly!
        // The Mouse event triggers proper word-break handling which clears:
        // - hMacroKey (critical for macro state)
        // - _specialChar and _typingStates (critical for typing state)
        // - vCheckSpelling restoration
        // - _willTempOffEngine flag
        phtvEngineHandleEvent(keyEventMouse, keyEventStateMouseDown, 0, 0, 0)

        let currentCodeTable = PHTVEngineRuntimeFacade.currentCodeTable()
        let sessionResetTransition = PHTVHotkeyService.sessionResetTransition(
            forCodeTable: currentCodeTable,
            allowUppercasePrime: allowUppercasePrime,
            safeMode: PHTVEngineRuntimeFacade.safeModeEnabled(),
            uppercaseEnabled: PHTVEngineRuntimeFacade.upperCaseFirstChar(),
            uppercaseExcluded: PHTVEngineRuntimeFacade.upperCaseExcludedForCurrentApp())

        if sessionResetTransition.shouldClearSyncKey {
            PHTVTypingSyncStateService.clearSyncKey()
        }
        if sessionResetTransition.shouldPrimeUppercaseFirstChar {
            phtvEnginePrimeUpperCaseFirstChar()
        }
        PHTVModifierRuntimeStateService.applySessionResetTransition(sessionResetTransition)

        // Release barrier: ensure state reset is visible to all threads
        OSMemoryBarrier()

        #if DEBUG
        NSLog("[RequestNewSession] Session reset complete")
        #endif
    }
}
