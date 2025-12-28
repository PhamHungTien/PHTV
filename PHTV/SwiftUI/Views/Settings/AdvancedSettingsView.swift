//
//  AdvancedSettingsView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

struct AdvancedSettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @State private var claudeCodeStatus: ClaudeCodeStatus = .checking
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    @State private var isConverting = false
    @State private var convertProgress = ""
    @State private var canOpenTerminal = false
    @State private var wasBinaryInstall = false

    enum ClaudeCodeStatus {
        case checking
        case notInstalled     // Claude Code chưa cài
        case nativeBinaryInstall  // Cài qua Native Install (binary) - cần chuyển sang npm
        case homebrewInstall  // Cài qua Homebrew - cần chuyển sang npm
        case canPatch         // Cài qua npm (JavaScript) - có thể patch
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Claude Code Fix
                SettingsCard(title: "Sửa lỗi Claude Code trong Terminal", icon: "terminal.fill") {
                    VStack(spacing: 0) {
                        claudeCodeToggleRow
                    }
                }

                // Advanced Typing Options
                SettingsCard(title: "Tùy chọn nâng cao", icon: "gearshape.2.fill") {
                    VStack(spacing: 0) {
                        SettingsToggleRow(
                            icon: "character",
                            iconColor: themeManager.themeColor,
                            title: "Phụ âm Z, F, W, J",
                            subtitle: "Cho phép nhập các phụ âm ngoại lai",
                            isOn: $appState.allowConsonantZFWJ
                        )

                        SettingsDivider()

                        SettingsToggleRow(
                            icon: "arrow.right.circle.fill",
                            iconColor: themeManager.themeColor,
                            title: "Phụ âm đầu nhanh",
                            subtitle: "Gõ nhanh phụ âm đầu",
                            isOn: $appState.quickStartConsonant
                        )

                        SettingsDivider()

                        SettingsToggleRow(
                            icon: "arrow.left.circle.fill",
                            iconColor: themeManager.themeColor,
                            title: "Phụ âm cuối nhanh",
                            subtitle: "Gõ nhanh phụ âm cuối",
                            isOn: $appState.quickEndConsonant
                        )

                        SettingsDivider()

                        SettingsToggleRow(
                            icon: "memorychip.fill",
                            iconColor: themeManager.themeColor,
                            title: "Nhớ bảng mã",
                            subtitle: "Lưu bảng mã khi đóng ứng dụng",
                            isOn: $appState.rememberCode
                        )
                    }
                }

                // Send Key Step By Step
                SettingsCard(title: "Gửi từng phím", icon: "keyboard.badge.ellipsis") {
                    VStack(spacing: 0) {
                        SettingsToggleRow(
                            icon: "keyboard.badge.ellipsis",
                            iconColor: themeManager.themeColor,
                            title: "Bật gửi từng phím",
                            subtitle: "Gửi từng ký tự một (chậm nhưng ổn định)",
                            isOn: $appState.sendKeyStepByStep
                        )
                    }
                }

                // Send Key Step By Step Apps
                SettingsCard(title: "Ứng dụng gửi từng phím", icon: "app.badge.fill") {
                    SendKeyStepByStepAppsView()
                }

                Spacer(minLength: 20)
            }
            .padding(20)
        }
        .settingsBackground()
        .onAppear {
            checkClaudeCodeStatus()
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            if canOpenTerminal {
                Button("Mở Terminal") {
                    ClaudeCodePatcher.shared.openTerminalWithInstallCommand(isHomebrew: wasBinaryInstall)
                }
                Button("Đóng", role: .cancel) {}
            } else {
                Button("OK", role: .cancel) {}
            }
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - Claude Code Status

    @ViewBuilder
    private var claudeCodeToggleRow: some View {
        let subtitle: String = {
            switch claudeCodeStatus {
            case .checking:
                return "Đang kiểm tra..."
            case .notInstalled:
                return "Claude Code chưa được cài đặt"
            case .nativeBinaryInstall:
                return isConverting ? convertProgress : "Bật để chuyển sang phiên bản npm (hỗ trợ tiếng Việt)"
            case .homebrewInstall:
                return isConverting ? convertProgress : "Bật để chuyển sang phiên bản npm (hỗ trợ tiếng Việt)"
            case .canPatch:
                return appState.claudeCodePatchEnabled ? "Đã bật ✓" : "Sửa lỗi không nhận dấu tiếng Việt"
            }
        }()

        let iconColor: Color = {
            switch claudeCodeStatus {
            case .checking, .canPatch:
                return themeManager.themeColor
            case .notInstalled:
                return .secondary
            case .nativeBinaryInstall, .homebrewInstall:
                return isConverting ? themeManager.themeColor : .orange
            }
        }()

        let isDisabled = claudeCodeStatus == .checking || claudeCodeStatus == .notInstalled || isConverting
        let showProgress = claudeCodeStatus == .checking || isConverting

        ClaudeCodeToggleRow(
            iconColor: iconColor,
            title: "Hỗ trợ gõ tiếng Việt trong Claude Code",
            subtitle: subtitle,
            showProgress: showProgress,
            isDisabled: isDisabled,
            isOn: Binding(
                get: {
                    claudeCodeStatus == .canPatch ? appState.claudeCodePatchEnabled : false
                },
                set: { newValue in
                    if (claudeCodeStatus == .nativeBinaryInstall || claudeCodeStatus == .homebrewInstall) && newValue && !isConverting {
                        convertToNpm()
                    } else if claudeCodeStatus == .canPatch {
                        if newValue {
                            applyClaudeCodePatch()
                        } else {
                            removeClaudeCodePatch()
                        }
                    }
                }
            )
        )
    }

    private func checkClaudeCodeStatus() {
        claudeCodeStatus = .checking

        DispatchQueue.global(qos: .userInitiated).async {
            let patcher = ClaudeCodePatcher.shared
            let installationType = patcher.getInstallationType()

            let status: ClaudeCodeStatus
            switch installationType {
            case .notInstalled:
                status = .notInstalled
            case .nativeBinary:
                status = .nativeBinaryInstall
            case .homebrew:
                status = .homebrewInstall
            case .npm:
                status = .canPatch
            }

            DispatchQueue.main.async {
                self.claudeCodeStatus = status
                // Sync toggle state with actual patch status
                if status == .canPatch {
                    self.appState.claudeCodePatchEnabled = patcher.isPatched()
                }
            }
        }
    }

    private func applyClaudeCodePatch() {
        canOpenTerminal = false
        let result = ClaudeCodePatcher.shared.applyPatch()
        switch result {
        case .success(let message):
            appState.claudeCodePatchEnabled = true
            alertTitle = "Thành công"
            alertMessage = message
        case .failure(let error):
            appState.claudeCodePatchEnabled = false
            alertTitle = "Lỗi"
            alertMessage = error.localizedDescription
        }
        showingAlert = true
    }

    private func removeClaudeCodePatch() {
        canOpenTerminal = false
        let result = ClaudeCodePatcher.shared.removePatch()
        switch result {
        case .success(let message):
            appState.claudeCodePatchEnabled = false
            alertTitle = "Thành công"
            alertMessage = message
        case .failure(let error):
            // Nếu không có backup, chỉ cần tắt toggle
            if case .noBackupFound = error {
                appState.claudeCodePatchEnabled = false
                return
            }
            alertTitle = "Lỗi"
            alertMessage = error.localizedDescription
        }
        showingAlert = true
    }

    private func convertToNpm() {
        isConverting = true
        convertProgress = "Đang bắt đầu..."
        wasBinaryInstall = (claudeCodeStatus == .nativeBinaryInstall || claudeCodeStatus == .homebrewInstall)

        ClaudeCodePatcher.shared.reinstallFromNpm(
            progress: { message in
                DispatchQueue.main.async {
                    self.convertProgress = message
                }
            },
            completion: { result in
                DispatchQueue.main.async {
                    self.isConverting = false

                    switch result {
                    case .success(let message):
                        self.alertTitle = "Thành công"
                        self.alertMessage = message
                        self.appState.claudeCodePatchEnabled = true
                        self.claudeCodeStatus = .canPatch
                        self.canOpenTerminal = false
                    case .failure(let error):
                        self.alertTitle = "Lỗi"
                        self.alertMessage = error.localizedDescription
                        self.canOpenTerminal = error.canOpenTerminal
                        self.checkClaudeCodeStatus()
                    }
                    self.showingAlert = true
                }
            }
        )
    }
}

// MARK: - Claude Code Toggle Row (matches SettingsToggleRow style)

private struct ClaudeCodeToggleRow: View {
    let iconColor: Color
    let title: String
    let subtitle: String
    let showProgress: Bool
    let isDisabled: Bool
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            // Icon background - no glass effect to avoid glass-on-glass
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 36, height: 36)

                if showProgress {
                    ProgressView()
                        .scaleEffect(0.6)
                } else {
                    Image(systemName: "terminal.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(iconColor)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(iconColor == .orange ? iconColor : .secondary)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(iconColor)
                .disabled(isDisabled)
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    AdvancedSettingsView()
        .environmentObject(AppState.shared)
        .environmentObject(ThemeManager.shared)
        .frame(width: 500, height: 600)
}
