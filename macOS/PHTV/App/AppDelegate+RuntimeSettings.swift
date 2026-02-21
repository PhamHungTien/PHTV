//
//  AppDelegate+RuntimeSettings.swift
//  PHTV
//
//  Swift port of AppDelegate+RuntimeSettings.mm.
//

import Foundation

@MainActor @objc extension AppDelegate {
    func loadRuntimeSettingsFromUserDefaults() {
        lastSettingsChangeToken = PHTVManager.loadRuntimeSettingsFromUserDefaults()
    }
}
