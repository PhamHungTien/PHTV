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

@MainActor @objc extension AppDelegate {
    func askPermission() {
        presentPermissionGuidanceUI()
    }

    @nonobjc
    func continuePermissionGuidanceIfNeeded(forceOpenSystemSettings: Bool = false) {
        let step = currentPermissionGuidanceStep()
        guard step != .ready else {
            lastPresentedPermissionGuidanceStep = nil
            return
        }

        guard forceOpenSystemSettings || step != lastPresentedPermissionGuidanceStep else {
            return
        }

        lastPresentedPermissionGuidanceStep = step
        requestMissingPermissionPromptsIfNeeded()

        switch step {
        case .accessibility:
            NSLog("[PermissionFlow] Opening Accessibility guidance")
            PHTVAccessibilityService.openAccessibilityPreferences()
        case .inputMonitoring:
            NSLog("[PermissionFlow] Opening Input Monitoring guidance")
            PHTVPermissionService.openInputMonitoringPreferences()
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

        permissionGuidancePresentationTask?.cancel()
        permissionGuidancePresentationTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard let self, !Task.isCancelled else { return }

            NotificationCenter.default.post(name: NotificationName.showOnboarding, object: nil)
            self.continuePermissionGuidanceIfNeeded(forceOpenSystemSettings: true)
        }
    }

    @nonobjc
    private func currentPermissionGuidanceStep() -> PHTVPermissionGuidanceStep {
        let accessibilityTrusted = AXIsProcessTrusted()
        let postEventGranted = PHTVPermissionService.hasPostEventAccess()
        let inputMonitoringGranted = PHTVPermissionService.hasListenEventAccess()
        let eventTapReady = accessibilityTrusted
            && postEventGranted
            && inputMonitoringGranted
            && PHTVManager.isInited()
            && PHTVManager.isEventTapEnabled()

        return PHTVPermissionGuidanceStep.resolve(
            accessibilityTrusted: accessibilityTrusted,
            postEventGranted: postEventGranted,
            inputMonitoringGranted: inputMonitoringGranted,
            eventTapReady: eventTapReady
        )
    }

    @nonobjc
    private func requestMissingPermissionPromptsIfNeeded() {
        if !PHTVPermissionService.hasPostEventAccess() {
            _ = PHTVPermissionService.requestPostEventAccess()
        }
        if !PHTVPermissionService.hasListenEventAccess() {
            _ = PHTVPermissionService.requestListenEventAccess()
        }
    }
}
