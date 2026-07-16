//
//  PHTVAccessibilityService.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation
import AppKit
@preconcurrency import ApplicationServices
import Darwin

/// Decides whether the focused element is a Notion code block.
///
/// The Notion code-block fix swaps in a very different output strategy (AX
/// select + type-over instead of backspaces). Applying it anywhere else
/// corrupts typing, so a stale `true` must never survive a context change —
/// it leaked into Outlook and swallowed the diacritics of every word.
enum PHTVNotionCodeBlockPolicy {
    /// Age below which a cached answer may still stand in for a transient
    /// accessibility failure *inside* Notion.
    static let staleFallbackMs: UInt64 = 500

    /// - Parameters:
    ///   - inNotionContext: whether the focused app is Notion (or a browser on Notion).
    ///   - axDetected: accessibility verdict, or `nil` when it could not be read.
    ///   - cachedResult: previous answer.
    ///   - cacheAgeMs: age of `cachedResult`, or `nil` when there is no cache.
    static func resolve(
        inNotionContext: Bool,
        axDetected: Bool?,
        cachedResult: Bool,
        cacheAgeMs: UInt64?
    ) -> Bool {
        // Never carry a code-block verdict outside Notion.
        guard inNotionContext else { return false }

        if let axDetected {
            return axDetected
        }

        // Still inside Notion but accessibility failed to answer: keep the last
        // known verdict briefly rather than flip-flopping mid-word.
        if let cacheAgeMs, cacheAgeMs < staleFallbackMs {
            return cachedResult
        }

        return false
    }
}

@objcMembers
final class PHTVAccessibilityService: NSObject {
    private struct AccessibilityCacheState {
        var lastTerminalPanelResult = false
        var lastTerminalPanelCheckTime: UInt64 = 0
        var lastClaudeCodeSessionResult = false
        var lastClaudeCodeSessionCheckTime: UInt64 = 0
        var lastAddressBarResult = false
        var lastAddressBarCheckTime: UInt64 = 0
        var lastNotionCodeBlockResult = false
        var lastNotionCodeBlockCheckTime: UInt64 = 0
    }

    private final class AccessibilityCacheStateBox: @unchecked Sendable {
        private let lock = NSLock()
        private var state = AccessibilityCacheState()

        func withLock<T>(_ body: (inout AccessibilityCacheState) -> T) -> T {
            lock.lock()
            defer { lock.unlock() }
            return body(&state)
        }
    }

    private static let cacheState = AccessibilityCacheStateBox()

    private static let uppercaseAbbreviationSet: Set<String> = [
        "mr", "mrs", "ms", "dr", "prof", "sr", "jr", "st",
        "vs", "etc", "eg", "ie",
        "tp", "q", "p", "ths", "ts", "gs", "pgs"
    ]

    private class func isAsciiWhitespace(_ c: unichar) -> Bool {
        c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D
    }

    private class func isAsciiLetter(_ c: unichar) -> Bool {
        (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A)
    }

    private class func isAsciiDigit(_ c: unichar) -> Bool {
        c >= 0x30 && c <= 0x39
    }

    private class func isAsciiClosingPunct(_ c: unichar) -> Bool {
        c == 0x22 || c == 0x27 || c == 0x29 || c == 0x5D || c == 0x7D
    }

    private class func isAsciiSentenceTerminator(_ c: unichar) -> Bool {
        c == 0x2E || c == 0x21 || c == 0x3F
    }

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

    @objc(shouldPrimeUppercaseFromAXWithSafeMode:uppercaseEnabled:uppercaseExcluded:)
    class func shouldPrimeUppercaseFromAX(safeMode: Bool,
                                          uppercaseEnabled: Bool,
                                          uppercaseExcluded: Bool) -> Bool {
        guard uppercaseEnabled, !uppercaseExcluded, !safeMode else {
            return false
        }

        let systemWide = AXUIElementCreateSystemWide()
        guard let focusedElement = elementAttribute(systemWide, kAXFocusedUIElementAttribute) else {
            return false
        }

        var valueRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focusedElement, kAXValueAttribute as CFString, &valueRef) == .success else {
            return false
        }

        let valueString: String
        if let valueRef,
           CFGetTypeID(valueRef) == CFStringGetTypeID(),
           let casted = valueRef as? String {
            valueString = casted
        } else {
            valueString = ""
        }

        let valueNSString = valueString as NSString
        var caretLocation = valueNSString.length
        var rangeRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(focusedElement, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success,
           let rangeRef,
           CFGetTypeID(rangeRef) == AXValueGetTypeID() {
            var sel = CFRange()
            let axRange = unsafeDowncast(rangeRef, to: AXValue.self)
            if AXValueGetValue(axRange, .cfRange, &sel) {
                caretLocation = sel.location
            }
        }

        if caretLocation <= 0 {
            return true
        }
        if caretLocation > valueNSString.length {
            caretLocation = valueNSString.length
        }

        var idx = caretLocation - 1

        while idx >= 0 && isAsciiWhitespace(valueNSString.character(at: idx)) {
            idx -= 1
        }
        if idx < 0 {
            return true
        }

        var progressed = true
        while progressed {
            progressed = false
            while idx >= 0 && isAsciiClosingPunct(valueNSString.character(at: idx)) {
                idx -= 1
                progressed = true
            }
            while idx >= 0 && isAsciiWhitespace(valueNSString.character(at: idx)) {
                idx -= 1
                progressed = true
            }
        }
        if idx < 0 {
            return true
        }

        let lastChar = valueNSString.character(at: idx)
        if !isAsciiSentenceTerminator(lastChar) {
            return false
        }

        if lastChar != 0x2E {
            return true
        }

        var end = idx - 1
        while end >= 0 && isAsciiWhitespace(valueNSString.character(at: end)) {
            end -= 1
        }
        if end < 0 {
            return false
        }

        var start = end
        while start >= 0 {
            let c = valueNSString.character(at: start)
            if isAsciiLetter(c) || isAsciiDigit(c) {
                start -= 1
                continue
            }
            break
        }

        let tokenStart = start + 1
        let tokenLength = end - start
        if tokenLength <= 0 {
            return false
        }

        let token = valueNSString.substring(with: NSRange(location: tokenStart, length: tokenLength)).lowercased()

        var allDigits = true
        for char in token.utf16 {
            if !isAsciiDigit(char) {
                allDigits = false
                break
            }
        }
        if allDigits {
            return false
        }

        if token.count == 1 {
            return false
        }

        return !uppercaseAbbreviationSet.contains(token)
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
            let axRange = unsafeDowncast(rangeRef, to: AXValue.self)
            if AXValueGetValue(axRange, .cfRange, &sel) {
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
        return unsafeDowncast(raw, to: AXUIElement.self)
    }

    // MARK: - Electron accessibility bootstrap

    private final class ElectronAXBootstrapStateBox: @unchecked Sendable {
        private let lock = NSLock()
        private var enabledPids: Set<pid_t> = []

        /// Returns true when the pid was not enabled yet and the caller
        /// should perform the enable step now.
        func markIfNeeded(_ pid: pid_t) -> Bool {
            lock.lock()
            defer { lock.unlock() }
            return enabledPids.insert(pid).inserted
        }

        func unmark(_ pid: pid_t) {
            lock.lock()
            defer { lock.unlock() }
            enabledPids.remove(pid)
        }
    }

    private static let electronAXBootstrapState = ElectronAXBootstrapStateBox()

    /// Chromium/Electron apps only build their DOM accessibility tree after an
    /// assistive client opts in via AXManualAccessibility. Without this the
    /// focused element of apps like Notion is invisible to PHTV, so
    /// per-context typing fixes (e.g. Notion code blocks) silently fail.
    /// Called on every frontmost-app change; enables once per app process.
    @objc class func ensureElectronAccessibility(forBundleId bundleId: String?) {
        guard PHTVAppDetectionService.isNotionApp(bundleId), let bundleId else { return }

        for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleId) {
            let pid = app.processIdentifier
            guard pid > 0, electronAXBootstrapState.markIfNeeded(pid) else { continue }

            let appElement = AXUIElementCreateApplication(pid)
            let result = AXUIElementSetAttributeValue(
                appElement,
                "AXManualAccessibility" as CFString,
                kCFBooleanTrue
            )
            if result == .success {
                NSLog("[Accessibility] Enabled Electron accessibility tree for %@ (pid %d)",
                      bundleId, pid)
            } else {
                // The app may still be launching; retry on its next activation.
                electronAXBootstrapState.unmark(pid)
            }
        }
    }

    /// Selects the `count` UTF-16 units before the caret in the focused
    /// element so the next synthetic text event types over them. Returns true
    /// only when the selection was applied and verified by reading it back —
    /// CodeMirror-based editors accept AX selection changes but silently
    /// ignore AX text writes, which is exactly the combination this enables.
    @objc class func selectBackwardForTypeover(_ count: Int32) -> Bool {
        guard count > 0, let focused = focusedElement() else { return false }

        // Wait for the accessibility caret to settle: when typing fast, the
        // previous replacement text may still be committing in the renderer,
        // and selecting against a stale caret grabs the wrong characters
        // (dropped or duplicated letters). Two consecutive identical
        // zero-length reads mean the pending edits have landed.
        var caret = CFRange()
        var settled = false
        var lastLocation = -1
        for attempt in 0..<5 {
            var caretRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(
                    focused, kAXSelectedTextRangeAttribute as CFString, &caretRef) == .success,
                  let caretValue = caretRef else {
                return false
            }
            guard AXValueGetValue(caretValue as! AXValue, .cfRange, &caret) else {
                return false
            }
            if attempt > 0 && caret.length == 0 && caret.location == lastLocation {
                settled = true
                break
            }
            lastLocation = caret.length == 0 ? caret.location : -1
            usleep(8000)
        }
        guard settled, caret.location >= Int(count) else {
            return false
        }

        var selection = CFRange(location: caret.location - Int(count), length: Int(count))
        guard let selectionValue = AXValueCreate(.cfRange, &selection) else { return false }
        guard AXUIElementSetAttributeValue(
                focused, kAXSelectedTextRangeAttribute as CFString, selectionValue) == .success else {
            return false
        }

        // Chromium applies the selection asynchronously in the renderer, with
        // latency jitter while it is busy rendering keystrokes. Poll briefly
        // until the selection is confirmed before letting the replacement
        // text type over it.
        for _ in 0..<4 {
            usleep(12000)
            var verifyRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(
                    focused, kAXSelectedTextRangeAttribute as CFString, &verifyRef) == .success,
                  let verifyValue = verifyRef else {
                break
            }
            var applied = CFRange()
            guard AXValueGetValue(verifyValue as! AXValue, .cfRange, &applied) else { break }
            if applied.location == selection.location && applied.length == selection.length {
                return true
            }
        }

        // The selection could still apply late; restore the original caret so
        // the fallback deletion path cannot double-delete on top of it.
        var originalCaret = caret
        if let caretValue = AXValueCreate(.cfRange, &originalCaret) {
            AXUIElementSetAttributeValue(
                focused, kAXSelectedTextRangeAttribute as CFString, caretValue)
            usleep(8000)
        }
        return false
    }

    private class func focusedElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        return elementAttribute(systemWide, kAXFocusedUIElementAttribute)
    }

    private class func focusedApplicationElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        return elementAttribute(systemWide, kAXFocusedApplicationAttribute)
    }

    private class func focusedWindowTitleForFrontmostApp() -> String? {
        guard let focusedWindow = focusedWindowForFrontmostApp() else {
            return nil
        }

        return stringAttribute(focusedWindow, kAXTitleAttribute)
    }

    private class func focusedWindowDocumentForFrontmostApp() -> String? {
        guard let focusedWindow = focusedWindowForFrontmostApp() else {
            return nil
        }

        return stringAttribute(focusedWindow, kAXDocumentAttribute)
    }

    private class func focusedWindowForFrontmostApp() -> AXUIElement? {
        guard let appElement = focusedApplicationElement() else {
            return nil
        }
        return elementAttribute(appElement, kAXFocusedWindowAttribute)
    }

    private class func focusedAppBundleId() -> String? {
        PHTVAppContextService.currentFrontmostBundleId()
    }

    private class func isNotionWorkspaceContext() -> Bool {
        let bundleId = focusedAppBundleId()
        if PHTVAppDetectionService.isNotionApp(bundleId) {
            return true
        }

        guard PHTVAppDetectionService.isBrowserApp(bundleId) else {
            return false
        }

        if let document = focusedWindowDocumentForFrontmostApp()?.lowercased(),
           document.contains("notion.so") || document.contains("notion.site") || document.contains("notion.com") {
            return true
        }

        if let title = focusedWindowTitleForFrontmostApp()?.lowercased(),
           title.contains("notion") {
            return true
        }

        return false
    }

    private class func containsAddressBarKeyword(_ value: String?, bundleId: String?) -> Bool {
        guard let value else {
            return false
        }
        var keywords = ["Address", "Omnibox", "Location", "URL", "Địa chỉ"]
        if PHTVAppDetectionService.isSafariApp(bundleId) {
            keywords.append("Smart Search")
        }
        for keyword in keywords {
            if value.range(of: keyword, options: .caseInsensitive) != nil {
                return true
            }
        }
        return false
    }

    class func addressBarClassification(
        role: String?,
        positiveKeywordMatch: Bool,
        foundWebArea: Bool,
        strictDetection: Bool
    ) -> Bool {
        if positiveKeywordMatch {
            return true
        }
        if foundWebArea {
            return false
        }

        switch role {
        case "AXComboBox":
            return true
        case "AXTextField", "AXSearchField":
            return !strictDetection
        default:
            // In strict mode (e.g. Cốc Cốc) only explicitly-identified roles are
            // treated as address bars. Unknown roles like AXRow/AXList that appear
            // in search-history dropdowns are rejected so the browser fix is not
            // incorrectly applied to suggestion fields.
            return !strictDetection
        }
    }

    private class func readAddressBarCache() -> (result: Bool, checkTime: UInt64) {
        cacheState.withLock { state in
            (state.lastAddressBarResult, state.lastAddressBarCheckTime)
        }
    }

    private class func writeAddressBarCache(result: Bool, checkTime: UInt64) {
        cacheState.withLock { state in
            state.lastAddressBarResult = result
            state.lastAddressBarCheckTime = checkTime
        }
    }

    @objc class func invalidateAddressBarCache() {
        writeAddressBarCache(result: false, checkTime: 0)
    }

    private class func readNotionCodeBlockCache() -> (result: Bool, checkTime: UInt64) {
        cacheState.withLock { state in
            (state.lastNotionCodeBlockResult, state.lastNotionCodeBlockCheckTime)
        }
    }

    private class func writeNotionCodeBlockCache(result: Bool, checkTime: UInt64) {
        cacheState.withLock { state in
            state.lastNotionCodeBlockResult = result
            state.lastNotionCodeBlockCheckTime = checkTime
        }
    }

    @objc class func invalidateNotionCodeBlockCache() {
        writeNotionCodeBlockCache(result: false, checkTime: 0)
    }

    @objc class func invalidateTerminalContextCaches() {
        cacheState.withLock { state in
            state.lastTerminalPanelResult = false
            state.lastTerminalPanelCheckTime = 0
            state.lastClaudeCodeSessionResult = false
            state.lastClaudeCodeSessionCheckTime = 0
        }
    }

    @objc class func invalidateContextDetectionCaches() {
        invalidateAddressBarCache()
        invalidateNotionCodeBlockCache()
        // Also reset terminal/Claude Code session caches so focus changes
        // are reflected on the next keypress (e.g., clicking into a new session).
        invalidateTerminalContextCaches()
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
        let bundleId = focusedAppBundleId()
        let strictDetection = PHTVCompatibilityProfileResolver.resolve(forBundleId: bundleId)
            .needsStrictAddressBarDetection

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

        let role = stringAttribute(focused, kAXRoleAttribute)

        // Strategy 1: positive keyword match
        let attributesToCheck: [String] = [
            kAXTitleAttribute,
            kAXDescriptionAttribute,
            kAXRoleDescriptionAttribute,
            "AXIdentifier"
        ]

        var positiveMatch = false
        for attr in attributesToCheck {
            if containsAddressBarKeyword(stringAttribute(focused, attr), bundleId: bundleId) {
                positiveMatch = true
                break
            }
        }

        // Strategy 2: negative identification via parent hierarchy
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

        isAddressBar = addressBarClassification(
            role: role,
            positiveKeywordMatch: positiveMatch,
            foundWebArea: foundWebArea,
            strictDetection: strictDetection
        )

        writeAddressBarCache(result: isAddressBar, checkTime: now)
        return isAddressBar
    }

    /// Only Notion itself, or a browser that could be showing Notion, can ever
    /// host a Notion code block. Resolved from the cached frontmost bundle id,
    /// so this costs nothing on the per-keystroke path.
    private class func isNotionCapableApp() -> Bool {
        let bundleId = focusedAppBundleId()
        return PHTVAppDetectionService.isNotionApp(bundleId)
            || PHTVAppDetectionService.isBrowserApp(bundleId)
    }

    @objc class func isNotionCodeBlock() -> Bool {
        let now = mach_absolute_time()

        // Outside a Notion-capable app the answer is always false, and any
        // cached `true` is dropped immediately. Reusing it across apps applied
        // Notion's code-block output strategy (AX select + type-over) inside
        // unrelated editors such as Outlook, which swallowed the replacement
        // text and left words without their diacritics.
        guard isNotionCapableApp() else {
            writeNotionCodeBlockCache(result: false, checkTime: now)
            return false
        }

        let cache = readNotionCodeBlockCache()
        let elapsedMs = PHTVTimingService.machTimeToMs(now - cache.checkTime)

        // Cache valid for 120ms to reduce AX pressure in hot typing path.
        if cache.checkTime > 0 && elapsedMs < 120 {
            return cache.result
        }

        let attributes: [String] = [
            kAXRoleDescriptionAttribute,
            kAXDescriptionAttribute,
            kAXHelpAttribute,
            kAXTitleAttribute,
            "AXIdentifier"
        ]

        let inNotionContext = isNotionWorkspaceContext()
        var axDetected: Bool?

        if inNotionContext, let focused = focusedElement() {
            var detected = false
            var current: AXUIElement? = focused
            var depth = 0
            while let element = current, depth < 6, !detected {
                for attr in attributes {
                    if let value = stringAttribute(element, attr),
                       value.range(of: "code", options: String.CompareOptions.caseInsensitive) != nil {
                        detected = true
                        break
                    }
                }
                current = elementAttribute(element, kAXParentAttribute)
                depth += 1
            }
            axDetected = detected
        }

        let isCodeBlock = PHTVNotionCodeBlockPolicy.resolve(
            inNotionContext: inNotionContext,
            axDetected: axDetected,
            cachedResult: cache.result,
            cacheAgeMs: cache.checkTime > 0 ? elapsedMs : nil
        )

        writeNotionCodeBlockCache(result: isCodeBlock, checkTime: now)
        return isCodeBlock
    }

    @objc class func isTerminalPanelFocused() -> Bool {
        let now = mach_absolute_time()
        let cached = cacheState.withLock { state in
            (state.lastTerminalPanelResult, state.lastTerminalPanelCheckTime)
        }
        if cached.1 != 0,
           PHTVTimingService.machTimeToMs(now - cached.1) < 100 {
            return cached.0
        }

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

        cacheState.withLock { state in
            state.lastTerminalPanelResult = isTerminalPanel
            state.lastTerminalPanelCheckTime = now
        }
        return isTerminalPanel
    }

    @objc class func isClaudeCodeSessionFocused() -> Bool {
        let now = mach_absolute_time()
        let cached = cacheState.withLock { state in
            (state.lastClaudeCodeSessionResult, state.lastClaudeCodeSessionCheckTime)
        }
        // 200ms cache reduces AX tree traversal frequency during active typing.
        // Claude Code sessions rarely change mid-typing; stale results are acceptable.
        if cached.1 != 0,
           PHTVTimingService.machTimeToMs(now - cached.1) < 200 {
            return cached.0
        }

        let bundleId = focusedAppBundleId()
        let isTerminalApp = PHTVAppDetectionService.isTerminalApp(bundleId)
        let isIDEApp = PHTVAppDetectionService.isIDEApp(bundleId)
        let isCliContainer = isTerminalApp || isIDEApp
        var isClaudeCodeSession = false

        if isCliContainer {
            let shouldInspect = isTerminalApp || (isIDEApp && isTerminalPanelFocused())
            if shouldInspect &&
                PHTVAppDetectionService.containsClaudeCodeKeyword(focusedWindowTitleForFrontmostApp()) {
                isClaudeCodeSession = true
            } else if shouldInspect, let focused = focusedElement() {
                let attributes: [String] = [
                    kAXDescriptionAttribute,
                    kAXRoleDescriptionAttribute,
                    kAXHelpAttribute,
                    kAXTitleAttribute,
                    "AXIdentifier",
                    kAXRoleAttribute,
                    kAXSubroleAttribute
                ]

                var current: AXUIElement? = focused
                for _ in 0..<8 {
                    guard let currentElement = current else {
                        break
                    }

                    for attr in attributes {
                        if PHTVAppDetectionService.containsClaudeCodeKeyword(
                            stringAttribute(currentElement, attr)
                        ) {
                            isClaudeCodeSession = true
                            break
                        }
                    }

                    if isClaudeCodeSession {
                        break
                    }

                    current = elementAttribute(currentElement, kAXParentAttribute)
                }
            }
        }

        cacheState.withLock { state in
            state.lastClaudeCodeSessionResult = isClaudeCodeSession
            state.lastClaudeCodeSessionCheckTime = now
        }
        return isClaudeCodeSession
    }

    @discardableResult
    @objc class func requestAccessibilityPrompt() -> Bool {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    @objc class func openAccessibilityPreferences() {
        _ = requestAccessibilityPrompt()
        openSystemSettings(urlStrings: accessibilitySettingsURLs)
    }

    @objc class func repairAndOpenAccessibilityPreferences() {
        if PHTVTCCMaintenanceService.resetAccessibilityEntry() {
            PHTVTCCMaintenanceService.restartTCCDaemon()
        }
        _ = requestAccessibilityPrompt()
        openSystemSettings(urlStrings: accessibilitySettingsURLs)
    }

    @discardableResult
    @objc class func requestInputMonitoringPrompt() -> Bool {
        PHTVPermissionService.requestInputMonitoringPermission()
    }

    @objc class func openInputMonitoringPreferences() {
        _ = requestInputMonitoringPrompt()
        openSystemSettings(urlStrings: inputMonitoringSettingsURLs)
    }

    @objc class func repairAndOpenInputMonitoringPreferences() {
        if PHTVTCCMaintenanceService.resetInputMonitoringEntry() {
            PHTVTCCMaintenanceService.restartTCCDaemon()
        }
        _ = requestInputMonitoringPrompt()
        openSystemSettings(urlStrings: inputMonitoringSettingsURLs)
    }

    private static let accessibilitySettingsURLs = [
        "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
        "x-apple.systempreferences:com.apple.preference.security",
        "x-apple.systempreferences:com.apple.preference.universalaccess"
    ]

    private static let inputMonitoringSettingsURLs = [
        "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent",
        "x-apple.systempreferences:com.apple.preference.security",
        "x-apple.systempreferences:com.apple.preference.keyboard"
    ]

    private class func openSystemSettings(urlStrings: [String]) {
        for urlString in urlStrings {
            guard let url = URL(string: urlString) else { continue }
            if NSWorkspace.shared.open(url) {
                return
            }
        }

        let systemSettingsURL = URL(fileURLWithPath: "/System/Applications/System Settings.app")
        if FileManager.default.fileExists(atPath: systemSettingsURL.path) {
            NSWorkspace.shared.open(systemSettingsURL)
        }
    }
}
