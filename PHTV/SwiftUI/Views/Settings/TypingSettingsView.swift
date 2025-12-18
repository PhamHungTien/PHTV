//
//  TypingSettingsView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI
import AudioToolbox

struct TypingSettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Status Card
                StatusCard(hasPermission: appState.hasAccessibilityPermission)

                // Input Configuration
                SettingsCard(title: "Cấu hình gõ", icon: "keyboard.fill") {
                    VStack(spacing: 16) {
                        // Input Method Picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Phương pháp gõ")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)

                            Picker("", selection: $appState.inputMethod) {
                                ForEach(InputMethod.allCases) { method in
                                    Text(method.displayName).tag(method)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                        }

                        Divider()

                        // Code Table Picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Bảng mã")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)

                            Picker("", selection: $appState.codeTable) {
                                ForEach(CodeTable.allCases) { table in
                                    Text(table.displayName).tag(table)
                                }
                            }
                            .labelsHidden()
                        }
                    }
                }

                // Basic Features
                SettingsCard(title: "Tính năng cơ bản", icon: "checkmark.circle.fill") {
                    VStack(spacing: 0) {
                        SettingsToggleRow(
                            icon: "text.badge.checkmark",
                            iconColor: themeManager.themeColor,
                            title: "Kiểm tra chính tả",
                            subtitle: "Tự động phát hiện lỗi chính tả",
                            isOn: $appState.checkSpelling
                        )

                        SettingsDivider()

                        SettingsToggleRow(
                            icon: "arrow.uturn.left.circle.fill",
                            iconColor: themeManager.themeColor,
                            title: "Khôi phục phím nếu từ sai",
                            subtitle: "Khôi phục ký tự khi từ không hợp lệ",
                            isOn: $appState.restoreOnInvalidWord
                        )
                    }
                }

                // Enhancement Features
                SettingsCard(title: "Cải thiện gõ", icon: "wand.and.stars") {
                    VStack(spacing: 0) {
                        SettingsToggleRow(
                            icon: "textformat.abc",
                            iconColor: themeManager.themeColor,
                            title: "Viết hoa ký tự đầu",
                            subtitle: "Tự động viết hoa sau dấu chấm",
                            isOn: $appState.upperCaseFirstChar
                        )

                        SettingsDivider()

                        SettingsToggleRow(
                            icon: "arrow.left.arrow.right",
                            iconColor: themeManager.themeColor,
                            title: "Phím chuyển thông minh",
                            subtitle: "Tự động chuyển ngữ thông minh",
                            isOn: $appState.useSmartSwitchKey
                        )

                        SettingsDivider()

                        SettingsToggleRow(
                            icon: "a.circle.fill",
                            iconColor: themeManager.themeColor,
                            title: "Đặt dấu oà, uý",
                            subtitle: "Dấu trên chữ (oà, uý) thay vì dưới (òa, úy)",
                            isOn: $appState.useModernOrthography
                        )
                    }
                }

                Spacer(minLength: 20)
            }
            .padding(20)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Reusable Components

struct StatusCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let hasPermission: Bool

    var body: some View {
        HStack(spacing: 16) {
            Image(
                systemName: hasPermission
                    ? "checkmark.shield.fill" : "exclamationmark.triangle.fill"
            )
            .font(.system(size: 32))
            .foregroundStyle(hasPermission ? themeManager.themeColor : .orange)

            VStack(alignment: .leading, spacing: 4) {
                Text(hasPermission ? "Sẵn sàng hoạt động" : "Cần cấp quyền")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(
                    hasPermission
                        ? "Quyền Accessibility đã được cấp" : "Vui lòng cấp quyền để sử dụng"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if !hasPermission {
                if #available(macOS 26.0, *) {
                    Button("Cấp quyền") {
                        if let url = URL(
                            string:
                                "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                        ) {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.small)
                    .tint(hasPermission ? themeManager.themeColor : .orange)
                } else {
                    Button("Cấp quyền") {
                        if let url = URL(
                            string:
                                "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                        ) {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
        .padding(16)
        .background {
            if #available(macOS 26.0, *) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(hasPermission ? themeManager.themeColor.opacity(0.08) : Color.orange.opacity(0.08))
                    .glassEffect(in: .rect(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(hasPermission ? themeManager.themeColor.opacity(0.08) : Color.orange.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                hasPermission
                                    ? themeManager.themeColor.opacity(0.2) : Color.orange.opacity(0.2),
                                lineWidth: 1)
                    )
            }
        }
    }
}

struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.tint)

                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

            Divider()

            // Content
            content
                .padding(16)
        }
        .background {
            if #available(macOS 26.0, *) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .glassEffect(in: .rect(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                    )
            }
        }
    }
}

struct SettingsToggleRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                if #available(macOS 26.0, *) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 36, height: 36)
                        .glassEffect(in: .rect(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 36, height: 36)
                }

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
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(iconColor)
        }
        .padding(.vertical, 6)
    }
}

struct SettingsDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 50)
    }
}

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
    var onValueChanged: ((Double) -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    if #available(macOS 26.0, *) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(iconColor.opacity(0.12))
                            .frame(width: 36, height: 36)
                            .glassEffect(in: .rect(cornerRadius: 8))
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(iconColor.opacity(0.12))
                            .frame(width: 36, height: 36)
                    }

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
                }

                Spacer()

                Text(valueFormatter(value))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.tint)
                    .frame(minWidth: 40, alignment: .trailing)
            }

            Slider(
                value: $value,
                in: minValue...maxValue,
                step: step,
                onEditingChanged: { editing in
                    onEditingChanged?(editing)
                }
            )
            .tint(iconColor)
            .onChange(of: value) { _, newVal in
                onValueChanged?(newVal)
            }
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    TypingSettingsView()
        .environmentObject(AppState.shared)
        .frame(width: 500, height: 800)
}
