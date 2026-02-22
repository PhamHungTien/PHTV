//
//  AppDelegate+InputState.swift
//  PHTV
//
//  Swift port of AppDelegate+InputState.mm.
//

import AppKit
import Foundation

private let phtvInputStateDefaultsKeyInputMethod = "InputMethod"
private let phtvInputStateDefaultsKeyInputType = "InputType"
private let phtvInputStateDefaultsKeyCodeTable = "CodeTable"
private let phtvInputStateNotificationLanguageChangedFromBackend = Notification.Name("LanguageChangedFromBackend")

@MainActor extension AppDelegate {
    @objc func handleLanguageChangedFromSwiftUI(_ notification: Notification) {
        if isUpdatingLanguage {
#if DEBUG
            NSLog("[SwiftUI] Ignoring language change (already updating)")
#endif
            return
        }

        guard let language = notification.object as? NSNumber else {
            return
        }

        let newLanguage = language.int32Value
        let currentLanguage = PHTVManager.currentLanguage()
        if currentLanguage == newLanguage {
            return
        }

#if DEBUG
        NSLog("[SwiftUI] Language changing from %d to %d", currentLanguage, newLanguage)
        NSLog("========================================")
        NSLog("[SwiftUI] CHANGING LANGUAGE: %d -> %d", currentLanguage, newLanguage)
        NSLog("========================================")
#endif

        isUpdatingLanguage = true
        defer { isUpdatingLanguage = false }

        PHTVManager.setCurrentLanguage(newLanguage)

        if isInExcludedApp {
            savedLanguageBeforeExclusion = Int(newLanguage)
        }

        UserDefaults.standard.set(Int(newLanguage), forKey: phtvInputStateDefaultsKeyInputMethod)
        PHTVManager.requestNewSession()
        fillData()

        if PHTVManager.isSmartSwitchKeyEnabled() {
            Task.detached(priority: .utility) {
                PHTVManager.notifyInputMethodChanged()
            }
        }

        NSLog("[SwiftUI] Language changed to: %d (engine reset complete)", newLanguage)
    }

    @objc func handleInputMethodChanged(_ notification: Notification) {
        if isUpdatingInputType {
#if DEBUG
            NSLog("[SwiftUI] Ignoring input method change (already updating)")
#endif
            return
        }

        guard let inputMethod = notification.object as? NSNumber else {
            return
        }

        let newIndex = inputMethod.int32Value
        let currentInputType = PHTVManager.currentInputType()
        if currentInputType == newIndex {
            return
        }

#if DEBUG
        NSLog("[SwiftUI] Input method changing from %d to %d", currentInputType, newIndex)
        NSLog("========================================")
        NSLog("[SwiftUI] CHANGING INPUT TYPE: %d -> %d", currentInputType, newIndex)
        NSLog("========================================")
#endif

        isUpdatingInputType = true
        defer { isUpdatingInputType = false }

        PHTVManager.setCurrentInputType(newIndex)
        UserDefaults.standard.set(Int(newIndex), forKey: phtvInputStateDefaultsKeyInputType)
        PHTVManager.requestNewSession()
        fillData()

        if PHTVManager.isSmartSwitchKeyEnabled() {
            Task.detached(priority: .utility) {
                PHTVManager.notifyInputMethodChanged()
            }
        }

        NSLog("[SwiftUI] Input method changed to: %d (engine reset complete)", newIndex)
    }

    @objc func handleCodeTableChanged(_ notification: Notification) {
        guard let codeTable = notification.object as? NSNumber else {
            return
        }

        let newIndex = codeTable.int32Value
        onCodeTableChanged(newIndex)
#if DEBUG
        NSLog("[SwiftUI] Code table changed to: %d", newIndex)
#endif
    }

    @objc(onImputMethodChanged:)
    func onImputMethodChanged(_ willNotify: Bool) {
        if isUpdatingLanguage {
#if DEBUG
            NSLog("[MenuBar] Ignoring language change (already updating)")
#endif
            return
        }

        let currentLanguage = PHTVManager.currentLanguage()
        let targetLanguage: Int32 = (currentLanguage == 0) ? 1 : 0
        if currentLanguage == targetLanguage {
#if DEBUG
            NSLog("[MenuBar] Language already at %d, skipping", currentLanguage)
#endif
            return
        }

#if DEBUG
        NSLog("[MenuBar] Language changing from %d to %d", currentLanguage, targetLanguage)
        NSLog("========================================")
        NSLog("[MenuBar] TOGGLING LANGUAGE: %d -> %d", currentLanguage, targetLanguage)
        NSLog("========================================")
#endif

        isUpdatingLanguage = true
        defer { isUpdatingLanguage = false }

        PHTVManager.setCurrentLanguage(targetLanguage)

        if isInExcludedApp {
            savedLanguageBeforeExclusion = Int(targetLanguage)
        }

        UserDefaults.standard.set(Int(targetLanguage), forKey: phtvInputStateDefaultsKeyInputMethod)
        PHTVManager.requestNewSession()
        fillData()

        NotificationCenter.default.post(name: phtvInputStateNotificationLanguageChangedFromBackend,
                                        object: NSNumber(value: targetLanguage))

        if willNotify && PHTVManager.isSmartSwitchKeyEnabled() {
            Task.detached(priority: .utility) {
                PHTVManager.notifyInputMethodChanged()
            }
        }

#if DEBUG
        NSLog("[MenuBar] Language changed to: %d (engine reset complete)", targetLanguage)
#endif
    }

    @objc func onInputMethodSelected() {
        onImputMethodChanged(true)
    }

    @objc func onInputTypeSelected(_ sender: Any?) {
        guard let menuItem = sender as? NSMenuItem else {
            return
        }
        onInputTypeSelectedIndex(Int32(menuItem.tag))
    }

    @objc(onInputTypeSelectedIndex:)
    func onInputTypeSelectedIndex(_ index: Int32) {
        if isUpdatingInputType {
            NSLog("[MenuBar] Ignoring input type change (already updating)")
            return
        }

        let currentInputType = PHTVManager.currentInputType()
        if currentInputType == index {
            NSLog("[MenuBar] Input type already at %d, skipping", index)
            return
        }

        NSLog("[MenuBar] Input type changing from %d to %d", currentInputType, index)
        NSLog("========================================")
        NSLog("[MenuBar] CHANGING INPUT TYPE: %d -> %d", currentInputType, index)
        NSLog("========================================")

        isUpdatingInputType = true
        defer { isUpdatingInputType = false }

        PHTVManager.setCurrentInputType(index)
        UserDefaults.standard.set(Int(index), forKey: phtvInputStateDefaultsKeyInputType)
        PHTVManager.requestNewSession()
        fillData()

        NotificationCenter.default.post(name: phtvInputStateNotificationLanguageChangedFromBackend,
                                        object: NSNumber(value: PHTVManager.currentLanguage()))

        if PHTVManager.isSmartSwitchKeyEnabled() {
            Task.detached(priority: .utility) {
                PHTVManager.notifyInputMethodChanged()
            }
        }

        NSLog("[MenuBar] Input type changed to: %d (engine reset complete)", index)
    }

    @objc(onCodeTableChanged:)
    func onCodeTableChanged(_ index: Int32) {
        if isUpdatingCodeTable {
            NSLog("[MenuBar] Ignoring code table change (already updating)")
            return
        }

        let currentCodeTable = PHTVManager.currentCodeTable()
        if currentCodeTable == index {
            NSLog("[MenuBar] Code table already at %d, skipping", index)
            return
        }

        NSLog("[MenuBar] Code table changing from %d to %d", currentCodeTable, index)
        NSLog("========================================")
        NSLog("[MenuBar] CHANGING CODE TABLE: %d -> %d", currentCodeTable, index)
        NSLog("========================================")

        isUpdatingCodeTable = true
        defer { isUpdatingCodeTable = false }

        PHTVManager.setCurrentCodeTable(index)
        UserDefaults.standard.set(Int(index), forKey: phtvInputStateDefaultsKeyCodeTable)
        PHTVManager.requestNewSession()
        fillData()

        Task.detached(priority: .utility) {
            PHTVManager.notifyTableCodeChanged()
        }

        NSLog("[MenuBar] Code table changed to: %d (engine reset complete)", index)
    }

    @objc func onCodeSelected(_ sender: Any?) {
        guard let menuItem = sender as? NSMenuItem else {
            return
        }
        onCodeTableChanged(Int32(menuItem.tag))
    }

    @objc func onInputMethodChangedFromSwiftUI(_ notification: Notification) {
        guard let newInputMethodValue = notification.object as? NSNumber else {
            return
        }

        let index = newInputMethodValue.int32Value
        NSLog("[SwiftUI] InputMethodChanged notification received: %d", index)
        onInputTypeSelectedIndex(index)
    }

    @objc func onCodeTableChangedFromSwiftUI(_ notification: Notification) {
        guard let newCodeTableValue = notification.object as? NSNumber else {
            return
        }

        let index = newCodeTableValue.int32Value
        NSLog("[SwiftUI] CodeTableChanged notification received: %d", index)
        onCodeTableChanged(index)
    }
}
