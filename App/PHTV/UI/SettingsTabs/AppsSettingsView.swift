//
//  AppsSettingsView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI
import Observation

struct AppsSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var showingAlwaysEnglishFilePicker = false
    @State private var showingAlwaysEnglishRunningApps = false
    @State private var showingAlwaysEnglishBundleIdInput = false
    @State private var showingStepByStepFilePicker = false
    @State private var showingStepByStepRunningApps = false
    @State private var showingStepByStepBundleIdInput = false
    private var bindable: Bindable<AppState> { Bindable(appState) }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: SettingsLayout.sectionSpacing) {
                // Remember Per-App State
                SettingsCard(
                    title: "Ghi nhớ chế độ theo ứng dụng",
                    subtitle: "Khôi phục chế độ gõ và bảng mã đã dùng gần nhất",
                    icon: "brain.fill"
                ) {
                    VStack(spacing: 0) {
                        SettingsToggleRow(
                            icon: "arrow.left.arrow.right",
                            iconColor: .accentColor,
                            title: "Ghi nhớ Việt/Anh",
                            subtitle: "Khôi phục chế độ gõ gần nhất của từng ứng dụng",
                            isOn: bindable.useSmartSwitchKey
                        )

                        SettingsDivider()

                        SettingsToggleRow(
                            icon: "memorychip.fill",
                            iconColor: .accentColor,
                            title: "Ghi nhớ bảng mã",
                            subtitle: "Lưu bảng mã riêng cho từng ứng dụng",
                            isOn: bindable.rememberCode
                        )
                    }
                }

                // Always-English Apps
                SettingsCard(
                    title: "Chỉ dùng tiếng Anh",
                    subtitle: "Khóa tiếng Việt và khôi phục chế độ khi rời ứng dụng",
                    icon: "lock.fill",
                    displaysSubtitle: true,
                    trailing: {
                        Menu {
                            Button(action: { showingAlwaysEnglishRunningApps = true }) {
                                Label("Chọn từ ứng dụng đang chạy", systemImage: "apps.iphone")
                            }

                            Button(action: { showingAlwaysEnglishFilePicker = true }) {
                                Label("Chọn từ thư mục Applications", systemImage: "folder")
                            }

                            Divider()

                            Button(action: { showingAlwaysEnglishBundleIdInput = true }) {
                                Label("Nhập Bundle ID thủ công", systemImage: "keyboard")
                            }
                        } label: {
                            Label("Thêm ứng dụng", systemImage: "plus.circle.fill")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    }
                ) {
                    AlwaysEnglishAppsView(
                        showingFilePicker: $showingAlwaysEnglishFilePicker,
                        showingRunningApps: $showingAlwaysEnglishRunningApps,
                        showingBundleIdInput: $showingAlwaysEnglishBundleIdInput,
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
                        isOn: bindable.sendKeyStepByStep
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
                            isOn: bindable.performLayoutCompat
                        )

                        SettingsDivider()

                        // Safe Mode
                        SettingsToggleRow(
                            icon: "shield.fill",
                            iconColor: .accentColor,
                            title: "Bật chế độ an toàn",
                            subtitle: "Tự phục hồi khi Accessibility API gặp lỗi",
                            isOn: bindable.safeMode
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

                Spacer(minLength: SettingsLayout.sectionSpacing)
            }
            .settingsPageFrame()
        }
        .settingsBackground()
    }
}

#Preview {
    AppsSettingsView()
        .environment(AppState.shared)
        .frame(width: 500, height: 600)
}
