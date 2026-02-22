//
//  AppDelegate+Defaults.swift
//  PHTV
//
//  Swift port of AppDelegate+Defaults.mm.
//

import Foundation

@MainActor @objc extension AppDelegate {
    func loadDefaultConfig() {
        PHTVManager.loadDefaultConfig()
        fillData()
    }

    func setGrayIcon(_ val: Bool) {
        _ = val
        fillData()
    }
}
