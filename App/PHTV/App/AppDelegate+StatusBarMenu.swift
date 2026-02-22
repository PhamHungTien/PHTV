//
//  AppDelegate+StatusBarMenu.swift
//  PHTV
//
//  Legacy NSStatusItem implementation has been retired.
//  Menu bar UI is now fully owned by SwiftUI MenuBarExtra.
//

import Foundation

@MainActor @objc extension AppDelegate {
    func createStatusBarMenu() {
        // Retained for backward compatibility with legacy call sites.
    }

    func setQuickConvertString() {
        // Retained for backward compatibility with legacy call sites.
    }

    func fillData() {
        // Retained for backward compatibility with legacy call sites.
    }

    @objc(fillDataWithAnimation:)
    func fillData(withAnimation animated: Bool) {
        _ = animated
        // Retained for backward compatibility with legacy call sites.
    }
}
