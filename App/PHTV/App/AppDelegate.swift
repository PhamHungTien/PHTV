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

    var accessibilityMonitorTask: Task<Void, Never>?
    var wasAccessibilityEnabled = false
    var accessibilityStableCount: UInt = 0
    var isPresentingAccessibilityRevokedAlert = false
    var isAttemptingTCCRepair = false
    var automaticTCCRepairAttemptCount = 0
    var lastAutomaticTCCRepairAttemptTime: CFAbsoluteTime = 0
    var healthCheckTask: Task<Void, Never>?
    var needsRelaunchAfterPermission = false
    var eventTapRecoveryToken: UInt = 0
    var lastEventTapRecoveryRequestTime: CFAbsoluteTime = 0
    var lastPublishedTypingPermissionReady: Bool?
    var permissionGuidancePresentationTask: Task<Void, Never>?
    var lastPresentedPermissionGuidanceStep: PHTVPermissionGuidanceStep?

    var savedLanguageBeforeExclusion = 0
    var previousBundleIdentifier: String?
    var isInExcludedApp = false
    var savedSendKeyStepByStepBeforeApp = false
    var isInSendKeyStepByStepApp = false
    var isUpdatingLanguage = false
    var isUpdatingInputType = false
    var isUpdatingCodeTable = false
    var appearanceObserver: Task<Void, Never>?
    var inputSourceObserver: Task<Void, Never>?
    var savedLanguageBeforeNonLatin = 0
    var isInNonLatinInputSource = false
    var monitoringNotificationTasks: [Task<Void, Never>] = []
    var settingsBridgeNotificationTasks: [Task<Void, Never>] = []
    var legacySwiftUINotificationTasks: [Task<Void, Never>] = []
    var sparkleNotificationTasks: [Task<Void, Never>] = []

    // Tracks the last-seen system text replacements token so macro list
    // can be refreshed when NSUserDictionaryReplacementItems changes.
    var lastSystemReplacementsChangeToken: Int = 0

    func makeNotificationTask(
        center: NotificationCenter = .default,
        name: Notification.Name,
        object: AnyObject? = nil,
        handler: @escaping @MainActor (AppDelegate, Notification) -> Void
    ) -> Task<Void, Never> {
        let observedObjectID = object.map(ObjectIdentifier.init)
        return Task { @MainActor [weak self] in
            guard let self else { return }
            for await notification in center.notifications(named: name) {
                guard !Task.isCancelled else { break }
                if let observedObjectID {
                    guard let notificationObject = notification.object as AnyObject?,
                          ObjectIdentifier(notificationObject) == observedObjectID else {
                        continue
                    }
                }
                handler(self, notification)
            }
        }
    }

    func cancelManagedNotificationTasks() {
        monitoringNotificationTasks.forEach { $0.cancel() }
        monitoringNotificationTasks.removeAll()

        settingsBridgeNotificationTasks.forEach { $0.cancel() }
        settingsBridgeNotificationTasks.removeAll()

        legacySwiftUINotificationTasks.forEach { $0.cancel() }
        legacySwiftUINotificationTasks.removeAll()

        sparkleNotificationTasks.forEach { $0.cancel() }
        sparkleNotificationTasks.removeAll()
    }
}
