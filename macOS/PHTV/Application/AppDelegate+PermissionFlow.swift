//
//  AppDelegate+PermissionFlow.swift
//  PHTV
//
//  Swift port of AppDelegate+PermissionFlow.mm.
//

import AppKit
import Foundation

private let phtvDefaultsKeyLastRunVersion = "LastRunVersion"

@MainActor @objc extension AppDelegate {
    func askPermission() {
        let alert = NSAlert()

        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let lastVersion = UserDefaults.standard.string(forKey: phtvDefaultsKeyLastRunVersion)

        if let lastVersion, !lastVersion.isEmpty, lastVersion != currentVersion {
            alert.messageText = "PHTV đã được cập nhật!"
            alert.informativeText = "Do macOS yêu cầu bảo mật, bạn cần cấp lại quyền trợ năng sau khi cập nhật ứng dụng lên phiên bản \(currentVersion).\n\nỨng dụng sẽ tự động khởi động lại sau khi bạn cấp quyền."
        } else {
            alert.messageText = "PHTV cần bạn cấp quyền để có thể hoạt động!"
            alert.informativeText = "Ứng dụng sẽ tự động khởi động lại sau khi bạn cấp quyền."
        }

        alert.addButton(withTitle: "Không")
        alert.addButton(withTitle: "Cấp quyền")

        alert.window.makeKeyAndOrderFront(nil)
        alert.window.level = .statusBar

        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            PHTVAccessibilityService.openAccessibilityPreferences()

            PHTVManager.invalidatePermissionCache()
            NSLog("[Accessibility] User opening System Settings - cache invalidated")

            UserDefaults.standard.set(currentVersion, forKey: phtvDefaultsKeyLastRunVersion)
        } else {
            NSApp.terminate(nil)
        }
    }
}
