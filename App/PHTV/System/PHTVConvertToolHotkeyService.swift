//
//  PHTVConvertToolHotkeyService.swift
//  PHTV
//
//  Runtime quick-convert hotkey resolver from UserDefaults.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation

@objcMembers
final class PHTVConvertToolHotkeyService: NSObject {
    private static let keyHotKey = "convertToolHotKey"
    private static let defaultHotkey = Int32(bitPattern: 0xFE0000FE) // EMPTY_HOTKEY

    private static let hotkeyKeyMask: UInt32 = 0x00FF
    private static let hotkeyControlMask: UInt32 = 0x0100
    private static let hotkeyOptionMask: UInt32 = 0x0200
    private static let hotkeyCommandMask: UInt32 = 0x0400
    private static let hotkeyShiftMask: UInt32 = 0x0800
    private static let hotkeyNoKey: UInt32 = 0x00FE
    private static let hotkeyInvalidKey: UInt32 = 0x00FF
    private static let hotkeyModifierMask: UInt32 = hotkeyControlMask | hotkeyOptionMask | hotkeyCommandMask | hotkeyShiftMask
    private static let hotkeyAllowedMask: UInt32 = hotkeyKeyMask | hotkeyModifierMask
    private final class HotkeyCacheStateBox: @unchecked Sendable {
        private let lock = NSLock()
        private var isInitialized = false
        private var cachedRawHotkey: Int32?
        private var cachedHotkey = defaultHotkey

        func cachedValue(for rawHotkey: Int32?) -> Int32? {
            lock.lock()
            defer { lock.unlock() }
            guard isInitialized, cachedRawHotkey == rawHotkey else {
                return nil
            }
            return cachedHotkey
        }

        func store(rawHotkey: Int32?, hotkey: Int32) {
            lock.lock()
            cachedRawHotkey = rawHotkey
            cachedHotkey = hotkey
            isInitialized = true
            lock.unlock()
        }

        func invalidate() {
            lock.lock()
            isInitialized = false
            cachedRawHotkey = nil
            lock.unlock()
        }
    }

    private static let hotkeyCache = HotkeyCacheStateBox()

    private class func normalizeHotkey(_ rawHotkey: Int32) -> (value: Int32, normalized: Bool) {
        if rawHotkey == defaultHotkey {
            return (rawHotkey, false)
        }

        let raw = UInt32(bitPattern: rawHotkey)
        let filtered = raw & hotkeyAllowedMask
        let modifiers = filtered & hotkeyModifierMask
        let key = filtered & hotkeyKeyMask
        let keyIsValid = key != hotkeyInvalidKey

        guard modifiers != 0, keyIsValid else {
            return (defaultHotkey, true)
        }

        let value = Int32(bitPattern: filtered)
        return (value, value != rawHotkey)
    }

    private class func rawHotkeyFromDefaults() -> Int32? {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: keyHotKey) != nil else {
            return nil
        }
        return Int32(truncatingIfNeeded: defaults.integer(forKey: keyHotKey))
    }

    private class func resolveHotkey(rawHotkey: Int32?) -> (value: Int32, cachedRawHotkey: Int32?) {
        guard let rawHotkey else {
            return (defaultHotkey, nil)
        }

        let defaults = UserDefaults.standard
        let normalizedHotkey = normalizeHotkey(rawHotkey)
        if normalizedHotkey.normalized {
            defaults.set(Int(normalizedHotkey.value), forKey: keyHotKey)
#if DEBUG
            NSLog(
                "[ConvertHotkey] Normalized invalid hotkey 0x%X -> 0x%X",
                rawHotkey,
                normalizedHotkey.value
            )
#endif
        }
        let cachedRawHotkey = normalizedHotkey.normalized ? normalizedHotkey.value : rawHotkey
        return (normalizedHotkey.value, cachedRawHotkey)
    }

    @objc(currentHotkey)
    class func currentHotkey() -> Int32 {
        let rawHotkey = rawHotkeyFromDefaults()
        if let cached = hotkeyCache.cachedValue(for: rawHotkey) {
            return cached
        }

        let resolved = resolveHotkey(rawHotkey: rawHotkey)
        hotkeyCache.store(rawHotkey: resolved.cachedRawHotkey, hotkey: resolved.value)
        return resolved.value
    }

    @objc(invalidateCache)
    class func invalidateCache() {
        hotkeyCache.invalidate()
    }

    class func hasControl(_ hotkey: Int32) -> Bool {
        (UInt32(bitPattern: hotkey) & hotkeyControlMask) != 0
    }

    class func hasOption(_ hotkey: Int32) -> Bool {
        (UInt32(bitPattern: hotkey) & hotkeyOptionMask) != 0
    }

    class func hasCommand(_ hotkey: Int32) -> Bool {
        (UInt32(bitPattern: hotkey) & hotkeyCommandMask) != 0
    }

    class func hasShift(_ hotkey: Int32) -> Bool {
        (UInt32(bitPattern: hotkey) & hotkeyShiftMask) != 0
    }

    class func hasKey(_ hotkey: Int32) -> Bool {
        (UInt32(bitPattern: hotkey) & hotkeyKeyMask) != hotkeyNoKey
    }

    class func switchKey(_ hotkey: Int32) -> UInt16 {
        UInt16(UInt32(bitPattern: hotkey) & hotkeyKeyMask)
    }
}
