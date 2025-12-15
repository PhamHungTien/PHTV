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
                            iconColor: .green,
                            title: "Kiểm tra chính tả",
                            subtitle: "Tự động phát hiện lỗi chính tả",
                            isOn: $appState.checkSpelling
                        )

                        // Removed font size slider and preview
                    }
                }

                // Enhancement Features
                SettingsCard(title: "Cải thiện gõ", icon: "wand.and.stars") {
                    VStack(spacing: 0) {
                        SettingsToggleRow(
                            icon: "textformat.abc",
                            iconColor: .blue,
                            title: "Viết hoa ký tự đầu",
                            subtitle: "Tự động viết hoa sau dấu chấm",
                            isOn: $appState.upperCaseFirstChar
                        )

                        SettingsDivider()

                        SettingsToggleRow(
                            icon: "arrow.left.arrow.right",
                            iconColor: .orange,
                            title: "Phím chuyển thông minh",
                            subtitle: "Tự động chuyển ngữ thông minh",
                            isOn: $appState.useSmartSwitchKey
                        )
                    }
                }

                // Advanced Options
                SettingsCard(title: "Tùy chọn nâng cao", icon: "gearshape.2.fill") {
                    VStack(spacing: 0) {
                        SettingsToggleRow(
                            icon: "character",
                            iconColor: .teal,
                            title: "Phụ âm Z, F, W, J",
                            subtitle: "Cho phép nhập các phụ âm ngoại lai",
                            isOn: $appState.allowConsonantZFWJ
                        )

                        SettingsDivider()

                        SettingsToggleRow(
                            icon: "arrow.right.circle.fill",
                            iconColor: .mint,
                            title: "Phụ âm đầu nhanh",
                            subtitle: "Gõ nhanh phụ âm đầu",
                            isOn: $appState.quickStartConsonant
                        )

                        SettingsDivider()

                        SettingsToggleRow(
                            icon: "arrow.left.circle.fill",
                            iconColor: .cyan,
                            title: "Phụ âm cuối nhanh",
                            subtitle: "Gõ nhanh phụ âm cuối",
                            isOn: $appState.quickEndConsonant
                        )

                        SettingsDivider()

                        SettingsToggleRow(
                            icon: "memorychip.fill",
                            iconColor: .indigo,
                            title: "Nhớ bảng mã",
                            subtitle: "Lưu bảng mã khi đóng ứng dụng",
                            isOn: $appState.rememberCode
                        )
                    }
                }

                // (Âm thanh & Giao diện) section removed per latest direction

                // Hotkey Configuration
                SettingsCard(title: "Phím tắt chuyển chế độ", icon: "command.circle.fill") {
                    HotkeyConfigView()
                }
            }
            .padding(20)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Reusable Components

struct StatusCard: View {
    let hasPermission: Bool

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                if #available(macOS 26.0, *) {
                    Circle()
                        .fill(
                            hasPermission ? Color.green.opacity(0.15) : Color.orange.opacity(0.15)
                        )
                        .frame(width: 48, height: 48)
                        .glassEffect(in: .circle)
                } else {
                    Circle()
                        .fill(
                            hasPermission ? Color.green.opacity(0.15) : Color.orange.opacity(0.15)
                        )
                        .frame(width: 48, height: 48)
                }

                Image(
                    systemName: hasPermission
                        ? "checkmark.shield.fill" : "exclamationmark.triangle.fill"
                )
                .font(.system(size: 22))
                .foregroundStyle(hasPermission ? .green : .orange)
            }

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
                    .tint(hasPermission ? .green : .orange)
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
                    .fill(hasPermission ? Color.green.opacity(0.08) : Color.orange.opacity(0.08))
                    .glassEffect(in: .rect(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(hasPermission ? Color.green.opacity(0.08) : Color.orange.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                hasPermission
                                    ? Color.green.opacity(0.2) : Color.orange.opacity(0.2),
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
                    .foregroundStyle(.blue)

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
                .tint(.blue)
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
                    .foregroundStyle(.blue)
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
            .tint(.blue)
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

