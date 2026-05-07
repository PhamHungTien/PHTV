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
    var onEditingChanged: ((Bool) -> Void)? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                Slider(
                    value: $value,
                    in: minValue...maxValue,
                    step: step,
                    onEditingChanged: { editing in
                        onEditingChanged?(editing)
                    }
                )
                .controlSize(.small)
                .tint(iconColor)
                .frame(width: 120)

                Text(valueFormatter(value))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(iconColor)
                    .monospacedDigit()
                    .frame(minWidth: 40, alignment: .trailing)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    VStack(spacing: 16) {
        SettingsSliderRow(
            icon: "speaker.wave.2",
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
            icon: "arrow.up.left.and.arrow.down.right",
            iconColor: .blue,
            title: "Kích thước icon",
            subtitle: "Điều chỉnh kích thước icon trên menu bar",
            minValue: 8.0,
            maxValue: 24.0,
            step: 1.0,
            value: .constant(14.0),
            valueFormatter: { String(format: "%.0f pt", $0) }
        )
    }
    .padding(16)
}
