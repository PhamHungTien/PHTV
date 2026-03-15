//
//  AppDelegate+StatusBarMenu.swift
//  PHTV
//
//  Legacy NSStatusItem implementation has been retired.
//  Menu bar UI is now fully owned by SwiftUI MenuBarExtra, but some
//  Objective-C-era runtime paths still call these selectors to request a UI
//  refresh after backend state changes.
//

import Foundation

@MainActor @objc extension AppDelegate {
    func createStatusBarMenu() {
        AppState.shared.refreshFromRuntime()
    }

    func setQuickConvertString() {
        AppState.shared.refreshFromRuntime()
    }

    func fillData() {
        AppState.shared.refreshFromRuntime()
    }

    @objc(fillDataWithAnimation:)
    func fillData(withAnimation animated: Bool) {
        _ = animated
        AppState.shared.refreshFromRuntime()
    }
}
