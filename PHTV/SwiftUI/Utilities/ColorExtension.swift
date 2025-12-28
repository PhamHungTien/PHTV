//
//  ColorExtension.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

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

// MARK: - AppStorageColor Wrapper

struct AppStorageColor: RawRepresentable {
    var color: Color

    init(color: Color) {
        self.color = color
    }

    init?(rawValue: String) {
        guard let data = Data(base64Encoded: rawValue) else {
            return nil
        }

        do {
            let nsColor = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)
            guard let color = nsColor else {
                return nil
            }
            self.color = Color.fromNSColor(color)
        } catch {
            return nil
        }
    }

    var rawValue: String {
        do {
            let nsColor = NSColor(color)
            let data = try NSKeyedArchiver.archivedData(withRootObject: nsColor, requiringSecureCoding: false)
            return data.base64EncodedString()
        } catch {
            return ""
        }
    }
}

// MARK: - Predefined Theme Colors

extension Color {
    static let themeColors: [ThemeColor] = [
        ThemeColor(id: "blue", name: "Xanh dương", color: .blue),
        ThemeColor(id: "purple", name: "Tím", color: .purple),
        ThemeColor(id: "pink", name: "Hồng", color: .pink),
        ThemeColor(id: "red", name: "Đỏ", color: .red),
        ThemeColor(id: "orange", name: "Cam", color: .orange),
        ThemeColor(id: "yellow", name: "Vàng", color: .yellow),
        ThemeColor(id: "green", name: "Xanh lá", color: .green),
        ThemeColor(id: "teal", name: "Xanh ngọc", color: .compatTeal),
        ThemeColor(id: "indigo", name: "Chàm", color: .compatIndigo),
        ThemeColor(id: "mint", name: "Bạc hà", color: .compatMint),
        ThemeColor(id: "cyan", name: "Lục lam", color: .compatCyan),
        ThemeColor(id: "brown", name: "Nâu", color: .compatBrown),
    ]
}

// MARK: - Theme Color Model

struct ThemeColor: Identifiable {
    let id: String
    let name: String
    let color: Color
}
