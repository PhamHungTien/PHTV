//
//  ColorExtension.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

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
            self.color = Color(nsColor: color)
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
        ThemeColor(id: "teal", name: "Xanh ngọc", color: .teal),
        ThemeColor(id: "indigo", name: "Chàm", color: .indigo),
        ThemeColor(id: "mint", name: "Bạc hà", color: .mint),
        ThemeColor(id: "cyan", name: "Lục lam", color: .cyan),
        ThemeColor(id: "brown", name: "Nâu", color: .brown),
    ]
}

// MARK: - Theme Color Model

struct ThemeColor: Identifiable {
    let id: String
    let name: String
    let color: Color
}
