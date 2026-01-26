//
//  SettingsSliderRow.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

struct SettingsSliderRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let minValue: Double
    let maxValue: Double
    let step: Double
    @Binding var value: Double
    var valueFormatter: (Double) -> String = { String(format: "%.0f", $0) }
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                // Icon background - colored fill to avoid glass-on-glass (Apple guideline)
                ZStack {
                    PHTVRoundedRect(cornerRadius: 8)
                        .fill(iconColor.opacity(colorScheme == .dark ? 0.2 : 0.15))
                        .overlay(
                            PHTVRoundedRect(cornerRadius: 8)
                                .stroke(iconColor.opacity(colorScheme == .dark ? 0.3 : 0.2), lineWidth: 1)
                        )
                        .frame(width: 36, height: 36)

                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(iconColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                // Value pill with glass effect
                valueDisplay
            }

            Slider(
                value: $value,
                in: minValue...maxValue,
                step: step
            )
            .tint(iconColor)
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var valueDisplay: some View {
        Text(valueFormatter(value))
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(iconColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background {
                Capsule()
                    .fill(iconColor.opacity(colorScheme == .dark ? 0.2 : 0.15))
                    .overlay(
                        Capsule()
                            .stroke(iconColor.opacity(colorScheme == .dark ? 0.3 : 0.2), lineWidth: 1)
                    )
            }
    }
}

#Preview {
    VStack(spacing: 16) {
        SettingsSliderRow(
            icon: "speaker.wave.2.fill",
            iconColor: .blue,
            title: "Âm lượng beep",
            subtitle: "Điều chỉnh mức âm lượng tiếng beep",
            minValue: 0.0,
            maxValue: 1.0,
            step: 0.1,
            value: .constant(0.5),
            valueFormatter: { String(format: "%.0f%%", $0 * 100) }
        )

        Divider()
            .padding(.leading, 50)

        SettingsSliderRow(
            icon: "textformat.size",
            iconColor: .blue,
            title: "Kích cỡ font",
            subtitle: "Điều chỉnh kích cỡ chữ hiển thị",
            minValue: 8.0,
            maxValue: 24.0,
            step: 1.0,
            value: .constant(14.0),
            valueFormatter: { String(format: "%.0f pt", $0) }
        )
    }
    .padding(16)
}
