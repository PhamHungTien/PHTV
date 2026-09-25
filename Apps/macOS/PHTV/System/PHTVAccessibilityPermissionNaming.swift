//
//  PHTVAccessibilityPermissionNaming.swift
//  PHTV
//
//  User-facing name for the macOS Accessibility privacy permission.
//

import Foundation

enum PHTVAccessibilityPermissionNaming {
    static var displayName: String {
        displayName(operatingSystemVersion: ProcessInfo.processInfo.operatingSystemVersion)
    }

    static func displayName(operatingSystemVersion: OperatingSystemVersion) -> String {
        operatingSystemVersion.majorVersion >= 27
            ? "Device Control and Data Access"
            : "Trợ năng"
    }
}
