//
//  SystemSettingsNavigator.swift
//  PHTV
//
//  Centralized System Settings deep-link helper.
//

import AppKit
import ApplicationServices
import Foundation

enum SystemSettingsNavigator {
    @discardableResult
    static func openAccessibility(promptForTrust: Bool = false) -> Bool {
        if promptForTrust {
            let promptKey = "AXTrustedCheckOptionPrompt"
            let options = [promptKey: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }

        return openFirstMatchingURL(from: [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension",
            "x-apple.systempreferences:com.apple.preference.security?Privacy"
        ])
    }

    @discardableResult
    static func openInputMonitoring() -> Bool {
        openFirstMatchingURL(from: [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ListenEvent",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension",
            "x-apple.systempreferences:com.apple.preference.security?Privacy"
        ])
    }

    @discardableResult
    static func openKeyboard() -> Bool {
        openFirstMatchingURL(from: [
            "x-apple.systempreferences:com.apple.Keyboard-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.keyboard"
        ])
    }

    @discardableResult
    private static func openFirstMatchingURL(from candidates: [String]) -> Bool {
        for candidate in candidates {
            guard let url = URL(string: candidate) else {
                continue
            }
            if NSWorkspace.shared.open(url) {
                return true
            }
        }
        return false
    }
}
