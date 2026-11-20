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

    /// macOS 27.3 asks which apps to control before granting this pane.
    static var asksWhichAppsToControl: Bool {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return version.majorVersion > 27 || (version.majorVersion == 27 && version.minorVersion >= 3)
    }

    /// macOS 27.0–27.2 call the pane "Device Control and Data Access";
    /// macOS 27.3 splits it and lists keyboard tools under
    /// "System & App Protection Override".
    static func displayName(operatingSystemVersion: OperatingSystemVersion) -> String {
        let version = operatingSystemVersion
        if version.majorVersion > 27 || (version.majorVersion == 27 && version.minorVersion >= 3) {
            return "System & App Protection Override"
        }
        return version.majorVersion == 27 ? "Device Control and Data Access" : "Trợ năng"
    }
}
