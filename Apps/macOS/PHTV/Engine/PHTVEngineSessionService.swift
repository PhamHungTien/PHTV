//
//  PHTVEngineSessionService.swift
//  PHTV
//
//  Engine initialization and session management.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
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
        PHTVEngineRuntimeFacade.initializeAndGetKeyHookState()
        PHTVTypingSyncStateService.setupSyncKeyCapacity(kSyncKeyReserveSize)
        PHTVEngineStartupDataService.loadFromUserDefaults()
    }

    @objc class func requestNewSession() {
        requestNewSessionInternal(allowUppercasePrime: true)
    }

    static func requestNewSessionInternal(allowUppercasePrime: Bool, preserveModifierState: Bool = false) {
        // Reset AX context caches on new session (often triggered by mouse click/focus change).
        PHTVEventContextBridgeService.invalidateAccessibilityContextCaches()

        // Runtime settings are lock-backed; reading them here observes latest committed values.

        #if DEBUG
        let dbgInputType = PHTVEngineRuntimeFacade.currentInputType()
        let dbgCodeTable = PHTVEngineRuntimeFacade.currentCodeTable()
        let dbgLanguage = PHTVEngineRuntimeFacade.currentLanguage()
        NSLog("[RequestNewSession] vInputType=%d, vCodeTable=%d, vLanguage=%d",
              dbgInputType, dbgCodeTable, dbgLanguage)
        #endif

        // Focus changes discard the previous composition, including history
        // and temporary flags. A synthetic mouse word break can take an
        // auto-restore branch whose output is never sent to the old field.
        engineResetInputSession()

        let currentCodeTable = PHTVEngineRuntimeFacade.currentCodeTable()
        let frontmostBundleId = PHTVAppContextService.currentFrontmostBundleId()
        let contextSafeMode =
            PHTVEngineRuntimeFacade.safeModeEnabled() ||
            PHTVAppDetectionService.prefersLowLatencyEventContext(frontmostBundleId)
        let sessionResetTransition = PHTVHotkeyService.sessionResetTransition(
            forCodeTable: currentCodeTable,
            allowUppercasePrime: allowUppercasePrime,
            safeMode: contextSafeMode,
            uppercaseEnabled: PHTVEngineRuntimeFacade.upperCaseFirstChar(),
            // Session reset only primes the Vietnamese engine's auto-capitalize,
            // so resolve the exclusion for the Vietnamese side of the scope.
            uppercaseExcluded: phtvRuntimeUpperCaseExcludedForVietnamese())

        if sessionResetTransition.shouldClearSyncKey {
            PHTVTypingSyncStateService.clearSyncKey()
        }
        if sessionResetTransition.shouldPrimeUppercaseFirstChar {
            phtvEnginePrimeUpperCaseFirstChar()
        }
        if preserveModifierState {
            // A focus boundary observed during keyDown must not erase the
            // preceding flagsChanged event; its release is still outstanding.
            PHTVModifierRuntimeStateService.setPendingUppercasePrimeCheckValue(
                sessionResetTransition.pendingUppercasePrimeCheck)
        } else {
            PHTVModifierRuntimeStateService.applySessionResetTransition(sessionResetTransition)
        }

        // Session reset state is now applied through lock-backed services.

        #if DEBUG
        NSLog("[RequestNewSession] Session reset complete")
        #endif
    }
}
