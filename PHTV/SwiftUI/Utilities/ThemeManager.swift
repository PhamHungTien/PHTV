//
//  ThemeManager.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

@MainActor
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @AppStorage("themeColor") private var storedColor: AppStorageColor = AppStorageColor(color: .blue) {
        willSet {
            objectWillChange.send()
        }
    }

    var themeColor: Color {
        get { storedColor.color }
        set { storedColor = AppStorageColor(color: newValue) }
    }

    private init() {}

    // Predefined theme colors
    let predefinedColors: [ThemeColor] = Color.themeColors

    // Update theme color
    func updateThemeColor(_ color: Color) {
        themeColor = color
    }
}
