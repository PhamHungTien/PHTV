//
//  AppDelegate+InputSourceMonitoring.swift
//  PHTV
//
//  Input source and appearance monitoring.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import AppKit
import Carbon
import Foundation

private let phtvDefaultsKeyInputMethod = "InputMethod"
private let phtvNotificationLanguageChangedFromObjC = Notification.Name("LanguageChangedFromObjC")
private let phtvInputSourceChangedNotification =
    Notification.Name(rawValue: kTISNotifySelectedKeyboardInputSourceChanged as String)
private let phtvAppearanceChangedNotification = Notification.Name("AppleInterfaceThemeChangedNotification")

private func phtvInputSourceProperty(_ inputSource: TISInputSource, _ key: CFString) -> AnyObject? {
    guard let rawValue = TISGetInputSourceProperty(inputSource, key) else {
        return nil
    }
    return Unmanaged<AnyObject>.fromOpaque(rawValue).takeUnretainedValue()
}

@MainActor extension AppDelegate {
    private func resetInputSourceTrackingState() {
        isInNonLatinInputSource = false
        savedLanguageBeforeNonLatin = 0
    }

    @objc func observeAppearanceChanges() {
        guard appearanceObserver == nil else { return }

        appearanceObserver = makeNotificationTask(
            center: DistributedNotificationCenter.default(),
            name: phtvAppearanceChangedNotification
        ) { appDelegate, notification in
            appDelegate.handleAppearanceChanged(notification)
        }
    }

    @objc func handleAppearanceChanged(_ notification: Notification) {
        _ = notification
        fillData()
    }

    func isLatinInputSource(_ inputSource: TISInputSource?) -> Bool {
        PHTVInputSourceLanguageService.isLatinInputSource(inputSource)
    }

    @objc func handleInputSourceChanged(_ notification: Notification) {
        _ = notification
        PHTVManager.invalidateLayoutCache()
        syncCurrentInputSourceState(reason: "changed")
    }

    private func syncCurrentInputSourceState(reason: String) {
        if PHTVManager.otherLanguageMode() == 0 {
            resetInputSourceTrackingState()
            return
        }

        guard let currentInputSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return
        }

        let isLatin = isLatinInputSource(currentInputSource)
        let localizedName = phtvInputSourceProperty(currentInputSource, kTISPropertyLocalizedName) as? String
        let sourceID = phtvInputSourceProperty(currentInputSource, kTISPropertyInputSourceID) as? String
        let displayName = localizedName ?? sourceID ?? "Unknown"

        let currentLanguage = Int(PHTVManager.currentLanguage())

        if !isLatin && !isInNonLatinInputSource {
            savedLanguageBeforeNonLatin = currentLanguage
            isInNonLatinInputSource = true

            if currentLanguage != 0 {
                NSLog("[InputSource] %@: non-Latin keyboard %@ -> auto-switching PHTV to English", reason, displayName)
                applyInputMethodLanguage(0)
            }
            return
        }

        if isLatin && isInNonLatinInputSource {
            isInNonLatinInputSource = false

            if savedLanguageBeforeNonLatin != 0 && currentLanguage == 0 {
                NSLog("[InputSource] %@: Latin keyboard %@ -> restoring PHTV to Vietnamese", reason, displayName)
                applyInputMethodLanguage(savedLanguageBeforeNonLatin)
            }
        }
    }

    @objc func startInputSourceMonitoring() {
        if inputSourceObserver == nil {
            resetInputSourceTrackingState()

            inputSourceObserver = makeNotificationTask(
                center: DistributedNotificationCenter.default(),
                name: phtvInputSourceChangedNotification
            ) { appDelegate, notification in
                appDelegate.handleInputSourceChanged(notification)
            }

            NSLog("[InputSource] Started monitoring input source changes")
        }

        syncCurrentInputSourceState(reason: "monitoring-start")
    }

    @objc func stopInputSourceMonitoring() {
        if let appearanceObserver {
            appearanceObserver.cancel()
            self.appearanceObserver = nil
        }

        if let inputSourceObserver {
            inputSourceObserver.cancel()
            self.inputSourceObserver = nil
        }

        resetInputSourceTrackingState()
    }

    private func applyInputMethodLanguage(_ language: Int) {
        PHTVManager.setCurrentLanguage(Int32(language))
        UserDefaults.standard.set(language, forKey: phtvDefaultsKeyInputMethod)
        PHTVManager.requestNewSession()
        fillData()

        NotificationCenter.default.post(name: phtvNotificationLanguageChangedFromObjC,
                                        object: NSNumber(value: language))
    }
}
