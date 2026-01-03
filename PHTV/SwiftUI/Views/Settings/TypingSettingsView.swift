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

    // Check if restore key conflicts with hotkey
    private var hasRestoreHotkeyConflict: Bool {
        guard appState.restoreOnEscape else { return false }

        switch appState.restoreKey {
        case .esc:
            return false // ESC never conflicts
        case .option:
            return appState.switchKeyOption
        case .control:
            return appState.switchKeyControl
        }
    }

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
                            iconColor: .accentColor,
                            title: "Kiểm tra chính tả",
                            subtitle: "Tự động phát hiện lỗi chính tả",
                            isOn: $appState.checkSpelling
                        )

                        SettingsDivider()

                        SettingsToggleRow(
                            icon: "arrow.uturn.left.circle.fill",
                            iconColor: .accentColor,
                            title: "Khôi phục phím nếu từ sai",
                            subtitle: "Khôi phục ký tự khi từ không hợp lệ",
                            isOn: $appState.restoreOnInvalidWord
                        )

                        SettingsDivider()

                        SettingsToggleRow(
                            icon: "textformat.abc.dottedunderline",
                            iconColor: .accentColor,
                            title: "Tự động nhận diện từ tiếng Anh",
                            subtitle: "Khôi phục từ tiếng Anh khi gõ ở chế độ Việt (VD: tẻminal → terminal)",
                            isOn: $appState.autoRestoreEnglishWord
                        )
                    }
                }

                // Restore to Raw Keys Feature
                SettingsCard(title: "Phím khôi phục", icon: "arrow.uturn.backward.circle.fill") {
                    VStack(spacing: 16) {
                        SettingsToggleRow(
                            icon: "arrow.uturn.backward.circle.fill",
                            iconColor: .accentColor,
                            title: "Khôi phục về ký tự gốc",
                            subtitle: "Khôi phục về ký tự đã gõ trước khi biến đổi (VD: user → úẻ → phím khôi phục → user)",
                            isOn: $appState.restoreOnEscape
                        )

                        if appState.restoreOnEscape {
                            Divider()

                            VStack(alignment: .leading, spacing: 12) {
                                Text("Chọn phím khôi phục")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)

                                // Grid of restore keys (3 columns, 3 keys total)
                                LazyVGrid(columns: [
                                    GridItem(.flexible(), spacing: 10),
                                    GridItem(.flexible(), spacing: 10),
                                    GridItem(.flexible(), spacing: 10)
                                ], spacing: 10) {
                                    ForEach(RestoreKey.allCases) { key in
                                        RestoreKeyButton(
                                            key: key,
                                            isSelected: appState.restoreKey == key,
                                            themeColor: .accentColor
                                        ) {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                appState.restoreKey = key
                                            }
                                        }
                                    }
                                }

                                // Conflict warning
                                if hasRestoreHotkeyConflict {
                                    HStack(spacing: 10) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundStyle(.orange)
                                            .font(.system(size: 14))

                                        Text("Phím khôi phục trùng với phím bổ trợ trong phím tắt chuyển chế độ")
                                            .font(.caption)
                                            .foregroundStyle(.orange)

                                        Spacer()
                                    }
                                    .padding(10)
                                    .background {
                                        if #available(macOS 26.0, *) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(.ultraThinMaterial)
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(Color.orange.opacity(0.1))
                                            }
                                            .glassEffect(in: .rect(cornerRadius: 8))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                                            )
                                        } else {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.orange.opacity(0.1))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                                                )
                                        }
                                    }
                                    .transition(.scale.combined(with: .opacity))
                                }
                            }
                        }
                    }
                }

                // Enhancement Features
                SettingsCard(title: "Cải thiện gõ", icon: "wand.and.stars") {
                    VStack(spacing: 0) {
                        SettingsToggleRow(
                            icon: "textformat.abc",
                            iconColor: .accentColor,
                            title: "Viết hoa ký tự đầu",
                            subtitle: "Tự động viết hoa sau dấu chấm",
                            isOn: $appState.upperCaseFirstChar
                        )

                        SettingsDivider()

                        SettingsToggleRow(
                            icon: "a.circle.fill",
                            iconColor: .accentColor,
                            title: "Đặt dấu oà, uý",
                            subtitle: "Dấu trên chữ (oà, uý) thay vì dưới (òa, úy)",
                            isOn: $appState.useModernOrthography
                        )

                        SettingsDivider()

                        SettingsToggleRow(
                            icon: "hare.fill",
                            iconColor: .accentColor,
                            title: "Gõ nhanh (Quick Telex)",
                            subtitle: "Gõ cc → ch, gg → gi, kk → kh, nn → ng...",
                            isOn: $appState.quickTelex
                        )
                    }
                }

                // Advanced Consonants
                SettingsCard(title: "Phụ âm nâng cao", icon: "character.textbox") {
                    VStack(spacing: 0) {
                        SettingsToggleRow(
                            icon: "character",
                            iconColor: .accentColor,
                            title: "Phụ âm Z, F, W, J",
                            subtitle: "Cho phép nhập các phụ âm ngoại lai",
                            isOn: $appState.allowConsonantZFWJ
                        )

                        SettingsDivider()

                        SettingsToggleRow(
                            icon: "arrow.right.circle.fill",
                            iconColor: .accentColor,
                            title: "Phụ âm đầu nhanh",
                            subtitle: "Gõ f → ph, j → gi, w → qu...",
                            isOn: $appState.quickStartConsonant
                        )

                        SettingsDivider()

                        SettingsToggleRow(
                            icon: "arrow.left.circle.fill",
                            iconColor: .accentColor,
                            title: "Phụ âm cuối nhanh",
                            subtitle: "Gõ g → ng, h → nh, k → ch...",
                            isOn: $appState.quickEndConsonant
                        )
                    }
                }

                Spacer(minLength: 20)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
        }
        .settingsBackground()
    }
}

// MARK: - Reusable Components

struct StatusCard: View {
    let hasPermission: Bool

    var body: some View {
        HStack(spacing: 16) {
            Image(
                systemName: hasPermission
                    ? "checkmark.shield.fill" : "exclamationmark.triangle.fill"
            )
            .font(.system(size: 32))
            .foregroundStyle(hasPermission ? Color.accentColor : .orange)

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
                    .tint(hasPermission ? .accentColor : .orange)
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
        .frame(maxWidth: 700)
        .background {
            if #available(macOS 26.0, *) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
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
            .background(Color(NSColor.controlBackgroundColor).opacity(0.15))

            Divider()
                .opacity(0.5)

            // Content
            content
                .padding(16)
        }
        .frame(maxWidth: 700)
        .background {
            if #available(macOS 26.0, *) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
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
            // Icon background - no glass effect to avoid glass-on-glass
            // (parent SettingsCard already has glass effect)
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.12))
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
                    .lineLimit(1)
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
                // Icon background - no glass effect to avoid glass-on-glass
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor.opacity(0.12))
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
            .onChange(of: value) { newVal in
                onValueChanged?(newVal)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Restore Key Button Component
struct RestoreKeyButton: View {
    let key: RestoreKey
    let isSelected: Bool
    let themeColor: Color
    let action: () -> Void

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
                if #available(macOS 26.0, *) {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(themeColor)
                            .shadow(color: themeColor.opacity(0.3), radius: 4, x: 0, y: 2)
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.ultraThinMaterial)
                            .glassEffect(in: .rect(cornerRadius: 10))
                    }
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? themeColor : Color(NSColor.controlBackgroundColor))
                        .shadow(color: isSelected ? themeColor.opacity(0.3) : Color.clear, radius: 4, x: 0, y: 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isSelected ? Color.clear : Color.gray.opacity(0.25), lineWidth: 1)
                        )
                }
            }
            .scaleEffect(isSelected ? 1.0 : 0.98)
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

#Preview {
    TypingSettingsView()
        .environmentObject(AppState.shared)
        .frame(width: 500, height: 800)
}
