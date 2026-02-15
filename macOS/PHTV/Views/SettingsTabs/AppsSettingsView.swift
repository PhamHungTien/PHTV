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
    @State private var showingExcludedFilePicker = false
    @State private var showingExcludedRunningApps = false
    @State private var showingExcludedBundleIdInput = false
    @State private var showingStepByStepFilePicker = false
    @State private var showingStepByStepRunningApps = false
    @State private var showingStepByStepBundleIdInput = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
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

                            Divider()

                            Button(action: { showingExcludedBundleIdInput = true }) {
                                Label("Nhập Bundle ID thủ công", systemImage: "keyboard")
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
                        showingBundleIdInput: $showingExcludedBundleIdInput,
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

                            Divider()

                            Button(action: { showingStepByStepBundleIdInput = true }) {
                                Label("Nhập Bundle ID thủ công", systemImage: "keyboard")
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
                        showingBundleIdInput: $showingStepByStepBundleIdInput,
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
                                    SettingsIconTile(color: .accentColor) {
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
    }
}

#Preview {
    AppsSettingsView()
        .environmentObject(AppState.shared)
        .frame(width: 500, height: 600)
}
