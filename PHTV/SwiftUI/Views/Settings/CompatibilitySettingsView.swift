//
//  CompatibilitySettingsView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

struct CompatibilitySettingsView: View {
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
        case notInstalled
        case nativeBinaryInstall
        case homebrewInstall
        case canPatch
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Browser Compatibility
                SettingsCard(title: "Trình duyệt", icon: "globe") {
                    VStack(spacing: 0) {
                        SettingsToggleRow(
                            icon: "globe",
                            iconColor: themeManager.themeColor,
                            title: "Sửa lỗi Chromium",
                            subtitle: "Tương thích Chrome, Edge, Brave, Arc...",
                            isOn: $appState.fixChromiumBrowser
                        )
                    }
                }

                // Keyboard Layout Compatibility
                SettingsCard(title: "Bàn phím", icon: "keyboard.fill") {
                    VStack(spacing: 0) {
                        SettingsToggleRow(
                            icon: "keyboard.fill",
                            iconColor: themeManager.themeColor,
                            title: "Tương thích bố cục bàn phím",
                            subtitle: "Hỗ trợ Dvorak, Colemak và các bố cục đặc biệt",
                            isOn: $appState.performLayoutCompat
                        )
                    }
                }

                // Claude Code Fix
                SettingsCard(title: "Claude Code", icon: "terminal.fill") {
                    VStack(spacing: 0) {
                        claudeCodeToggleRow
                    }
                }

                // Safe Mode
                SettingsCard(title: "Chế độ an toàn", icon: "shield.lefthalf.filled") {
                    VStack(spacing: 0) {
                        SettingsToggleRow(
                            icon: "shield.fill",
                            iconColor: themeManager.themeColor,
                            title: "Bật chế độ an toàn",
                            subtitle: "Tự động khôi phục khi Accessibility API gặp lỗi",
                            isOn: $appState.safeMode
                        )

                        if appState.safeMode {
                            SettingsDivider()

                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(themeManager.themeColor.opacity(0.12))
                                        .frame(width: 36, height: 36)

                                    Image(systemName: "info.circle.fill")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(themeManager.themeColor)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Dành cho máy Mac cũ")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)

                                    Text("Khuyến nghị cho Mac chạy OpenCore Legacy Patcher (OCLP) hoặc gặp vấn đề ổn định với Accessibility API.")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
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

// MARK: - Claude Code Toggle Row

private struct ClaudeCodeToggleRow: View {
    let iconColor: Color
    let title: String
    let subtitle: String
    let showProgress: Bool
    let isDisabled: Bool
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
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
    CompatibilitySettingsView()
        .environmentObject(AppState.shared)
        .environmentObject(ThemeManager.shared)
        .frame(width: 500, height: 600)
}
