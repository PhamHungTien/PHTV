//
//  AppDelegate.swift
//  PHTV
//
//  Swift-native AppDelegate owner type and shared runtime storage.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import AppKit

let PHTVBundleIdentifier = "com.phamhungtien.phtv"

@MainActor @objcMembers
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private static weak var sharedInstance: AppDelegate?

    static func current() -> AppDelegate? {
        if let sharedInstance {
            return sharedInstance
        }
        return NSApp.delegate as? AppDelegate
    }

    override init() {
        super.init()
        Self.sharedInstance = self
    }

    var lastInputMethod: Int = 0
    var lastCodeTable: Int = 0
    var isUpdatingUI = false
    var lastDefaultsApplyTime: CFAbsoluteTime = 0
    var lastSettingsChangeToken: UInt = 0
    var lastConvertToolHotkeyDefaultsValue: Int?
    var hasLastDockVisibilityRequest = false
    var lastDockVisibilityRequest = false
    var lastDockForceFrontRequest = false
    var lastDockVisibilityRequestTime: CFAbsoluteTime = 0
    var settingsWindowOpen = false

    var accessibilityMonitor: Timer?
    var wasAccessibilityEnabled = false
    var accessibilityStableCount: UInt = 0
    var isAttemptingTCCRepair = false
    var didAttemptTCCRepairOnce = false
    var healthCheckTimer: Timer?
    var needsRelaunchAfterPermission = false
    var eventTapRecoveryToken: UInt = 0
    var lastEventTapRecoveryRequestTime: CFAbsoluteTime = 0
    var lastPublishedTypingPermissionReady: Bool?

    var savedLanguageBeforeExclusion = 0
    var previousBundleIdentifier: String?
    var isInExcludedApp = false
    var savedSendKeyStepByStepBeforeApp = false
    var isInSendKeyStepByStepApp = false
    var isUpdatingLanguage = false
    var isUpdatingInputType = false
    var isUpdatingCodeTable = false
    var appearanceObserver: Any?
    var inputSourceObserver: Any?
    var userDefaultsObserver: Any?
    var savedLanguageBeforeNonLatin = 0
    var isInNonLatinInputSource = false

    // Tracks the last-seen system text replacements token so macro list
    // can be refreshed when NSUserDictionaryReplacementItems changes.
    var lastSystemReplacementsChangeToken: Int = 0
}
