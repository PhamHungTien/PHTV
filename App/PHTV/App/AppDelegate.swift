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
    var statusItem: NSStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var statusMenu: NSMenu = NSMenu()
    var menuInputMethod: NSMenuItem?
    var mnuTelex: NSMenuItem?
    var mnuVNI: NSMenuItem?
    var mnuSimpleTelex1: NSMenuItem?
    var mnuSimpleTelex2: NSMenuItem?
    var mnuUnicode: NSMenuItem?
    var mnuTCVN: NSMenuItem?
    var mnuVNIWindows: NSMenuItem?
    var mnuUnicodeComposite: NSMenuItem?
    var mnuVietnameseLocaleCP1258: NSMenuItem?
    var mnuQuickConvert: NSMenuItem?
    var mnuSpellCheck: NSMenuItem?
    var mnuAllowConsonantZFWJ: NSMenuItem?
    var mnuModernOrthography: NSMenuItem?
    var mnuQuickTelex: NSMenuItem?
    var mnuUpperCaseFirstChar: NSMenuItem?
    var mnuAutoRestoreEnglishWord: NSMenuItem?
    var statusBarFontSize: CGFloat = 0
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
