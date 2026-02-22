//
//  AppDelegate+EventTapRecovery.swift
//  PHTV
//
//  Self-healing event tap recovery for startup/wake/app-active transitions.
//

import AppKit
import Foundation

private let phtvEventTapRecoveryDelays: [TimeInterval] = [0.0, 0.25, 0.75, 1.5, 3.0]
private let phtvEventTapRecoveryThrottle: CFAbsoluteTime = 0.15
private let phtvPostRecoveryEmojiRefreshDelays: [TimeInterval] = [0.0, 0.25]

@MainActor extension AppDelegate {
    func requestEventTapRecovery(reason: String, force: Bool = false) {
        let now = CFAbsoluteTimeGetCurrent()
        if !force && (now - lastEventTapRecoveryRequestTime) < phtvEventTapRecoveryThrottle {
            return
        }
        lastEventTapRecoveryRequestTime = now

        eventTapRecoveryToken &+= 1
        let token = eventTapRecoveryToken

        for (index, delay) in phtvEventTapRecoveryDelays.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                Task { @MainActor in
                    self?.performEventTapRecoveryAttempt(
                        reason: reason,
                        attempt: index + 1,
                        totalAttempts: phtvEventTapRecoveryDelays.count,
                        token: token
                    )
                }
            }
        }
    }

    func cancelEventTapRecovery(reason: String) {
        eventTapRecoveryToken &+= 1
        NSLog("[EventTap] Recovery schedule cancelled (%@)", reason)
    }

    private func refreshEmojiHotkeyRegistrationAfterRecovery() {
        for delay in phtvPostRecoveryEmojiRefreshDelays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                EmojiHotkeyBridge.refreshEmojiHotkeyRegistration()
            }
        }
    }

    private func performEventTapRecoveryAttempt(
        reason: String,
        attempt: Int,
        totalAttempts: Int,
        token: UInt
    ) {
        guard token == eventTapRecoveryToken else {
            return
        }

        guard PHTVManager.canCreateEventTap() else {
            if attempt == totalAttempts {
                NSLog("[EventTap] Recovery (%@) stopped: permission unavailable", reason)
            }
            return
        }

        let isInited = PHTVManager.isInited()
        let isEnabled = PHTVManager.isEventTapEnabled()

        if isInited && isEnabled {
            eventTapRecoveryToken &+= 1
            return
        }

        if isInited && !isEnabled {
            NSLog("[EventTap] Recovery (%@) attempt %d/%d: tap disabled, recreating",
                  reason, attempt, totalAttempts)
            _ = PHTVManager.stopEventTap()
        } else {
            NSLog("[EventTap] Recovery (%@) attempt %d/%d: tap not initialized",
                  reason, attempt, totalAttempts)
        }

        let initialized = PHTVManager.initEventTap()
        let enabledAfterInit = PHTVManager.isEventTapEnabled()

        if initialized && enabledAfterInit {
            PHTVManager.requestNewSession()
            startHealthCheckMonitoring()
            startAccessibilityMonitoring(withInterval: currentMonitoringInterval(), resetState: false)
            refreshEmojiHotkeyRegistrationAfterRecovery()
            eventTapRecoveryToken &+= 1
            NSLog("[EventTap] Recovery (%@) succeeded on attempt %d/%d",
                  reason, attempt, totalAttempts)
            return
        }

        if attempt == totalAttempts {
            NSLog("[EventTap] Recovery (%@) exhausted after %d attempts",
                  reason, totalAttempts)
        }
    }
}
