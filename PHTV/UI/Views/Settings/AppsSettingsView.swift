//
//  AppsSettingsView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

struct AppsSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var claudeCodeStatus: ClaudeCodeStatus = .checking
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    @State private var isConverting = false
    @State private var convertProgress = ""
    @State private var canOpenTerminal = false
    @State private var wasBinaryInstall = false
    @State private var showingExcludedFilePicker = false
    @State private var showingExcludedRunningApps = false
    @State private var showingStepByStepFilePicker = false
    @State private var showingStepByStepRunningApps = false

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
                SettingsHeaderView(
                    title: "Ứng dụng & Tương thích",
                    subtitle: "Quản lý chuyển đổi theo từng ứng dụng và tối ưu khả năng tương thích.",
                    icon: "square.stack.3d.up.fill"
                ) {
                    VStack(alignment: .trailing, spacing: 6) {
                        SettingsStatusPill(
                            text: "Loại trừ: \(appState.excludedApps.count)",
                            color: .compatTeal
                        )
                        SettingsStatusPill(
                            text: appState.sendKeyStepByStep ? "Gửi theo từng phím: Bật" : "Gửi theo từng phím: Tắt",
                            color: appState.sendKeyStepByStep ? .accentColor : .secondary
                        )
                    }
                }

                // Smart Switch
                SettingsCard(
                    title: "Chuyển đổi theo ứng dụng",
                    subtitle: "Tự chuyển Việt/Anh và ghi nhớ bảng mã",
                    icon: "brain.fill"
                ) {
                    VStack(spacing: 0) {
                        SettingsToggleRow(
                            icon: "arrow.left.arrow.right",
                            iconColor: .accentColor,
                            title: "Tự chuyển theo ứng dụng",
                            subtitle: "Tự động chuyển Việt/Anh theo ứng dụng đang dùng",
                            isOn: $appState.useSmartSwitchKey
                        )

                        SettingsDivider()

                        SettingsToggleRow(
                            icon: "memorychip.fill",
                            iconColor: .accentColor,
                            title: "Ghi nhớ bảng mã",
                            subtitle: "Lưu bảng mã riêng cho từng ứng dụng",
                            isOn: $appState.rememberCode
                        )
                    }
                }

                // Excluded Apps
                SettingsCard(
                    title: "Loại trừ ứng dụng",
                    subtitle: "Tự chuyển sang tiếng Anh khi dùng các ứng dụng này",
                    icon: "app.badge.fill",
                    trailing: {
                        Menu {
                            Button(action: { showingExcludedRunningApps = true }) {
                                Label("Chọn từ ứng dụng đang chạy", systemImage: "apps.iphone")
                            }

                            Button(action: { showingExcludedFilePicker = true }) {
                                Label("Chọn từ thư mục Applications", systemImage: "folder")
                            }
                        } label: {
                            Label("Thêm", systemImage: "plus.circle.fill")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    }
                ) {
                    ExcludedAppsView(
                        showingFilePicker: $showingExcludedFilePicker,
                        showingRunningApps: $showingExcludedRunningApps,
                        showHeader: false
                    )
                }

                // Send Key Step By Step
                SettingsCard(
                    title: "Gửi theo từng phím",
                    subtitle: "Tăng ổn định khi một số ứng dụng không nhận đủ ký tự",
                    icon: "keyboard.badge.ellipsis"
                ) {
                    SettingsToggleRow(
                        icon: "keyboard.badge.ellipsis",
                        iconColor: .accentColor,
                        title: "Bật gửi theo từng phím",
                        subtitle: "Gửi từng ký tự một (chậm nhưng ổn định)",
                        isOn: $appState.sendKeyStepByStep
                    )
                }

                // Send Key Step By Step Apps
                SettingsCard(
                    title: "Ứng dụng gửi từng phím",
                    subtitle: "Tự động bật gửi theo từng phím trong các ứng dụng này",
                    icon: "app.badge.fill",
                    trailing: {
                        Menu {
                            Button(action: { showingStepByStepRunningApps = true }) {
                                Label("Chọn từ ứng dụng đang chạy", systemImage: "apps.iphone")
                            }

                            Button(action: { showingStepByStepFilePicker = true }) {
                                Label("Chọn từ thư mục Applications", systemImage: "folder")
                            }
                        } label: {
                            Label("Thêm", systemImage: "plus.circle.fill")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    }
                ) {
                    SendKeyStepByStepAppsView(
                        showingFilePicker: $showingStepByStepFilePicker,
                        showingRunningApps: $showingStepByStepRunningApps,
                        showHeader: false
                    )
                }

                // Compatibility
                SettingsCard(
                    title: "Tương thích nâng cao",
                    subtitle: "Tùy chọn cho ứng dụng và bố cục đặc biệt",
                    icon: "puzzlepiece.extension.fill"
                ) {
                    VStack(spacing: 0) {
                        // Keyboard Layout Compatibility
                        SettingsToggleRow(
                            icon: "keyboard.fill",
                            iconColor: .accentColor,
                            title: "Tương thích bố cục bàn phím",
                            subtitle: "Hỗ trợ Dvorak, Colemak và các bố cục đặc biệt",
                            isOn: $appState.performLayoutCompat
                        )

                        SettingsDivider()

                        // Claude Code Fix
                        claudeCodeToggleRow

                        SettingsDivider()

                        // Safe Mode
                        SettingsToggleRow(
                            icon: "shield.fill",
                            iconColor: .accentColor,
                            title: "Bật chế độ an toàn",
                            subtitle: "Tự phục hồi khi Accessibility API gặp lỗi",
                            isOn: $appState.safeMode
                        )

                        if appState.safeMode {
                            SettingsDivider()

                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.accentColor.opacity(0.12))
                                        .frame(width: 36, height: 36)

                                    Image(systemName: "info.circle.fill")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(Color.accentColor)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Gợi ý cho máy Mac cũ")
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
            .frame(maxWidth: .infinity)
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
                return "Đang kiểm tra…"
            case .notInstalled:
                return "Chưa phát hiện Claude Code"
            case .nativeBinaryInstall:
                return isConverting ? convertProgress : "Bật để chuyển sang bản npm (hỗ trợ gõ tiếng Việt)"
            case .homebrewInstall:
                return isConverting ? convertProgress : "Bật để chuyển sang bản npm (hỗ trợ gõ tiếng Việt)"
            case .canPatch:
                return appState.claudeCodePatchEnabled ? "Đang bật" : "Khắc phục lỗi không nhận dấu tiếng Việt"
            }
        }()

        let iconColor: Color = {
            switch claudeCodeStatus {
            case .checking, .canPatch:
                return .accentColor
            case .notInstalled:
                return .secondary
            case .nativeBinaryInstall, .homebrewInstall:
                return isConverting ? .accentColor : .orange
            }
        }()

        let isDisabled = claudeCodeStatus == .checking || claudeCodeStatus == .notInstalled || isConverting
        let showProgress = claudeCodeStatus == .checking || isConverting

        ClaudeCodeToggleRow(
            iconColor: iconColor,
            title: "Hỗ trợ gõ tiếng Việt cho Claude Code",
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
                        .controlSize(.small)
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)
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
                    .lineLimit(1)
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
    AppsSettingsView()
        .environmentObject(AppState.shared)
        .frame(width: 500, height: 600)
}
