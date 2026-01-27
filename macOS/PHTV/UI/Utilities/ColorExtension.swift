//
//  ColorExtension.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

// MARK: - Color from Hex String

extension Color {
    /// Create Color from hex string (e.g., "#FF5733" or "FF5733")
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }

        let length = hexSanitized.count
        let r, g, b, a: Double

        if length == 6 {
            r = Double((rgb & 0xFF0000) >> 16) / 255.0
            g = Double((rgb & 0x00FF00) >> 8) / 255.0
            b = Double(rgb & 0x0000FF) / 255.0
            a = 1.0
        } else if length == 8 {
            r = Double((rgb & 0xFF000000) >> 24) / 255.0
            g = Double((rgb & 0x00FF0000) >> 16) / 255.0
            b = Double((rgb & 0x0000FF00) >> 8) / 255.0
            a = Double(rgb & 0x000000FF) / 255.0
        } else {
            return nil
        }

        self.init(red: r, green: g, blue: b, opacity: a)
    }

    /// Convert Color to hex string
    var hexString: String {
        let nsColor = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(self)
        let r = Int(nsColor.redComponent * 255)
        let g = Int(nsColor.greenComponent * 255)
        let b = Int(nsColor.blueComponent * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - Color Compatibility for macOS 11+

extension Color {
    /// Create Color from NSColor (compatible with macOS 11+)
    static func fromNSColor(_ nsColor: NSColor) -> Color {
        if #available(macOS 12.0, *) {
            return Color(nsColor: nsColor)
        } else {
            // Fallback for macOS 11: convert via RGB
            let rgbColor = nsColor.usingColorSpace(.sRGB) ?? nsColor
            return Color(
                red: Double(rgbColor.redComponent),
                green: Double(rgbColor.greenComponent),
                blue: Double(rgbColor.blueComponent),
                opacity: Double(rgbColor.alphaComponent)
            )
        }
    }

    // Colors only available in macOS 12+ - define fallbacks
    static var compatTeal: Color {
        if #available(macOS 12.0, *) {
            return .teal
        } else {
            return Color(red: 0.35, green: 0.68, blue: 0.68)
        }
    }

    static var compatIndigo: Color {
        if #available(macOS 12.0, *) {
            return .indigo
        } else {
            return Color(red: 0.29, green: 0.0, blue: 0.51)
        }
    }

    static var compatMint: Color {
        if #available(macOS 12.0, *) {
            return .mint
        } else {
            return Color(red: 0.0, green: 0.78, blue: 0.75)
        }
    }

    static var compatCyan: Color {
        if #available(macOS 12.0, *) {
            return .cyan
        } else {
            return Color(red: 0.0, green: 0.75, blue: 0.85)
        }
    }

    static var compatBrown: Color {
        if #available(macOS 12.0, *) {
            return .brown
        } else {
            return Color(red: 0.6, green: 0.4, blue: 0.2)
        }
    }
}
