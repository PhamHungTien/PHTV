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

private let phtvNonLatinInputSourcePatterns: [String] = [
    "com.apple.inputmethod.Kotoeri", "com.apple.inputmethod.Japanese",
    "com.google.inputmethod.Japanese", "jp.co.atok",
    "com.apple.inputmethod.SCIM", "com.apple.inputmethod.TCIM",
    "com.apple.inputmethod.ChineseHandwriting",
    "com.sogou.inputmethod", "com.baidu.inputmethod",
    "com.tencent.inputmethod", "com.iflytek.inputmethod",
    "com.apple.inputmethod.Korean", "com.apple.inputmethod.KoreanIM",
    "com.apple.keylayout.Arabic", "com.apple.keylayout.ArabicPC",
    "com.apple.keylayout.Hebrew", "com.apple.keylayout.HebrewQWERTY",
    "com.apple.keylayout.Thai", "com.apple.keylayout.ThaiPattachote",
    "com.apple.keylayout.Devanagari", "com.apple.keylayout.Hindi",
    "com.apple.inputmethod.Hindi",
    "com.apple.keylayout.Greek", "com.apple.keylayout.GreekPolytonic",
    "com.apple.keylayout.Russian", "com.apple.keylayout.RussianPC",
    "com.apple.keylayout.Ukrainian", "com.apple.keylayout.Bulgarian",
    "com.apple.keylayout.Serbian", "com.apple.keylayout.Macedonian",
    "com.apple.keylayout.Georgian",
    "com.apple.keylayout.Armenian",
    "com.apple.keylayout.Tamil", "com.apple.keylayout.Telugu",
    "com.apple.keylayout.Kannada", "com.apple.keylayout.Malayalam",
    "com.apple.keylayout.Gujarati", "com.apple.keylayout.Punjabi",
    "com.apple.keylayout.Bengali", "com.apple.keylayout.Oriya",
    "com.apple.keylayout.Myanmar", "com.apple.keylayout.Khmer",
    "com.apple.keylayout.Lao",
    "com.apple.keylayout.Tibetan", "com.apple.keylayout.Nepali",
    "com.apple.keylayout.Sinhala",
    "com.apple.CharacterPaletteIM", "com.apple.PressAndHold",
    "com.apple.inputmethod.EmojiFunctionRowItem"
]

private let phtvLatinLanguages: Set<String> = [
    "en", "de", "fr", "es", "it", "pt", "nl", "ca",
    "da", "sv", "no", "nb", "nn", "fi", "is", "fo",
    "pl", "cs", "sk", "hu", "ro", "hr", "sl", "sr-Latn",
    "et", "lv", "lt",
    "sq", "bs", "mt",
    "tr", "az", "uz", "tk",
    "id", "ms", "vi", "tl", "jv", "su",
    "sw", "ha", "yo", "ig", "zu", "xh", "af",
    "mi", "sm", "to", "haw",
    "ga", "gd", "cy", "br",
    "eo", "la", "mul"
]

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
        guard let inputSource else {
            return true
        }

        let sourceID = phtvInputSourceProperty(inputSource, kTISPropertyInputSourceID) as? String
        if let sourceID {
            for pattern in phtvNonLatinInputSourcePatterns where sourceID.contains(pattern) {
                return false
            }
        }

        let languages = phtvInputSourceProperty(inputSource, kTISPropertyInputSourceLanguages) as? [String]
        guard let language = languages?.first else {
            return true
        }

        return phtvLatinLanguages.contains(language)
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
