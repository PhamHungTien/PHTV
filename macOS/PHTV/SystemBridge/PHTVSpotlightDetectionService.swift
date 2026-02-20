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
import Carbon

@objcMembers
final class PHTVSpotlightDetectionService: NSObject {
    private static let spotlightForceRecheckAfterInvalidationMs: UInt64 = 100
    private static let spotlightCacheDurationMs: UInt64 = 150
    private static let spotlightInvalidationDedupMs: UInt64 = 30
    private static let spotlightBundleId = "com.apple.Spotlight"

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
    nonisolated(unsafe) private static var lastEventFlags: CGEventFlags = []

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

    @objc class func isSpotlightActive() -> Bool {
        let now = mach_absolute_time()

        var cachedResult = PHTVCacheStateService.cachedSpotlightActive()
        var lastCheck = PHTVCacheStateService.lastSpotlightCheckTime()
        let lastInvalidation = PHTVCacheStateService.lastSpotlightInvalidationTime()

        var elapsedMs = PHTVTimingService.machTimeToMs(now - lastCheck)
        let elapsedSinceInvalidationMs = lastInvalidation > 0
            ? PHTVTimingService.machTimeToMs(now - lastInvalidation)
            : UInt64.max

        // Skip cache immediately after invalidation to avoid stale transitions.
        if elapsedSinceInvalidationMs < spotlightForceRecheckAfterInvalidationMs {
            lastCheck = 0
            elapsedMs = UInt64.max
        }

        // Prevent stale YES if previous cache came from browser address bar.
        if lastCheck > 0 && cachedResult {
            let cachedBundleId = PHTVCacheStateService.cachedFocusedBundleId()
            if cachedBundleId != nil && PHTVAppDetectionService.isBrowserApp(cachedBundleId) {
                _ = PHTVCacheStateService.invalidateSpotlightCache(dedupWindowMs: spotlightInvalidationDedupMs)
                lastCheck = 0
                elapsedMs = UInt64.max
                cachedResult = false
            }
        }

        if elapsedMs < spotlightCacheDurationMs && lastCheck > 0 {
            return cachedResult
        }

        guard let focusedElement = focusedElement() else {
            PHTVCacheStateService.updateSpotlightCache(false, pid: 0, bundleId: nil)
            return false
        }

        var focusedPID: pid_t = 0
        guard AXUIElementGetPid(focusedElement, &focusedPID) == .success, focusedPID != 0 else {
            PHTVCacheStateService.updateSpotlightCache(false, pid: 0, bundleId: nil)
            return false
        }

        let bundleId = PHTVCacheStateService.bundleIdFromPID(Int32(focusedPID), safeMode: false)

        if let bundleId, bundleId == Bundle.main.bundleIdentifier {
            PHTVCacheStateService.updateSpotlightCache(false, pid: Int32(focusedPID), bundleId: bundleId)
            return false
        }

        let elementLooksLikeSearchField = isElementSpotlight(focusedElement, bundleId: bundleId)
        if elementLooksLikeSearchField {
            if !cachedResult {
                NSLog("[Spotlight] ✅ DETECTED: bundleId=%@, pid=%d", bundleId ?? "(nil)", Int32(focusedPID))
            }
            PHTVCacheStateService.updateSpotlightCache(true, pid: Int32(focusedPID), bundleId: bundleId)
            return true
        }

        if let bundleId,
           bundleId == spotlightBundleId || bundleId.hasPrefix(spotlightBundleId) {
            if !cachedResult {
                NSLog("[Spotlight] ✅ DETECTED (by bundleId): bundleId=%@, pid=%d", bundleId, Int32(focusedPID))
            }
            PHTVCacheStateService.updateSpotlightCache(true, pid: Int32(focusedPID), bundleId: bundleId)
            return true
        }

        if bundleId == nil {
            // Equivalent to PROC_PIDPATHINFO_MAXSIZE (4 * MAXPATHLEN) in libproc.
            let procPidPathBufferSize = 4096
            var pathBuffer = [CChar](repeating: 0, count: procPidPathBufferSize)
            if proc_pidpath(focusedPID, &pathBuffer, UInt32(pathBuffer.count)) > 0 {
                let path = String(cString: pathBuffer)
                if path.contains("Spotlight") {
                    if !cachedResult {
                        NSLog("[Spotlight] ✅ DETECTED (by path): path=%@, pid=%d", path, Int32(focusedPID))
                    }
                    PHTVCacheStateService.updateSpotlightCache(true, pid: Int32(focusedPID), bundleId: spotlightBundleId)
                    return true
                }
            }
        }

        if cachedResult {
            NSLog("[Spotlight] ❌ LOST: now focused on bundleId=%@, pid=%d", bundleId ?? "(nil)", Int32(focusedPID))
        }
        PHTVCacheStateService.updateSpotlightCache(false, pid: Int32(focusedPID), bundleId: bundleId)
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

    @objc(handleSpotlightCacheInvalidation:keycode:flags:)
    class func handleSpotlightCacheInvalidation(_ type: CGEventType, keycode: CGKeyCode, flags: CGEventFlags) {
        let isCmdSpace = (type == .keyDown &&
                          keycode == CGKeyCode(kVK_Space) &&
                          flags.contains(.maskCommand))
        if isCmdSpace {
            invalidateSpotlightCache()
            return
        }

        if type == .keyDown && keycode == CGKeyCode(kVK_Escape) {
            if PHTVCacheStateService.cachedSpotlightActive() {
                invalidateSpotlightCache()
            }
            return
        }

        if type == .leftMouseDown || type == .rightMouseDown {
            if PHTVCacheStateService.cachedSpotlightActive() {
                invalidateSpotlightCache()
            }
        }

        let flagChangeMask = CGEventFlags.maskCommand.rawValue
        if type == .flagsChanged &&
           ((flags.rawValue ^ lastEventFlags.rawValue) & flagChangeMask) != 0 {
            invalidateSpotlightCache()
        }
        lastEventFlags = flags
    }

    private class func invalidateSpotlightCache() {
        let status = PHTVCacheStateService.invalidateSpotlightCache(dedupWindowMs: spotlightInvalidationDedupMs)
#if DEBUG
        if status == 2 {
            NSLog("[Spotlight] 🔄 CACHE INVALIDATED (was active)")
        }
#endif
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
