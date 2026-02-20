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
        let listenGranted = PHTVPermissionService.hasListenEventAccess()
        let postGranted = PHTVPermissionService.hasPostEventAccess()

        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let lastVersion = UserDefaults.standard.string(forKey: phtvDefaultsKeyLastRunVersion)

        if let lastVersion, !lastVersion.isEmpty, lastVersion != currentVersion {
            alert.messageText = "PHTV đã được cập nhật!"
            alert.informativeText = "Do macOS yêu cầu bảo mật, bạn cần cấp lại quyền sau khi cập nhật lên phiên bản \(currentVersion).\n\nPHTV cần:\n- Accessibility (Trợ năng)\n- Input Monitoring (Giám sát nhập liệu)\n\nỨng dụng sẽ tự động khởi động lại sau khi bạn cấp quyền."
        } else {
            alert.messageText = "PHTV cần bạn cấp quyền để có thể hoạt động!"
            alert.informativeText = "PHTV cần:\n- Accessibility (Trợ năng)\n- Input Monitoring (Giám sát nhập liệu)\n\nỨng dụng sẽ tự động khởi động lại sau khi bạn cấp quyền."
        }

        alert.addButton(withTitle: "Đóng")
        alert.addButton(withTitle: "Mở cài đặt quyền")

        alert.window.makeKeyAndOrderFront(nil)
        alert.window.level = .statusBar

        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            if !listenGranted {
                _ = PHTVPermissionService.requestListenEventAccess()
            }
            if !postGranted {
                _ = PHTVPermissionService.requestPostEventAccess()
            }

            PHTVAccessibilityService.openAccessibilityPreferences()
            PHTVAccessibilityService.openInputMonitoringPreferences()

            PHTVManager.invalidatePermissionCache()
            NSLog("[Accessibility] User opening System Settings - cache invalidated")

            UserDefaults.standard.set(currentVersion, forKey: phtvDefaultsKeyLastRunVersion)
        } else {
            NSApp.terminate(nil)
        }
    }
}
