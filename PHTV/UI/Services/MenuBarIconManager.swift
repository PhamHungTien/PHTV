//
//  MenuBarIconManager.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import AppKit

// MARK: - Menu Bar Icon Manager

/// Cache for menu bar icons to avoid repeated image generation
@MainActor
private var menuBarIconCache: [String: NSImage] = [:]

/// Invalidate menu bar icon cache (call when icon settings change)
@MainActor
func invalidateMenuBarIconCache() {
    menuBarIconCache.removeAll()
}

@MainActor
func makeMenuBarIconImage(size: CGFloat, slashed: Bool, useVietnameseIcon: Bool) -> NSImage {
    // Check cache first
    let cacheKey = "\(size)-\(slashed)-\(useVietnameseIcon)"
    if let cached = menuBarIconCache[cacheKey] {
        return cached
    }

    let targetSize = NSSize(width: size, height: size)
    let img = NSImage(size: targetSize)
    img.lockFocus()
    defer { img.unlockFocus() }

    let rect = NSRect(origin: .zero, size: targetSize)

    // Use different icons based on language mode
    let baseIcon: NSImage? = {
        if slashed {
            // English mode - use menubar_english.png
            if let englishIcon = NSImage(named: "menubar_english") {
                return englishIcon
            }
        }
        // Vietnamese mode - use menubar_vietnamese.png or menubar_icon.png based on preference
        if useVietnameseIcon, let vietnameseIcon = NSImage(named: "menubar_vietnamese") {
            return vietnameseIcon
        }
        if let img = NSImage(named: "menubar_icon") {
            return img
        }
        return NSApplication.shared.applicationIconImage
    }()

    if let baseIcon {
        baseIcon.draw(
            in: rect,
            from: .zero,
            operation: .sourceOver,
            fraction: 1.0,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
    }

    img.isTemplate = true
    img.size = targetSize

    // Cache the result
    menuBarIconCache[cacheKey] = img
    return img
}
