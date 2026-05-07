//
//  SettingsComponents.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

enum SettingsLayout {
    static let contentMaxWidth: CGFloat = 680
    static let contentPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 16
    static let cardContentHorizontalPadding: CGFloat = 12
    static let cardContentVerticalPadding: CGFloat = 8
    static let rowVerticalPadding: CGFloat = 7
    static let rowControlColumnWidth: CGFloat = 168
    static let toggleControlWidth: CGFloat = 54
    static let defaultPickerWidth: CGFloat = 148
    static let sidebarMinWidth: CGFloat = 200
    static let sidebarIdealWidth: CGFloat = 240
    static let sidebarMaxWidth: CGFloat = 300
    static let detailMinWidth: CGFloat = 500
    static let detailMinHeight: CGFloat = 500
    static let windowMinSize = CGSize(width: 780, height: 550)
    static let windowIdealSize = CGSize(width: 900, height: 620)
}

// MARK: - Settings Card

struct SettingsCard<Content: View, Trailing: View>: View {
    let title: String
    let subtitle: String?
    let trailing: Trailing
    let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        icon: String,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() },
        @ViewBuilder content: () -> Content
    ) {
        _ = icon
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
        self.content = content()
    }

    var body: some View {
        GroupBox {
            content
                .padding(.horizontal, SettingsLayout.cardContentHorizontalPadding)
                .padding(.vertical, SettingsLayout.cardContentVerticalPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 12)

                trailing
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .groupBoxStyle(.automatic)
        .frame(maxWidth: SettingsLayout.contentMaxWidth, alignment: .leading)
    }
}

// MARK: - Settings Picker Row

struct SettingsPickerRow<SelectionValue: Hashable, PickerContent: View>: View {
    let title: String
    let subtitle: String?
    let controlWidth: CGFloat
    @Binding var selection: SelectionValue
    let pickerContent: PickerContent

    init(
        title: String,
        subtitle: String? = nil,
        selection: Binding<SelectionValue>,
        controlWidth: CGFloat = SettingsLayout.defaultPickerWidth,
        @ViewBuilder content: () -> PickerContent
    ) {
        self.title = title
        self.subtitle = subtitle
        self.controlWidth = controlWidth
        self._selection = selection
        self.pickerContent = content()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            rowLabel
                .layoutPriority(1)

            Spacer(minLength: 12)

            Picker("", selection: $selection) {
                pickerContent
            }
            .labelsHidden()
            .controlSize(.small)
            .frame(width: SettingsLayout.rowControlColumnWidth, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, SettingsLayout.rowVerticalPadding)
        .accessibilityElement(children: .combine)
    }

    private var rowLabel: some View {
        Text(title)
            .font(.body)
            .foregroundStyle(.primary)
            .lineLimit(1)
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
        HStack(alignment: .center, spacing: 16) {
            rowLabel
                .layoutPriority(1)

            Spacer(minLength: 12)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .fixedSize()
                .frame(width: SettingsLayout.toggleControlWidth, alignment: .trailing)
                .frame(width: SettingsLayout.rowControlColumnWidth, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, SettingsLayout.rowVerticalPadding)
        .accessibilityElement(children: .combine)
    }

    private var rowLabel: some View {
        Text(title)
            .font(.body)
            .foregroundStyle(.primary)
            .lineLimit(1)
    }
}

// MARK: - Settings Selection Row

struct SettingsSelectionRow: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .frame(width: 18, height: 18)
                    .padding(.top, 1)

                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .settingsControlButtonStyle(isProminent: isSelected)
        .controlSize(.small)
    }
}

// MARK: - Settings Divider

struct SettingsDivider: View {
    var leadingInset: CGFloat = 0

    var body: some View {
        Divider()
            .padding(.leading, leadingInset)
    }
}

// MARK: - Status Card

struct StatusCard: View {
    let runtimeHealth: PHTVTypingRuntimeHealthSnapshot

    var body: some View {
        GroupBox {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: statusIcon)
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(statusColor)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(statusTitle)
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                Spacer(minLength: 12)

                if shouldShowPermissionButton {
                    Button(permissionButtonTitle) {
                        AppDelegate.current()?.continuePermissionGuidanceIfNeeded(
                            forceOpenSystemSettings: true
                        )
                    }
                    .controlSize(.small)
                    .adaptiveProminentButtonStyle()
                    .tint(.orange)
                }
            }
        }
        .groupBoxStyle(.automatic)
        .frame(maxWidth: SettingsLayout.contentMaxWidth)
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

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(key.symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if key != .esc {
                    Text(shortDisplayName)
                        .font(.system(size: 11))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .settingsControlButtonStyle(isProminent: isSelected)
        .controlSize(.small)
        .tint(themeColor)
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
