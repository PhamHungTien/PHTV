//
//  AppDelegate+InputSourceMonitoring.swift
//  PHTV
//
//  Swift port of AppDelegate+InputSourceMonitoring.mm.
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
    @objc func observeAppearanceChanges() {
        DistributedNotificationCenter.default().addObserver(self,
                                                            selector: #selector(handleAppearanceChanged(_:)),
                                                            name: phtvAppearanceChangedNotification,
                                                            object: nil)
        appearanceObserver = NSNumber(value: 1)
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

        if PHTVManager.otherLanguageMode() == 0 {
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
                NSLog("[InputSource] Detected non-Latin keyboard: %@ -> Auto-switching PHTV to English", displayName)
                applyInputMethodLanguage(0)
            }
            return
        }

        if isLatin && isInNonLatinInputSource {
            isInNonLatinInputSource = false

            if savedLanguageBeforeNonLatin != 0 && currentLanguage == 0 {
                NSLog("[InputSource] Detected Latin keyboard: %@ -> Restoring PHTV to Vietnamese", displayName)
                applyInputMethodLanguage(savedLanguageBeforeNonLatin)
            }
        }
    }

    @objc func startInputSourceMonitoring() {
        isInNonLatinInputSource = false
        savedLanguageBeforeNonLatin = 0

        DistributedNotificationCenter.default().addObserver(self,
                                                            selector: #selector(handleInputSourceChanged(_:)),
                                                            name: phtvInputSourceChangedNotification,
                                                            object: nil)
        inputSourceObserver = NSNumber(value: 1)

        NSLog("[InputSource] Started monitoring input source changes")
    }

    @objc func stopInputSourceMonitoring() {
        if let appearanceObserver {
            _ = appearanceObserver
            DistributedNotificationCenter.default().removeObserver(self,
                                                                   name: phtvAppearanceChangedNotification,
                                                                   object: nil)
            self.appearanceObserver = nil
        }

        if let inputSourceObserver {
            _ = inputSourceObserver
            DistributedNotificationCenter.default().removeObserver(self,
                                                                   name: phtvInputSourceChangedNotification,
                                                                   object: nil)
            self.inputSourceObserver = nil
        }

        isInNonLatinInputSource = false
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
