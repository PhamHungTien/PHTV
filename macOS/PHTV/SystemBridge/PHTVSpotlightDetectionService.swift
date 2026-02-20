//
//  PHTVSpotlightDetectionService.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation
import Darwin
import AppKit
import ApplicationServices

@objcMembers
final class PHTVSpotlightDetectionService: NSObject {
    private static let externalDeleteResetThresholdMs: UInt64 = 30_000
    private static let searchKeywords: [String] = [
        "search",
        "tìm kiếm",
        "tìm",
        "filter",
        "lọc"
    ]

    nonisolated(unsafe) private static var externalDeleteDetected = false
    nonisolated(unsafe) private static var lastExternalDeleteTime: UInt64 = 0
    nonisolated(unsafe) private static var externalDeleteCount = 0

    nonisolated(unsafe) private static var lock = NSLock()

    @objc class func containsSearchKeyword(_ value: String?) -> Bool {
        guard let lower = value?.lowercased(), !lower.isEmpty else {
            return false
        }
        for keyword in searchKeywords where lower.contains(keyword) {
            return true
        }
        return false
    }

    private class func stringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == CFStringGetTypeID() else {
            return nil
        }
        return value as? String
    }

    private class func elementAttribute(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        return (value as! AXUIElement)
    }

    private class func focusedElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        return elementAttribute(systemWide, kAXFocusedUIElementAttribute)
    }

    private class func attributeContainsSearchKeyword(_ element: AXUIElement, _ attribute: String) -> Bool {
        containsSearchKeyword(stringAttribute(element, attribute))
    }

    @objc(isElementSpotlight:bundleId:)
    class func isElementSpotlight(_ element: AXUIElement?, bundleId: String?) -> Bool {
        guard let element else {
            return false
        }

        // Filter out browser address bars.
        if let bundleId, PHTVAppDetectionService.isBrowserApp(bundleId) {
            return false
        }

        guard let role = stringAttribute(element, kAXRoleAttribute) else {
            return false
        }

        if role == "AXSearchField" {
            return true
        }

        if role == "AXTextField" || role == "AXTextArea" {
            return attributeContainsSearchKeyword(element, kAXSubroleAttribute) ||
                attributeContainsSearchKeyword(element, kAXIdentifierAttribute) ||
                attributeContainsSearchKeyword(element, kAXDescriptionAttribute) ||
                attributeContainsSearchKeyword(element, kAXPlaceholderValueAttribute)
        }

        return false
    }

    @objc class func isSafariAddressBar() -> Bool {
        // If cannot detect, assume address bar to preserve existing fallback behavior.
        guard let focused = focusedElement() else {
            return true
        }

        if let role = stringAttribute(focused, kAXRoleAttribute),
           role == "AXTextField" || role == "AXComboBox" || role == "AXSearchField" {
            return true
        }

        var current: AXUIElement? = focused
        for _ in 0..<10 {
            guard let currentElement = current else {
                break
            }
            if stringAttribute(currentElement, kAXRoleAttribute) == "AXWebArea" {
                return false
            }
            current = elementAttribute(currentElement, kAXParentAttribute)
            if current == nil {
                break
            }
        }

        // Not in web content => address bar/search field context.
        return true
    }

    @objc class func isSafariGoogleDocsOrSheets() -> Bool {
        guard let focused = focusedElement() else {
            return false
        }

        var pid: pid_t = 0
        guard AXUIElementGetPid(focused, &pid) == .success, pid != 0 else {
            return false
        }

        let appElement = AXUIElementCreateApplication(pid)
        guard let focusedWindow = elementAttribute(appElement, kAXFocusedWindowAttribute) else {
            return false
        }

        if let url = stringAttribute(focusedWindow, kAXDocumentAttribute),
           (url.contains("docs.google.com/document") ||
            url.contains("docs.google.com/spreadsheets") ||
            url.contains("docs.google.com/presentation") ||
            url.contains("docs.google.com/forms")) {
            return true
        }

        if let title = stringAttribute(focusedWindow, kAXTitleAttribute),
           (title.contains(" - Google Docs") ||
            title.contains(" - Google Sheets") ||
            title.contains(" - Google Slides") ||
            title.contains(" - Google Tài liệu") ||
            title.contains(" - Google Trang tính") ||
            title.contains(" - Google Biểu mẫu")) {
            return true
        }

        return false
    }

    @objc class func trackExternalDelete() {
        let now = mach_absolute_time()
        lock.lock()
        defer { lock.unlock() }

        if lastExternalDeleteTime != 0 {
            let elapsedMs = PHTVTimingService.machTimeToMs(now - lastExternalDeleteTime)
            if elapsedMs > externalDeleteResetThresholdMs {
                externalDeleteCount = 0
            }
        }

        lastExternalDeleteTime = now
        externalDeleteCount += 1
        externalDeleteDetected = true
    }

    @objc class func hasRecentExternalDeletes() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return externalDeleteDetected
    }

    @objc class func externalDeleteCountValue() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return externalDeleteCount
    }

    @objc class func resetExternalDeleteTracking() {
        lock.lock()
        defer { lock.unlock() }
        externalDeleteDetected = false
        lastExternalDeleteTime = 0
        externalDeleteCount = 0
    }
}
