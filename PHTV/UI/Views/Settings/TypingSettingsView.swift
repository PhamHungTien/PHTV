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
                SettingsHeaderView(
                    title: "Bộ gõ tiếng Việt",
                    subtitle: "Thiết lập phương pháp gõ, chính tả và các tối ưu để gõ nhanh, đúng.",
                    icon: "keyboard.fill"
                ) {
                    VStack(alignment: .trailing, spacing: 6) {
                        SettingsStatusPill(
                            text: appState.isEnabled ? "Chế độ: Tiếng Việt" : "Chế độ: Tiếng Anh",
                            color: appState.isEnabled ? .accentColor : .secondary
                        )
                        SettingsStatusPill(
                            text: appState.inputMethod.displayName,
                            color: .compatTeal
                        )
                    }
                }

                // Status Card
                StatusCard(hasPermission: appState.hasAccessibilityPermission)

                // Input Configuration
                SettingsCard(
                    title: "Thiết lập bộ gõ",
                    subtitle: "Chọn phương pháp gõ và bảng mã phù hợp",
                    icon: "keyboard.fill"
                ) {
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
                SettingsCard(
                    title: "Cơ bản",
                    subtitle: "Các tính năng hỗ trợ gõ tiếng Việt",
                    icon: "checkmark.circle.fill"
                ) {
                    VStack(spacing: 0) {
                        SettingsToggleRow(
                            icon: "text.badge.checkmark",
                            iconColor: .accentColor,
                            title: "Kiểm tra chính tả",
                            subtitle: "Phát hiện lỗi chính tả khi gõ tiếng Việt",
                            isOn: $appState.checkSpelling
                        )

                        SettingsDivider()

                        SettingsToggleRow(
                            icon: "arrow.uturn.left.circle.fill",
                            iconColor: .accentColor,
                            title: "Hoàn tác khi từ sai",
                            subtitle: "Trả lại ký tự gốc khi từ không hợp lệ",
                            isOn: $appState.restoreOnInvalidWord
                        )

                        SettingsDivider()

                        SettingsToggleRow(
                            icon: "textformat.abc.dottedunderline",
                            iconColor: .accentColor,
                            title: "Giữ nguyên từ tiếng Anh",
                            subtitle: "Không biến đổi từ tiếng Anh khi đang gõ tiếng Việt (vd: tẻminal → terminal)",
                            isOn: $appState.autoRestoreEnglishWord
                        )
                    }
                }

                // Restore to Raw Keys Feature
                SettingsCard(
                    title: "Khôi phục ký tự",
                    subtitle: "Hoàn tác nhanh khi gõ sai",
                    icon: "arrow.uturn.backward.circle.fill"
                ) {
                    VStack(spacing: 16) {
                        SettingsToggleRow(
                            icon: "arrow.uturn.backward.circle.fill",
                            iconColor: .accentColor,
                            title: "Hoàn tác về ký tự gốc",
                            subtitle: "Dùng phím hoàn tác để trả về ký tự trước khi biến đổi",
                            isOn: $appState.restoreOnEscape
                        )

                        if appState.restoreOnEscape {
                            Divider()

                            VStack(alignment: .leading, spacing: 12) {
                                Text("Chọn phím hoàn tác")
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

                                        Text("Phím hoàn tác trùng với phím bổ trợ của phím tắt chuyển chế độ")
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
                SettingsCard(
                    title: "Tối ưu gõ",
                    subtitle: "Tăng tốc và cải thiện trải nghiệm",
                    icon: "wand.and.stars"
                ) {
                    VStack(spacing: 0) {
                        SettingsToggleRow(
                            icon: "textformat.abc",
                            iconColor: .accentColor,
                            title: "Viết hoa đầu câu",
                            subtitle: "Tự động viết hoa sau dấu kết thúc câu",
                            isOn: $appState.upperCaseFirstChar
                        )

                        SettingsDivider()

                        SettingsToggleRow(
                            icon: "a.circle.fill",
                            iconColor: .accentColor,
                            title: "Chính tả mới (oà, uý)",
                            subtitle: "Ưu tiên dấu trên chữ (oà, uý) thay vì òa, úy",
                            isOn: $appState.useModernOrthography
                        )

                        SettingsDivider()

                        SettingsToggleRow(
                            icon: "hare.fill",
                            iconColor: .accentColor,
                            title: "Gõ nhanh Telex",
                            subtitle: "Tăng tốc: cc→ch, gg→gi, kk→kh, nn→ng…",
                            isOn: $appState.quickTelex
                        )
                    }
                }

                // Advanced Consonants
                SettingsCard(
                    title: "Phụ âm mở rộng",
                    subtitle: "Hỗ trợ các tổ hợp nâng cao",
                    icon: "character.textbox"
                ) {
                    VStack(spacing: 0) {
                        SettingsToggleRow(
                            icon: "character",
                            iconColor: .accentColor,
                            title: "Cho phép Z/F/W/J",
                            subtitle: "Hỗ trợ phụ âm ngoại lai khi cần",
                            isOn: $appState.allowConsonantZFWJ
                        )

                        SettingsDivider()

                        SettingsToggleRow(
                            icon: "arrow.right.circle.fill",
                            iconColor: .accentColor,
                            title: "Phụ âm đầu nhanh",
                            subtitle: "Gõ tắt: f→ph, j→gi, w→qu…",
                            isOn: $appState.quickStartConsonant
                        )

                        SettingsDivider()

                        SettingsToggleRow(
                            icon: "arrow.left.circle.fill",
                            iconColor: .accentColor,
                            title: "Phụ âm cuối nhanh",
                            subtitle: "Gõ tắt: g→ng, h→nh, k→ch…",
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
                if #available(macOS 26.0, *) {
                    Button("Mở cài đặt quyền") {
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
                    Button("Mở cài đặt quyền") {
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

struct SettingsCard<Content: View, Trailing: View>: View {
    let title: String
    let subtitle: String?
    let icon: String
    let trailing: Trailing
    let content: Content

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
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.tint)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)

                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer()

                trailing
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
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
        HStack(alignment: .top, spacing: 14) {
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
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(iconColor)
                .padding(.top, 2)
                .accessibilityLabel(Text(title))
                .accessibilityHint(Text(subtitle))
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
            HStack(alignment: .top, spacing: 14) {
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
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Text(valueFormatter(value))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.tint)
                    .frame(minWidth: 40, alignment: .trailing)
                    .padding(.top, 2)
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
