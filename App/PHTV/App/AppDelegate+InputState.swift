//
//  AppDelegate+InputState.swift
//  PHTV
//
//  Input state synchronization.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import AppKit
import Foundation

private let phtvInputStateDefaultsKeyInputMethod = UserDefaultsKey.inputMethod
private let phtvInputStateDefaultsKeyInputType = UserDefaultsKey.inputType
private let phtvInputStateDefaultsKeyCodeTable = UserDefaultsKey.codeTable
private let phtvInputStateNotificationLanguageChangedFromBackend = NotificationName.languageChangedFromBackend

private nonisolated func phtvNotifyInputMethodChangedInBackground() async {
    PHTVManager.notifyInputMethodChanged()
}

private nonisolated func phtvNotifyTableCodeChangedInBackground() async {
    PHTVManager.notifyTableCodeChanged()
}

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
            Task(priority: .utility) {
                await phtvNotifyInputMethodChangedInBackground()
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
            Task(priority: .utility) {
                await phtvNotifyInputMethodChangedInBackground()
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
            Task(priority: .utility) {
                await phtvNotifyInputMethodChangedInBackground()
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
#if DEBUG
            NSLog("[MenuBar] Ignoring input type change (already updating)")
#endif
            return
        }

        let currentInputType = PHTVManager.currentInputType()
        if currentInputType == index {
#if DEBUG
            NSLog("[MenuBar] Input type already at %d, skipping", index)
#endif
            return
        }

#if DEBUG
        NSLog("[MenuBar] CHANGING INPUT TYPE: %d -> %d", currentInputType, index)
#endif

        isUpdatingInputType = true
        defer { isUpdatingInputType = false }

        PHTVManager.setCurrentInputType(index)
        UserDefaults.standard.set(Int(index), forKey: phtvInputStateDefaultsKeyInputType)
        PHTVManager.requestNewSession()
        fillData()

        NotificationCenter.default.post(name: phtvInputStateNotificationLanguageChangedFromBackend,
                                        object: NSNumber(value: PHTVManager.currentLanguage()))

        if PHTVManager.isSmartSwitchKeyEnabled() {
            Task(priority: .utility) {
                await phtvNotifyInputMethodChangedInBackground()
            }
        }

        NSLog("[MenuBar] Input type changed to: %d", index)
    }

    @objc(onCodeTableChanged:)
    func onCodeTableChanged(_ index: Int32) {
        if isUpdatingCodeTable {
#if DEBUG
            NSLog("[MenuBar] Ignoring code table change (already updating)")
#endif
            return
        }

        let currentCodeTable = PHTVManager.currentCodeTable()
        if currentCodeTable == index {
#if DEBUG
            NSLog("[MenuBar] Code table already at %d, skipping", index)
#endif
            return
        }

#if DEBUG
        NSLog("[MenuBar] CHANGING CODE TABLE: %d -> %d", currentCodeTable, index)
#endif

        isUpdatingCodeTable = true
        defer { isUpdatingCodeTable = false }

        PHTVManager.setCurrentCodeTable(index)
        UserDefaults.standard.set(Int(index), forKey: phtvInputStateDefaultsKeyCodeTable)
        PHTVManager.requestNewSession()
        fillData()

        Task(priority: .utility) {
            await phtvNotifyTableCodeChangedInBackground()
        }

        NSLog("[MenuBar] Code table changed to: %d", index)
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
#if DEBUG
        NSLog("[SwiftUI] InputMethodChanged notification received: %d", index)
#endif
        onInputTypeSelectedIndex(index)
    }

    @objc func onCodeTableChangedFromSwiftUI(_ notification: Notification) {
        guard let newCodeTableValue = notification.object as? NSNumber else {
            return
        }

        let index = newCodeTableValue.int32Value
#if DEBUG
        NSLog("[SwiftUI] CodeTableChanged notification received: %d", index)
#endif
        onCodeTableChanged(index)
    }
}
