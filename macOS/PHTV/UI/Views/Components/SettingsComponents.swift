//
//  SettingsComponents.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

// MARK: - Settings Card

struct SettingsCard<Content: View, Trailing: View>: View {
    let title: String
    let subtitle: String?
    let icon: String
    let trailing: Trailing
    let content: Content
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    init(
        title: String,
        subtitle: String? = nil,
        icon: String,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() },
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.trailing = trailing()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 12) {
                // Icon with subtle background
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(width: 28, height: 28)
                    
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)

                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                trailing
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(headerBackground)

            Divider()
                .opacity(0.5)

            // Content
            content
                .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(borderCallback, lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.1 : 0.05), radius: 4, x: 0, y: 2)
        .frame(maxWidth: 700)
    }

    private var borderCallback: Color {
        if colorScheme == .dark {
            return Color.white.opacity(0.1)
        } else {
            return Color.black.opacity(0.08)
        }
    }

    @ViewBuilder
    private var cardBackground: some View {
        if SettingsVisualEffects.enableMaterials, !reduceTransparency {
            // Glassy look for modern macOS
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)
        } else {
            // Solid background fallback
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        }
    }

    @ViewBuilder
    private var headerBackground: some View {
        if colorScheme == .dark {
            Color.white.opacity(0.02)
        } else {
            Color.black.opacity(0.01)
        }
    }
}

// MARK: - Settings Toggle Row

struct SettingsToggleRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(iconColor)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(Color.accentColor)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Settings Divider

struct SettingsDivider: View {
    var leadingInset: CGFloat = 38 // Aligned with text start
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Divider()
            .padding(.leading, leadingInset)
            .opacity(0.6)
    }
}

// MARK: - Status Card

struct StatusCard: View {
    let hasPermission: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(hasPermission ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                    .frame(width: 48, height: 48)

                Image(systemName: hasPermission ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(hasPermission ? Color.green : .orange)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(hasPermission ? "Sẵn sàng" : "Thiếu quyền Trợ năng")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(
                    hasPermission
                        ? "Quyền Trợ năng đã được cấp"
                        : "Cần cấp quyền Trợ năng để PHTV hoạt động ổn định"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if !hasPermission {
                Button("Cấp quyền") {
                    if let url = URL(
                        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                    ) {
                        NSWorkspace.shared.open(url)
                    }
                }
                .controlSize(.small)
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
        }
        .padding(16)
        .frame(maxWidth: 700)
        .background {
            if SettingsVisualEffects.enableMaterials, !reduceTransparency {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(hasPermission ? Color.green.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: (hasPermission ? Color.green : Color.orange).opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Restore Key Button

struct RestoreKeyButton: View {
    let key: RestoreKey
    let isSelected: Bool
    let themeColor: Color
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(key.symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(shortDisplayName)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .white.opacity(0.9) : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(themeColor)
                        .shadow(color: themeColor.opacity(0.3), radius: 4, x: 0, y: 2)
                } else {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }

    private var shortDisplayName: String {
        switch key {
        case .esc: return "ESC"
        case .option: return "Option"
        case .control: return "Control"
        }
    }
}

