//
//  ThemeSettingsView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

struct ThemeSettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Predefined Colors
                SettingsCard(title: "Màu chủ đạo", icon: "paintpalette.fill") {
                    VStack(spacing: 16) {
                        // Color Grid
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                        ], spacing: 12) {
                            ForEach(themeManager.predefinedColors) { themeColor in
                                ThemeColorButton(
                                    themeColor: themeColor,
                                    isSelected: isSameColor(themeColor.color, themeManager.themeColor)
                                ) {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        themeManager.updateThemeColor(themeColor.color)
                                    }
                                }
                            }
                        }
                    }
                }

                Spacer(minLength: 20)
            }
            .padding(20)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    // Helper function to compare colors
    private func isSameColor(_ color1: Color, _ color2: Color) -> Bool {
        let nsColor1 = NSColor(color1)
        let nsColor2 = NSColor(color2)

        // Convert to RGB space for comparison
        guard let rgb1 = nsColor1.usingColorSpace(.deviceRGB),
              let rgb2 = nsColor2.usingColorSpace(.deviceRGB) else {
            return false
        }

        return abs(rgb1.redComponent - rgb2.redComponent) < 0.01 &&
               abs(rgb1.greenComponent - rgb2.greenComponent) < 0.01 &&
               abs(rgb1.blueComponent - rgb2.blueComponent) < 0.01
    }
}

// MARK: - Theme Color Button

struct ThemeColorButton: View {
    let themeColor: ThemeColor
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(themeColor.color)
                        .frame(width: 44, height: 44)

                    if isSelected {
                        Circle()
                            .strokeBorder(Color.primary, lineWidth: 3)
                            .frame(width: 44, height: 44)

                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }

                Text(themeColor.name)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? themeColor.color.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? themeColor.color.opacity(0.3) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ThemeSettingsView()
        .frame(width: 600, height: 700)
}
