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
private let phtvSwitchHotkeyModifierMask: UInt32 = UInt32(
    KeyCode.controlMask
    | KeyCode.optionMask
    | KeyCode.commandMask
    | KeyCode.shiftMask
    | KeyCode.fnMask
)
private let phtvSwitchHotkeyAllowedMask: UInt32 = phtvSwitchHotkeyModifierMask
    | UInt32(KeyCode.beepMask)
    | UInt32(KeyCode.keyMask)
private let phtvConvertHotkeyModifierMask: UInt32 = 0x0100 | 0x0200 | 0x0400 | 0x0800
private let phtvConvertHotkeyAllowedMask: UInt32 = phtvConvertHotkeyModifierMask | 0x00FF
private let phtvConvertEmptyHotkey: Int32 = Int32(bitPattern: 0xFE0000FE)

private func phtvSwitchHotkeyLooksValid(_ status: Int32) -> Bool {
    let value = UInt32(bitPattern: status)
    if (value & ~phtvSwitchHotkeyAllowedMask) != 0 {
        return false
    }

    let modifiers = value & phtvSwitchHotkeyModifierMask
    let key = value & UInt32(KeyCode.keyMask)
    return modifiers != 0 && key != UInt32(KeyCode.keyMask)
}

private func phtvConvertHotkeyLooksValid(_ hotkey: Int32) -> Bool {
    if hotkey == phtvConvertEmptyHotkey {
        return true
    }

    let value = UInt32(bitPattern: hotkey)
    if (value & ~phtvConvertHotkeyAllowedMask) != 0 {
        return false
    }

    let modifiers = value & phtvConvertHotkeyModifierMask
    let key = value & 0x00FF
    return modifiers != 0 && key != 0x00FF
}

private func phtvEmojiHotkeyLooksValid(enabled: Int32, modifiers: Int32, keyCode: Int32) -> Bool {
    guard enabled != 0 else {
        return true
    }

    let modifierMask = Int32(
        NSEvent.ModifierFlags.command.rawValue
        | NSEvent.ModifierFlags.option.rawValue
        | NSEvent.ModifierFlags.control.rawValue
        | NSEvent.ModifierFlags.shift.rawValue
        | NSEvent.ModifierFlags.function.rawValue
    )
    let normalizedModifiers = modifiers & modifierMask
    guard normalizedModifiers != 0 else {
        return false
    }

    return keyCode >= 0 && keyCode < Int32(KeyCode.keyMask)
}

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

    func runHotkeyHealthCheck(reason: String) {
        let tapReady = PHTVManager.isInited() && PHTVManager.isEventTapEnabled()
        let switchHotkey = Int32(PHTVManager.currentSwitchKeyStatus())
        let convertHotkey = Int32(PHTVConvertToolHotkeyService.currentHotkey())
        let snapshot = PHTVManager.runtimeSettingsSnapshot()
        let emojiEnabled = snapshot["enableEmojiHotkey"]?.int32Value ?? 0
        let emojiModifiers = snapshot["emojiHotkeyModifiers"]?.int32Value ?? 0
        let emojiKeyCode = snapshot["emojiHotkeyKeyCode"]?.int32Value ?? Int32(KeyCode.eKey)

        let switchValid = phtvSwitchHotkeyLooksValid(switchHotkey)
        let convertValid = phtvConvertHotkeyLooksValid(convertHotkey)
        let emojiValid = phtvEmojiHotkeyLooksValid(
            enabled: emojiEnabled,
            modifiers: emojiModifiers,
            keyCode: emojiKeyCode
        )
        let allValid = switchValid && convertValid && emojiValid

        if allValid {
            NSLog(
                "[HotkeyHealth] %@ PASS (tap=%@ switch=0x%X convert=0x%X emoji=%d/0x%X/%d)",
                reason,
                tapReady ? "YES" : "NO",
                switchHotkey,
                convertHotkey,
                emojiEnabled,
                emojiModifiers,
                emojiKeyCode
            )
            return
        }

        NSLog(
            "[HotkeyHealth] %@ FAIL (tap=%@ switchValid=%@ convertValid=%@ emojiValid=%@) - self-healing",
            reason,
            tapReady ? "YES" : "NO",
            switchValid ? "YES" : "NO",
            convertValid ? "YES" : "NO",
            emojiValid ? "YES" : "NO"
        )

        _ = PHTVManager.loadRuntimeSettingsFromUserDefaults()
        EmojiHotkeyBridge.refreshEmojiHotkeyRegistration()
        if tapReady {
            PHTVManager.requestNewSession()
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
            runHotkeyHealthCheck(reason: "\(reason)-alreadyHealthy")
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
            runHotkeyHealthCheck(reason: "\(reason)-recovered")
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
