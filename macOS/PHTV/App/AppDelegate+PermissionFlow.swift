//
//  AppDelegate+PermissionFlow.swift
//  PHTV
//
//  Permission request and recovery flow.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import AppKit
import ApplicationServices
import Foundation

func phtvShouldRepairPermissionEntryBeforeGuidance(
    permissionTrusted: Bool,
    forceOpenSystemSettings: Bool
) -> Bool {
    forceOpenSystemSettings && !permissionTrusted
}

@MainActor @objc extension AppDelegate {
    func askPermission() {
        presentPermissionGuidanceUI()
    }

    @nonobjc
    func continuePermissionGuidanceIfNeeded(forceOpenSystemSettings: Bool = false) {
        let runtimeHealth = currentTypingRuntimeHealthSnapshot()
        if runtimeHealth.phase == .relaunchPending {
            return
        }

        let step = currentPermissionGuidanceStep()
        guard step != .ready else {
            lastPresentedPermissionGuidanceStep = nil
            return
        }

        guard forceOpenSystemSettings || step != lastPresentedPermissionGuidanceStep else {
            return
        }

        lastPresentedPermissionGuidanceStep = step

        switch step {
        case .accessibility:
            NSLog("[PermissionFlow] Opening Accessibility guidance")
            if phtvShouldRepairPermissionEntryBeforeGuidance(
                permissionTrusted: runtimeHealth.axTrusted,
                forceOpenSystemSettings: forceOpenSystemSettings
            ) {
                PHTVAccessibilityService.repairAndOpenAccessibilityPreferences()
            } else {
                PHTVAccessibilityService.openAccessibilityPreferences()
            }
        case .inputMonitoring:
            NSLog("[PermissionFlow] Opening Input Monitoring guidance")
            if phtvShouldRepairPermissionEntryBeforeGuidance(
                permissionTrusted: runtimeHealth.inputMonitoringTrusted,
                forceOpenSystemSettings: forceOpenSystemSettings
            ) {
                PHTVAccessibilityService.repairAndOpenInputMonitoringPreferences()
            } else {
                PHTVAccessibilityService.openInputMonitoringPreferences()
            }
        case .waitingForEventTap:
            NSLog("[PermissionFlow] Retrying event tap initialization")
            retryTypingPermissionRecovery(reason: "permission-guidance")
        case .ready:
            break
        }
    }

    @nonobjc
    func retryTypingPermissionRecovery(reason: String = "manual-permission-retry") {
        PHTVManager.invalidatePermissionCache()
        publishTypingPermissionState(eventTapReady: false)
        requestEventTapRecovery(reason: reason, force: true)
    }

    @nonobjc
    private func presentPermissionGuidanceUI() {
        NotificationCenter.default.post(name: NotificationName.showSettings, object: nil)

        let hasCompletedOnboarding = UserDefaults.standard.bool(
            forKey: UserDefaultsKey.onboardingCompleted)

        permissionGuidancePresentationTask?.cancel()
        permissionGuidancePresentationTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard let self, !Task.isCancelled else { return }

            if hasCompletedOnboarding {
                // Returning user lost a permission: jump straight to the
                // permission step and open the right System Settings pane.
                NotificationCenter.default.post(
                    name: NotificationName.showOnboarding,
                    object: nil,
                    userInfo: [
                        NotificationUserInfoKey.onboardingInitialStep:
                            OnboardingView.permissionStepIndex
                    ])
                self.continuePermissionGuidanceIfNeeded(forceOpenSystemSettings: true)
            } else {
                // First install: show the full tour without covering it with
                // System Settings. The permission step opens the correct pane
                // in context once the user reaches it.
                NotificationCenter.default.post(name: NotificationName.showOnboarding, object: nil)
            }
        }
    }

    @nonobjc
    private func currentPermissionGuidanceStep() -> PHTVPermissionGuidanceStep {
        currentTypingRuntimeHealthSnapshot().guidanceStep
    }
}
