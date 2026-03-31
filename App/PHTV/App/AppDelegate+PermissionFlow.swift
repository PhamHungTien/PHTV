//
//  AppDelegate+PermissionFlow.swift
//  PHTV
//
//  Permission request and recovery flow.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import AppKit
import ApplicationServices
import Foundation

private let phtvDefaultsKeyLastRunVersion = "LastRunVersion"

@MainActor @objc extension AppDelegate {
    func askPermission() {
        let alert = NSAlert()
        let accessibilityGranted = AXIsProcessTrusted()
        let listenGranted = PHTVPermissionService.hasListenEventAccess()
        let postGranted = PHTVPermissionService.hasPostEventAccess()
        let needsAccessibilityPermission = !accessibilityGranted || !postGranted
        let needsInputMonitoringPermission = !listenGranted

        var requiredPermissions: [String] = []
        if needsAccessibilityPermission {
            requiredPermissions.append("Accessibility (Trợ năng)")
        }
        if needsInputMonitoringPermission {
            requiredPermissions.append("Input Monitoring (Giám sát nhập liệu)")
        }
        if requiredPermissions.isEmpty {
            requiredPermissions = [
                "Accessibility (Trợ năng)",
                "Input Monitoring (Giám sát nhập liệu)"
            ]
        }
        let permissionList = requiredPermissions.map { "- \($0)" }.joined(separator: "\n")

        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let lastVersion = UserDefaults.standard.string(forKey: phtvDefaultsKeyLastRunVersion)

        if let lastVersion, !lastVersion.isEmpty, lastVersion != currentVersion {
            alert.messageText = "PHTV đã được cập nhật!"
            alert.informativeText = "Do macOS yêu cầu bảo mật, bạn cần cấp lại quyền sau khi cập nhật lên phiên bản \(currentVersion).\n\nPHTV cần:\n\(permissionList)\n\nỨng dụng sẽ tự động khởi động lại sau khi bạn cấp quyền."
        } else {
            alert.messageText = "PHTV cần bạn cấp quyền để có thể hoạt động!"
            alert.informativeText = "PHTV cần:\n\(permissionList)\n\nỨng dụng sẽ tự động khởi động lại sau khi bạn cấp quyền."
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

            if needsAccessibilityPermission {
                PHTVAccessibilityService.openAccessibilityPreferences()
            } else if needsInputMonitoringPermission {
                PHTVPermissionService.openInputMonitoringPreferences()
            }

            PHTVManager.invalidatePermissionCache()
            NSLog("[Accessibility] User opening System Settings - cache invalidated")

            UserDefaults.standard.set(currentVersion, forKey: phtvDefaultsKeyLastRunVersion)
        } else {
            NSApp.terminate(nil)
        }
    }
}
