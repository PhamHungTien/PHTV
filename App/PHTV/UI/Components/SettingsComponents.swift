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
                .stroke(borderCallback, lineWidth: 1.0)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.12), radius: 8, x: 0, y: 4)
        .frame(maxWidth: 700)
    }

    private var borderCallback: Color {
        if colorScheme == .dark {
            return Color.white.opacity(0.18)
        } else {
            return Color.black.opacity(0.14)
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

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
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
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 12)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(Color.accentColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }
}

// MARK: - Settings Selection Row

struct SettingsSelectionRow: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .frame(width: 18, height: 18)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(backgroundShape)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var backgroundShape: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(isSelected ? Color.accentColor.opacity(colorScheme == .dark ? 0.18 : 0.10) : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                        isSelected
                            ? Color.accentColor.opacity(colorScheme == .dark ? 0.45 : 0.28)
                            : Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08),
                        lineWidth: 1
                    )
            )
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
    let runtimeHealth: PHTVTypingRuntimeHealthSnapshot
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.1))
                    .frame(width: 48, height: 48)

                Image(systemName: statusIcon)
                    .font(.system(size: 24))
                    .foregroundStyle(statusColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(statusTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(statusDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if shouldShowPermissionButton {
                Button(permissionButtonTitle) {
                    AppDelegate.current()?.continuePermissionGuidanceIfNeeded(
                        forceOpenSystemSettings: true
                    )
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
                .stroke(statusColor.opacity(0.4), lineWidth: 1.5)
        )
        .shadow(color: statusColor.opacity(colorScheme == .dark ? 0.15 : 0.08), radius: 10, x: 0, y: 4)
    }

    private var statusColor: Color {
        switch runtimeHealth.phase {
        case .ready:
            return .green
        case .accessibilityRequired:
            return .orange
        case .relaunchPending:
            return .blue
        case .waitingForEventTap:
            return .yellow
        }
    }

    private var statusIcon: String {
        switch runtimeHealth.phase {
        case .ready:
            return "checkmark.shield.fill"
        case .accessibilityRequired:
            return "exclamationmark.triangle.fill"
        case .relaunchPending:
            return "arrow.clockwise.circle.fill"
        case .waitingForEventTap:
            return "clock.badge.exclamationmark.fill"
        }
    }

    private var statusTitle: String {
        switch runtimeHealth.phase {
        case .ready:
            return "Sẵn sàng"
        case .accessibilityRequired:
            return "Thiếu quyền Trợ năng"
        case .relaunchPending:
            return "Đang tự khởi động lại"
        case .waitingForEventTap:
            return "Đang hoàn tất khởi tạo"
        }
    }

    private var statusDescription: String {
        switch runtimeHealth.phase {
        case .ready:
            return "PHTV đã sẵn sàng để gõ tiếng Việt."
        case .accessibilityRequired:
            return "PHTV chỉ cần quyền Trợ năng để hoạt động ổn định."
        case .relaunchPending:
            return "PHTV đang tự khởi động lại để nhận quyền Trợ năng và khôi phục bộ gõ."
        case .waitingForEventTap:
            return "Quyền đã được cấp, nhưng bộ gõ chưa sẵn sàng. Nhấn Thử lại ngay để PHTV tự khởi tạo lại."
        }
    }

    private var shouldShowPermissionButton: Bool {
        switch runtimeHealth.phase {
        case .ready, .relaunchPending:
            return false
        case .accessibilityRequired, .waitingForEventTap:
            return true
        }
    }

    private var permissionButtonTitle: String {
        if runtimeHealth.phase == .accessibilityRequired {
            return "Mở Trợ năng"
        }
        return "Thử lại ngay"
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
