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
    nonisolated(unsafe) private static var notionCodeBlockCacheLock = NSLock()
    nonisolated(unsafe) private static var lastNotionCodeBlockResult = false
    nonisolated(unsafe) private static var lastNotionCodeBlockCheckTime: UInt64 = 0

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

    @objc(replaceFocusedTextViaAX:insertText:)
    class func replaceFocusedTextViaAX(_ backspaceCount: Int, insertText: String?) -> Bool {
        replaceFocusedTextViaAX(backspaceCount, insertText: insertText, verify: false)
    }

    @objc(replaceFocusedTextViaAX:insertText:verify:)
    class func replaceFocusedTextViaAX(_ backspaceCount: Int, insertText: String?, verify: Bool) -> Bool {
        let clampedBackspace = max(0, backspaceCount)
        let textToInsert = insertText ?? ""

        let systemWide = AXUIElementCreateSystemWide()
        guard let focusedElement = elementAttribute(systemWide, kAXFocusedUIElementAttribute) else {
            return false
        }

        // Read current value
        var valueRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focusedElement, kAXValueAttribute as CFString, &valueRef) == .success else {
            return false
        }
        let valueStr: String
        if let valueRef,
           CFGetTypeID(valueRef) == CFStringGetTypeID(),
           let casted = valueRef as? String {
            valueStr = casted
        } else {
            valueStr = ""
        }
        let valueNSString = valueStr as NSString
        let valueLength = valueNSString.length

        // Read caret position and selected text range
        var caretLocation = valueLength
        var selectedLength = 0
        var rangeRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(focusedElement, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success,
           let rangeRef,
           CFGetTypeID(rangeRef) == AXValueGetTypeID() {
            var sel = CFRange()
            if AXValueGetValue((rangeRef as! AXValue), .cfRange, &sel) {
                caretLocation = sel.location
                selectedLength = sel.length
            }
        }

        // Clamp
        if caretLocation < 0 {
            caretLocation = 0
        }
        if caretLocation > valueLength {
            caretLocation = valueLength
        }

        // Calculate replacement position
        var start = caretLocation
        var len = 0
        let selectionAtEnd = selectedLength > 0 && (caretLocation + selectedLength == valueLength)

        if selectedLength > 0 && !selectionAtEnd {
            // User has highlighted text in-place: replace selected range only.
            start = caretLocation
            len = selectedLength
        } else {
            // No selection or Spotlight autocomplete suffix selection.
            let deleteStart = calculateDeleteStartForAX(
                valueStr,
                caretLocation: caretLocation,
                backspaceCount: clampedBackspace
            )
            if selectionAtEnd {
                start = deleteStart
                len = (caretLocation - deleteStart) + selectedLength
            } else {
                start = deleteStart
                len = caretLocation - deleteStart
            }
        }

        // Clamp length to valid range
        if start + len > valueLength {
            len = valueLength - start
        }
        if len < 0 {
            len = 0
        }

        let newValue = valueNSString.replacingCharacters(in: NSRange(location: start, length: len), with: textToInsert)

        // Write new value
        let writeError = AXUIElementSetAttributeValue(focusedElement, kAXValueAttribute as CFString, newValue as CFTypeRef)
        guard writeError == .success else {
            return false
        }

        // Set caret position
        let newCaret = start + (textToInsert as NSString).length
        var newSel = CFRange(location: newCaret, length: 0)
        if let newRange = AXValueCreate(.cfRange, &newSel) {
            _ = AXUIElementSetAttributeValue(focusedElement, kAXSelectedTextRangeAttribute as CFString, newRange)
        }

        guard verify else {
            return true
        }

        // Verify value changed (some apps may apply AXValue asynchronously)
        for attempt in 0..<2 {
            var verifyValueRef: CFTypeRef?
            let verifyError = AXUIElementCopyAttributeValue(focusedElement, kAXValueAttribute as CFString, &verifyValueRef)
            let verifyStr: String
            if verifyError == .success,
               let verifyValueRef,
               CFGetTypeID(verifyValueRef) == CFStringGetTypeID(),
               let casted = verifyValueRef as? String {
                verifyStr = casted
            } else {
                verifyStr = ""
            }

            if verifyError == .success {
                if stringEqualCanonicalForAX(verifyStr, rhs: newValue) {
                    return true
                }
                if selectionAtEnd && stringHasCanonicalPrefixForAX(verifyStr, prefix: newValue) {
                    return true
                }
            }
            if attempt == 0 {
                usleep(2000)
            }
        }

        return false
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

    private class func readNotionCodeBlockCache() -> (result: Bool, checkTime: UInt64) {
        notionCodeBlockCacheLock.lock()
        let result = lastNotionCodeBlockResult
        let checkTime = lastNotionCodeBlockCheckTime
        notionCodeBlockCacheLock.unlock()
        return (result, checkTime)
    }

    private class func writeNotionCodeBlockCache(result: Bool, checkTime: UInt64) {
        notionCodeBlockCacheLock.lock()
        lastNotionCodeBlockResult = result
        lastNotionCodeBlockCheckTime = checkTime
        notionCodeBlockCacheLock.unlock()
    }

    @objc class func invalidateNotionCodeBlockCache() {
        writeNotionCodeBlockCache(result: false, checkTime: 0)
    }

    @objc class func invalidateContextDetectionCaches() {
        invalidateAddressBarCache()
        invalidateNotionCodeBlockCache()
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
        let now = mach_absolute_time()
        let cache = readNotionCodeBlockCache()
        let elapsedMs = PHTVTimingService.machTimeToMs(now - cache.checkTime)

        // Cache valid for 120ms to reduce AX pressure in hot typing path.
        if cache.checkTime > 0 && elapsedMs < 120 {
            return cache.result
        }

        var isCodeBlock = false
        let attributes: [String] = [
            kAXRoleDescriptionAttribute,
            kAXDescriptionAttribute,
            kAXHelpAttribute
        ]

        if let focused = focusedElement() {
            for attr in attributes {
                if let value = stringAttribute(focused, attr),
                   value.range(of: "code", options: String.CompareOptions.caseInsensitive) != nil {
                    isCodeBlock = true
                    break
                }
            }

            if !isCodeBlock,
               let parent = elementAttribute(focused, kAXParentAttribute) {
                for attr in attributes {
                    if let value = stringAttribute(parent, attr),
                       value.range(of: "code", options: String.CompareOptions.caseInsensitive) != nil {
                        isCodeBlock = true
                        break
                    }
                }
            }
        } else if cache.checkTime > 0 && elapsedMs < 500 {
            // AX can fail transiently while focus changes; keep recent stable result.
            isCodeBlock = cache.result
        }

        writeNotionCodeBlockCache(result: isCodeBlock, checkTime: now)
        return isCodeBlock
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

    @objc class func openAccessibilityPreferences() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)

        if let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ), NSWorkspace.shared.open(url) {
            return
        }

        let script = """
        tell application "System Preferences"
            activate
            set current pane to pane "com.apple.preference.universalaccess"
        end tell
        """
        NSAppleScript(source: script)?.executeAndReturnError(nil)
    }

    @objc class func openInputMonitoringPreferences() {
        if let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
        ), NSWorkspace.shared.open(url) {
            return
        }

        if let fallbackURL = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy"
        ) {
            _ = NSWorkspace.shared.open(fallbackURL)
        }
    }
}
