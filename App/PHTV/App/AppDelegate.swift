//
//  AppDelegate.swift
//  PHTV
//
//  Swift-native AppDelegate owner type and shared runtime storage.
//

import AppKit

let PHTVBundleIdentifier = "com.phamhungtien.phtv"

@MainActor @objcMembers
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var lastInputMethod: Int = 0
    var lastCodeTable: Int = 0
    var isUpdatingUI = false
    var lastDefaultsApplyTime: CFAbsoluteTime = 0
    var lastSettingsChangeToken: UInt = 0
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
}
