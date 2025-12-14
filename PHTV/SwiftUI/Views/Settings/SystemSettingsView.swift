//
//  SystemSettingsView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

struct SystemSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingResetAlert = false
    @State private var showingUpdateCheckStatus = false
    @State private var updateCheckMessage = ""
    @State private var updateCheckIsError = false
    @State private var isCheckingForUpdates = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Startup Settings
                SettingsCard(title: "Khởi động", icon: "power.circle.fill") {
                    VStack(spacing: 0) {
                        SettingsToggleRow(
                            icon: "play.fill",
                            iconColor: .green,
                            title: "Khởi động cùng hệ thống",
                            subtitle: "Tự động mở PHTV khi đăng nhập macOS",
                            isOn: $appState.runOnStartup
                        )

                        SettingsDivider()

                        SettingsToggleRow(
                            icon: "app.fill",
                            iconColor: .blue,
                            title: "Hiển thị icon trên Dock",
                            subtitle: "Hiện icon PHTV khi mở menu bảng điều khiển",
                            isOn: $appState.showIconOnDock
                        )
                    }
                }

                // Excluded Apps
                SettingsCard(title: "Loại trừ ứng dụng", icon: "app.badge.fill") {
                    ExcludedAppsView()
                }

                // Compatibility Settings
                SettingsCard(title: "Tương thích", icon: "puzzlepiece.extension.fill") {
                    VStack(spacing: 0) {
                        SettingsToggleRow(
                            icon: "globe",
                            iconColor: .blue,
                            title: "Sửa lỗi Chromium",
                            subtitle: "Tương thích Chrome, Edge, Brave...",
                            isOn: $appState.fixChromiumBrowser
                        )

                        SettingsDivider()

                        SettingsToggleRow(
                            icon: "keyboard.fill",
                            iconColor: .purple,
                            title: "Tương thích bố cục bàn phím",
                            subtitle: "Hỗ trợ các bố cục đặc biệt",
                            isOn: $appState.performLayoutCompat
                        )
                    }
                }

                // App Information
                SettingsCard(title: "Thông tin ứng dụng", icon: "info.circle.fill") {
                    VStack(spacing: 0) {
                        SettingsInfoRow(
                            icon: "number.circle.fill",
                            iconColor: .blue,
                            title: "Phiên bản",
                            value: Bundle.main.infoDictionary?["CFBundleShortVersionString"]
                                as? String ?? "1.0"
                        )

                        SettingsDivider()

                        SettingsInfoRow(
                            icon: "hammer.fill",
                            iconColor: .orange,
                            title: "Build",
                            value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
                        )

                        SettingsDivider()

                        SettingsButtonRow(
                            icon: isCheckingForUpdates
                                ? "hourglass.circle.fill" : "arrow.clockwise.circle.fill",
                            iconColor: .green,
                            title: isCheckingForUpdates ? "Đang kiểm tra..." : "Kiểm tra cập nhật",
                            subtitle: "Tìm phiên bản mới",
                            isLoading: isCheckingForUpdates,
                            action: {
                                checkForUpdates()
                            }
                        )
                    }
                }

                // Data Management
                SettingsCard(title: "Quản lý dữ liệu", icon: "externaldrive.fill") {
                    VStack(spacing: 0) {
                        SettingsButtonRow(
                            icon: "arrow.counterclockwise.circle.fill",
                            iconColor: .red,
                            title: "Đặt lại cài đặt",
                            subtitle: "Khôi phục mặc định",
                            isDestructive: true,
                            action: {
                                showingResetAlert = true
                            }
                        )
                    }
                }

                Spacer(minLength: 20)
            }
            .padding(20)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .alert("Đặt lại cài đặt?", isPresented: $showingResetAlert) {
            Button("Hủy", role: .cancel) {}
            Button("Đặt lại", role: .destructive) {
                resetToDefaults()
            }
        } message: {
            Text("Tất cả cài đặt sẽ được khôi phục về mặc định. Hành động này không thể hoàn tác.")
        }
        .alert("Kiểm tra cập nhật", isPresented: $showingUpdateCheckStatus) {
            if !updateCheckIsError && updateCheckMessage.contains("có sẵn") {
                Button("Hủy", role: .cancel) {}
                Button("Tải xuống") {
                    // Prefer dynamic URL from update.json if you later store it in state
                    if let url = URL(string: "https://github.com/PhamHungTien/PHTV/releases/latest") {
                        NSWorkspace.shared.open(url)
                    }
                }
            } else {
                Button("OK") {}
            }
        } message: {
            Text(updateCheckMessage)
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSNotification.Name("CheckForUpdatesResponse"))
        ) { notification in
            handleUpdateCheckResponse(notification)
        }
    }

    private func resetToDefaults() {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.loadDefaultConfig()
            // Post notification to trigger UI refresh across the app
            NotificationCenter.default.post(name: NSNotification.Name("SettingsReset"), object: nil)
            // Reload settings with a small delay to ensure UserDefaults is synchronized
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                appState.loadSettings()
            }
        }
    }

    private func checkForUpdates() {
        isCheckingForUpdates = true
        updateCheckMessage = ""
        updateCheckIsError = false

        struct UpdateInfo: Decodable {
            let latestVersion: String
            let downloadURL: String?
            let message: String?
        }

        DispatchQueue.global(qos: .userInitiated).async {
            // Compute results off the main actor using local immutable copies
            let computed: (message: String, isError: Bool) = {
                guard let url = Bundle.main.url(forResource: "update", withExtension: "json"),
                      let data = try? Data(contentsOf: url) else {
                    return ("Không tìm thấy thông tin cập nhật trong ứng dụng.", true)
                }

                do {
                    let info = try JSONDecoder().decode(UpdateInfo.self, from: data)
                    let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"

                    if current.compare(info.latestVersion, options: .numeric) == .orderedAscending {
                        // Có bản mới
                        if let msg = info.message, !msg.isEmpty {
                            return (msg, false)
                        } else {
                            return ("Bản \(info.latestVersion) có sẵn. Bạn muốn tải xuống?", false)
                        }
                    } else {
                        return ("Phiên bản hiện tại là mới nhất", false)
                    }
                } catch {
                    return ("Không thể đọc thông tin cập nhật.", true)
                }
            }()

            DispatchQueue.main.async {
                self.isCheckingForUpdates = false
                self.updateCheckMessage = computed.message
                self.updateCheckIsError = computed.isError
                self.showingUpdateCheckStatus = true
            }
        }
    }

    private func handleUpdateCheckResponse(_ notification: Notification) {
        isCheckingForUpdates = false

        if let response = notification.object as? [String: Any] {
            if let message = response["message"] as? String {
                updateCheckMessage = message
            }
            if let isError = response["isError"] as? Bool {
                updateCheckIsError = isError
            }
        } else {
            updateCheckMessage = "Phiên bản hiện tại là mới nhất"
        }

        showingUpdateCheckStatus = true
    }
}

// MARK: - Settings Row Components

struct SettingsInfoRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(iconColor)
            }

            Text(title)
                .font(.body)
                .foregroundStyle(.primary)

            Spacer()

            Text(value)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

struct SettingsButtonRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    var isDestructive: Bool = false
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 36, height: 36)

                    if isLoading {
                        ProgressView()
                            .tint(iconColor)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(iconColor)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(isDestructive ? .red : .primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !isLoading {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

#Preview {
    SystemSettingsView()
        .environmentObject(AppState.shared)
        .frame(width: 500, height: 600)
}
