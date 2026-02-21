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

    @objc class func boot() {
        PHTVCoreSettingsBootstrapService.loadFromUserDefaults()
        PHTVSafeModeStartupService.recoverAndValidateAccessibilityState()
        PHTVLayoutCompatibilityService.autoEnableIfNeeded()
        PHTVKeyEventSenderService.initializeEventSource()
        phtvEngineInitializeAndGetKeyHookState()
        PHTVTypingSyncStateService.setupSyncKeyCapacity(kSyncKeyReserveSize)
        PHTVEngineStartupDataService.loadFromUserDefaults()
        PHTVConvertToolSettingsService.loadFromUserDefaults()
    }

    @objc class func requestNewSession() {
        requestNewSessionInternal(allowUppercasePrime: true)
    }

    static func requestNewSessionInternal(allowUppercasePrime: Bool) {
        // Reset AX context caches on new session (often triggered by mouse click/focus change).
        PHTVEventContextBridgeService.invalidateAccessibilityContextCaches()

        // Acquire barrier: ensure we see latest config changes before processing
        phtvRuntimeBarrier()

        #if DEBUG
        let dbgInputType = phtvRuntimeCurrentInputType()
        let dbgCodeTable = phtvRuntimeCurrentCodeTable()
        let dbgLanguage  = phtvRuntimeCurrentLanguage()
        NSLog("[RequestNewSession] vInputType=%d, vCodeTable=%d, vLanguage=%d",
              dbgInputType, dbgCodeTable, dbgLanguage)
        #endif

        // Must use Mouse event, NOT startNewSession directly!
        // The Mouse event triggers proper word-break handling which clears:
        // - hMacroKey (critical for macro state)
        // - _specialChar and _typingStates (critical for typing state)
        // - vCheckSpelling restoration
        // - _willTempOffEngine flag
        phtvEngineHandleMouseDown()

        let currentCodeTable = Int32(phtvRuntimeCurrentCodeTable())
        let sessionResetTransition = PHTVHotkeyService.sessionResetTransition(
            forCodeTable: currentCodeTable,
            allowUppercasePrime: allowUppercasePrime,
            safeMode: phtvRuntimeSafeMode(),
            uppercaseEnabled: Int32(phtvRuntimeUpperCaseFirstChar()),
            uppercaseExcluded: Int32(phtvRuntimeUpperCaseExcludedForCurrentApp()))

        if sessionResetTransition.shouldClearSyncKey {
            PHTVTypingSyncStateService.clearSyncKey()
        }
        if sessionResetTransition.shouldPrimeUppercaseFirstChar {
            phtvEnginePrimeUpperCaseFirstChar()
        }
        PHTVModifierRuntimeStateService.applySessionResetTransition(sessionResetTransition)

        // Release barrier: ensure state reset is visible to all threads
        phtvRuntimeBarrier()

        #if DEBUG
        NSLog("[RequestNewSession] Session reset complete")
        #endif
    }
}
