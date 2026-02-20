//
//  PHTVAccessibilityService.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation
import AppKit
import ApplicationServices
import Darwin

@objcMembers
final class PHTVAccessibilityService: NSObject {
    nonisolated(unsafe) private static var terminalCacheLock = NSLock()
    nonisolated(unsafe) private static var lastTerminalPanelResult = false
    nonisolated(unsafe) private static var lastTerminalPanelCheckTime: UInt64 = 0
    nonisolated(unsafe) private static var addressBarCacheLock = NSLock()
    nonisolated(unsafe) private static var lastAddressBarResult = false
    nonisolated(unsafe) private static var lastAddressBarCheckTime: UInt64 = 0

    @objc(stringEqualCanonicalForAX:rhs:)
    class func stringEqualCanonicalForAX(_ lhs: String?, rhs: String?) -> Bool {
        if lhs == rhs {
            return true
        }
        guard let lhs, let rhs else {
            return false
        }
        if lhs == rhs {
            return true
        }
        if lhs.precomposedStringWithCanonicalMapping == rhs.precomposedStringWithCanonicalMapping {
            return true
        }
        return lhs.decomposedStringWithCanonicalMapping == rhs.decomposedStringWithCanonicalMapping
    }

    @objc(stringHasCanonicalPrefixForAX:prefix:)
    class func stringHasCanonicalPrefixForAX(_ value: String?, prefix: String?) -> Bool {
        guard let value, let prefix else {
            return false
        }
        if value.hasPrefix(prefix) {
            return true
        }
        if value.precomposedStringWithCanonicalMapping.hasPrefix(prefix.precomposedStringWithCanonicalMapping) {
            return true
        }
        return value.decomposedStringWithCanonicalMapping.hasPrefix(prefix.decomposedStringWithCanonicalMapping)
    }

    @objc(calculateDeleteStartForAX:caretLocation:backspaceCount:)
    class func calculateDeleteStartForAX(_ value: String?, caretLocation: Int, backspaceCount: Int) -> Int {
        guard let value else {
            return max(0, caretLocation)
        }
        if backspaceCount <= 0 {
            return caretLocation
        }

        let valueNSString = value as NSString
        var start = caretLocation - backspaceCount
        if start < 0 {
            start = 0
        }

        if start < caretLocation && caretLocation <= valueNSString.length {
            let textToDelete = valueNSString.substring(with: NSRange(location: start, length: caretLocation - start))
            let composedLen = (textToDelete.precomposedStringWithCanonicalMapping as NSString).length
            if composedLen != backspaceCount && composedLen > 0 {
                var actualStart = caretLocation
                var composedCount = 0
                while actualStart > 0 && composedCount < backspaceCount {
                    actualStart -= 1
                    let c = valueNSString.character(at: actualStart)
                    if !isCombiningMark(c) {
                        composedCount += 1
                    }
                }
                start = actualStart
            }
        }

        return start
    }

    private class func isCombiningMark(_ scalar: unichar) -> Bool {
        (scalar >= 0x0300 && scalar <= 0x036F) ||
        (scalar >= 0x1DC0 && scalar <= 0x1DFF) ||
        (scalar >= 0x20D0 && scalar <= 0x20FF) ||
        (scalar >= 0xFE20 && scalar <= 0xFE2F)
    }

    private class func stringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }

    private class func elementAttribute(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let raw = value else {
            return nil
        }
        guard CFGetTypeID(raw) == AXUIElementGetTypeID() else {
            return nil
        }
        return (raw as! AXUIElement)
    }

    private class func focusedElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        return elementAttribute(systemWide, kAXFocusedUIElementAttribute)
    }

    private class func focusedWindowTitleForFrontmostApp() -> String? {
        guard let frontmost = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let appElement = AXUIElementCreateApplication(frontmost.processIdentifier)
        guard let focusedWindow = elementAttribute(appElement, kAXFocusedWindowAttribute) else {
            return nil
        }

        return stringAttribute(focusedWindow, kAXTitleAttribute)
    }

    private class func focusedAppBundleId() -> String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    private class func containsAddressBarKeyword(_ value: String?) -> Bool {
        guard let value else {
            return false
        }
        let keywords = ["Address", "Omnibox", "Location", "URL", "Search", "Địa chỉ", "Tìm kiếm"]
        for keyword in keywords {
            if value.range(of: keyword, options: .caseInsensitive) != nil {
                return true
            }
        }
        return false
    }

    private class func readAddressBarCache() -> (result: Bool, checkTime: UInt64) {
        addressBarCacheLock.lock()
        let result = lastAddressBarResult
        let checkTime = lastAddressBarCheckTime
        addressBarCacheLock.unlock()
        return (result, checkTime)
    }

    private class func writeAddressBarCache(result: Bool, checkTime: UInt64) {
        addressBarCacheLock.lock()
        lastAddressBarResult = result
        lastAddressBarCheckTime = checkTime
        addressBarCacheLock.unlock()
    }

    @objc class func invalidateAddressBarCache() {
        writeAddressBarCache(result: false, checkTime: 0)
    }

    @objc class func isFocusedElementAddressBar() -> Bool {
        let now = mach_absolute_time()
        let cache = readAddressBarCache()
        let elapsedMs = PHTVTimingService.machTimeToMs(now - cache.checkTime)

        // Cache valid for 500ms
        if cache.checkTime > 0 && elapsedMs < 500 {
            return cache.result
        }

        var isAddressBar = true // Default to YES (Address Bar) for safety

        guard let focused = focusedElement() else {
            // AX failed: use recent cached result, otherwise safe default.
            if cache.checkTime > 0 && elapsedMs < 2000 {
                isAddressBar = cache.result
            } else {
                isAddressBar = true
            }
            writeAddressBarCache(result: isAddressBar, checkTime: now)
            return isAddressBar
        }

        // Strategy 1: role-based identification
        if let role = stringAttribute(focused, kAXRoleAttribute),
           role == "AXTextField" || role == "AXSearchField" || role == "AXComboBox" {
            writeAddressBarCache(result: true, checkTime: now)
            return true
        }

        // Strategy 2: positive keyword match
        let attributesToCheck: [String] = [
            kAXTitleAttribute,
            kAXDescriptionAttribute,
            kAXRoleDescriptionAttribute,
            "AXIdentifier"
        ]

        var positiveMatch = false
        for attr in attributesToCheck {
            if containsAddressBarKeyword(stringAttribute(focused, attr)) {
                positiveMatch = true
                break
            }
        }

        if positiveMatch {
            isAddressBar = true
        } else {
            // Strategy 3: negative identification via parent hierarchy
            var foundWebArea = false
            var current: AXUIElement? = focused

            // Walk up to 12 levels to find AXWebArea
            for _ in 0..<12 {
                guard let currentElement = current,
                      let parent = elementAttribute(currentElement, kAXParentAttribute) else {
                    break
                }

                if stringAttribute(parent, kAXRoleAttribute) == "AXWebArea" {
                    foundWebArea = true
                    break
                }
                current = parent
            }

            isAddressBar = !foundWebArea
        }

        writeAddressBarCache(result: isAddressBar, checkTime: now)
        return isAddressBar
    }

    @objc class func isNotionCodeBlock() -> Bool {
        guard let focused = focusedElement() else {
            return false
        }

        let attributes: [String] = [
            kAXRoleDescriptionAttribute,
            kAXDescriptionAttribute,
            kAXHelpAttribute
        ]

        for attr in attributes {
            if let value = stringAttribute(focused, attr),
               value.range(of: "code", options: String.CompareOptions.caseInsensitive) != nil {
                return true
            }
        }

        guard let parent = elementAttribute(focused, kAXParentAttribute) else {
            return false
        }

        for attr in attributes {
            if let value = stringAttribute(parent, attr),
               value.range(of: "code", options: String.CompareOptions.caseInsensitive) != nil {
                return true
            }
        }

        return false
    }

    @objc class func isTerminalPanelFocused() -> Bool {
        let now = mach_absolute_time()
        terminalCacheLock.lock()
        let cachedTime = lastTerminalPanelCheckTime
        if cachedTime != 0,
           PHTVTimingService.machTimeToMs(now - cachedTime) < 50 {
            let cachedResult = lastTerminalPanelResult
            terminalCacheLock.unlock()
            return cachedResult
        }
        terminalCacheLock.unlock()

        var isTerminalPanel = false
        if let focused = focusedElement() {
            let attributes: [String] = [
                kAXDescriptionAttribute,
                kAXRoleDescriptionAttribute,
                kAXHelpAttribute,
                kAXTitleAttribute,
                "AXIdentifier",
                kAXRoleAttribute,
                kAXSubroleAttribute
            ]

            let bundleId = focusedAppBundleId()
            let isIDE = PHTVAppDetectionService.isIDEApp(bundleId)
            let windowTitle = isIDE ? focusedWindowTitleForFrontmostApp() : nil

            var current: AXUIElement? = focused
            for _ in 0..<8 {
                guard let currentElement = current else {
                    break
                }
                for attr in attributes {
                    if let value = stringAttribute(currentElement, attr) {
                        if PHTVAppDetectionService.containsTerminalKeyword(value) {
                            isTerminalPanel = true
                            break
                        }
                        if isIDE && !isTerminalPanel &&
                            (value == "AXTextArea" || value == "AXGroup" || value == "AXScrollArea") &&
                            PHTVAppDetectionService.containsTerminalKeyword(windowTitle) {
                            isTerminalPanel = true
                            break
                        }
                    }
                }
                if isTerminalPanel {
                    break
                }
                current = elementAttribute(currentElement, kAXParentAttribute)
                if current == nil {
                    break
                }
            }

            if !isTerminalPanel,
               isIDE,
               PHTVAppDetectionService.containsTerminalKeyword(windowTitle) {
                isTerminalPanel = true
            }
        }

        terminalCacheLock.lock()
        lastTerminalPanelResult = isTerminalPanel
        lastTerminalPanelCheckTime = now
        terminalCacheLock.unlock()
        return isTerminalPanel
    }
}
