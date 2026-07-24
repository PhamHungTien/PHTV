//
//  AppDelegate+StatusBarMenu.swift
//  PHTV
//
//  Legacy NSStatusItem implementation has been retired.
//  Menu bar UI is now fully owned by SwiftUI MenuBarExtra, but some
//  Objective-C-era runtime paths still call these selectors to request a UI
//  refresh after backend state changes.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
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
        // Defer refreshFromRuntime to avoid blocking mode switches and other time-sensitive operations.
        // This prevents UI freezes when user switches Vietnamese/English modes by allowing the mode switch
        // to complete immediately while the expensive state reload happens asynchronously.
        // Using DispatchQueue.main.async ensures the reload runs on the main thread but after current operations.
        DispatchQueue.main.async {
            AppState.shared.refreshFromRuntime()
        }
    }

    @objc(fillDataWithAnimation:)
    func fillData(withAnimation animated: Bool) {
        _ = animated
        // Defer refreshFromRuntime to avoid blocking mode switches and other time-sensitive operations.
        // This prevents UI freezes when user switches Vietnamese/English modes by allowing the mode switch
        // to complete immediately while the expensive state reload happens asynchronously.
        DispatchQueue.main.async {
            AppState.shared.refreshFromRuntime()
        }
    }
}
