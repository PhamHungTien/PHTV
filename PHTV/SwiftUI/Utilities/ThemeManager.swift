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

    @AppStorage("themeColor") private var storedColor = AppStorageColor(color: .blue)

    var themeColor: Color {
        get { storedColor.color }
        set {
            objectWillChange.send()
            storedColor = AppStorageColor(color: newValue)
        }
    }

    private init() {}

    // Predefined theme colors
    let predefinedColors: [ThemeColor] = Color.themeColors
}
