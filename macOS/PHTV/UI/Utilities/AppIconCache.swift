//
//  AppIconCache.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import AppKit

/// Lightweight icon cache to avoid loading full-size app icons repeatedly.
@MainActor
final class AppIconCache {
    static let shared = AppIconCache()

    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 300
        cache.totalCostLimit = 30 * 1024 * 1024
    }

    func icon(for path: String, size: CGFloat) -> NSImage? {
        let key = "\(path)|\(Int(size))" as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }

        let icon = NSWorkspace.shared.icon(forFile: path)
        guard icon.size.width > 0, icon.size.height > 0 else { return nil }

        let scaled = scaledIcon(icon, size: size)
        if let scaled {
            let scale = NSScreen.main?.backingScaleFactor ?? 2.0
            let cost = Int(size * size * 4 * scale * scale)
            cache.setObject(scaled, forKey: key, cost: cost)
        }

        return scaled
    }

    func clear() {
        cache.removeAllObjects()
    }

    private func scaledIcon(_ icon: NSImage, size: CGFloat) -> NSImage? {
        let targetSize = NSSize(width: size, height: size)
        let image = NSImage(size: targetSize)
        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        icon.draw(in: NSRect(origin: .zero, size: targetSize),
                  from: NSRect(origin: .zero, size: icon.size),
                  operation: .sourceOver,
                  fraction: 1.0)
        image.unlockFocus()
        return image
    }
}
