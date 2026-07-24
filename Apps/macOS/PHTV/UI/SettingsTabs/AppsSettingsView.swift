//
//  AppsSettingsView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import AppKit
import Observation
import SwiftUI
import UniformTypeIdentifiers

struct AppsSettingsView: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: SettingsLayout.sectionSpacing) {
                PerAppMemorySettingsCard()
                EnglishAppRulesSettingsCard()
                StepByStepSettingsCard()
                AdvancedCompatibilitySettingsCard()

                Spacer(minLength: SettingsLayout.sectionSpacing)
            }
            .settingsPageFrame()
        }
        .settingsBackground()
    }
}

// MARK: - Remember per-app state

private struct PerAppMemorySettingsCard: View {
    @Environment(AppState.self) private var appState
    private var bindable: Bindable<AppState> { Bindable(appState) }

    var body: some View {
        SettingsCard(
            title: "Ghi nhớ theo ứng dụng",
            subtitle: "Khôi phục chế độ gõ và bảng mã đã dùng gần nhất",
            icon: "brain.fill",
            displaysSubtitle: true
        ) {
            VStack(spacing: 0) {
                SettingsToggleRow(
                    icon: "arrow.left.arrow.right",
                    iconColor: .accentColor,
                    title: "Chế độ Việt/Anh",
                    subtitle: "Khôi phục chế độ gõ gần nhất của từng ứng dụng",
                    isOn: bindable.useSmartSwitchKey
                )

                SettingsDivider()

                SettingsToggleRow(
                    icon: "memorychip.fill",
                    iconColor: .accentColor,
                    title: "Bảng mã",
                    subtitle: "Lưu bảng mã riêng cho từng ứng dụng",
                    isOn: bindable.rememberCode
                )
            }
        }
    }
}

// MARK: - English rules

private struct EnglishAppRulesSettingsCard: View {
    @Environment(AppState.self) private var appState
    @State private var pickerDestination: AppSelectionPickerDestination?

    var body: some View {
        SettingsCard(
            title: "Tiếng Anh theo ứng dụng",
            subtitle: "Tự chuyển hoặc khóa tiếng Anh riêng cho từng ứng dụng",
            icon: "e.circle.fill",
            displaysSubtitle: true,
            trailing: {
                AppSelectionAddMenu {
                    pickerDestination = $0
                }
            }
        ) {
            AlwaysEnglishAppsView()
        }
        .fileImporter(
            isPresented: presentationBinding(for: .applicationsFolder),
            allowedContentTypes: [.application],
            allowsMultipleSelection: true,
            onCompletion: addEnglishApps(from:)
        )
        .sheet(isPresented: presentationBinding(for: .runningApps)) {
            RunningAppsPickerView { apps in
                apps.forEach(appState.addExcludedApp)
            }
        }
        .sheet(isPresented: presentationBinding(for: .bundleIdentifier)) {
            ManualBundleIdInputView { bundleIdentifier in
                let metadata = AppSelectionResolver.metadata(for: bundleIdentifier)
                appState.addExcludedApp(
                    ExcludedApp(
                        bundleIdentifier: bundleIdentifier,
                        name: metadata.name,
                        path: metadata.path
                    )
                )
            }
        }
    }

    private func addEnglishApps(from result: Result<[URL], Error>) {
        guard case .success(let urls) = result else { return }
        urls.compactMap(ExcludedApp.init(from:)).forEach(appState.addExcludedApp)
    }

    private func presentationBinding(
        for destination: AppSelectionPickerDestination
    ) -> Binding<Bool> {
        Binding(
            get: { pickerDestination == destination },
            set: { isPresented in
                if isPresented {
                    pickerDestination = destination
                } else if pickerDestination == destination {
                    pickerDestination = nil
                }
            }
        )
    }
}

// MARK: - Step-by-step compatibility

private struct StepByStepSettingsCard: View {
    @Environment(AppState.self) private var appState
    @State private var pickerDestination: AppSelectionPickerDestination?
    private var bindable: Bindable<AppState> { Bindable(appState) }

    var body: some View {
        SettingsCard(
            title: "Gửi từng phím",
            subtitle: "Bật cho mọi ứng dụng hoặc tự động bật ở ứng dụng đã chọn",
            icon: "keyboard.badge.ellipsis",
            displaysSubtitle: true,
            trailing: {
                AppSelectionAddMenu {
                    pickerDestination = $0
                }
            }
        ) {
            VStack(spacing: 0) {
                SettingsToggleRow(
                    icon: "keyboard.badge.ellipsis",
                    iconColor: .accentColor,
                    title: "Bật cho mọi ứng dụng",
                    subtitle: "Gửi từng ký tự một để tăng độ ổn định",
                    isOn: bindable.sendKeyStepByStep
                )

                SettingsDivider()

                SendKeyStepByStepAppsView()
            }
        }
        .fileImporter(
            isPresented: presentationBinding(for: .applicationsFolder),
            allowedContentTypes: [.application],
            allowsMultipleSelection: true,
            onCompletion: addStepByStepApps(from:)
        )
        .sheet(isPresented: presentationBinding(for: .runningApps)) {
            AppSelectionRunningAppsPickerView<SendKeyStepByStepApp> { apps in
                apps.forEach(appState.addSendKeyStepByStepApp)
            }
        }
        .sheet(isPresented: presentationBinding(for: .bundleIdentifier)) {
            ManualBundleIdInputView { bundleIdentifier in
                let metadata = AppSelectionResolver.metadata(for: bundleIdentifier)
                appState.addSendKeyStepByStepApp(
                    SendKeyStepByStepApp(
                        bundleIdentifier: bundleIdentifier,
                        name: metadata.name,
                        path: metadata.path
                    )
                )
            }
        }
    }

    private func addStepByStepApps(from result: Result<[URL], Error>) {
        guard case .success(let urls) = result else { return }
        urls.compactMap(SendKeyStepByStepApp.init(from:))
            .forEach(appState.addSendKeyStepByStepApp)
    }

    private func presentationBinding(
        for destination: AppSelectionPickerDestination
    ) -> Binding<Bool> {
        Binding(
            get: { pickerDestination == destination },
            set: { isPresented in
                if isPresented {
                    pickerDestination = destination
                } else if pickerDestination == destination {
                    pickerDestination = nil
                }
            }
        )
    }
}

// MARK: - Advanced compatibility

private struct AdvancedCompatibilitySettingsCard: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var bindable: Bindable<AppState> { Bindable(appState) }

    var body: some View {
        SettingsCard(
            title: "Tương thích nâng cao",
            subtitle: "Chỉ thay đổi khi bàn phím hoặc Accessibility hoạt động không ổn định",
            icon: "puzzlepiece.extension.fill",
            displaysSubtitle: true
        ) {
            VStack(spacing: 0) {
                SettingsToggleRow(
                    icon: "keyboard.fill",
                    iconColor: .accentColor,
                    title: "Bố cục bàn phím đặc biệt",
                    subtitle: "Hỗ trợ Dvorak, Colemak và các bố cục đặc biệt",
                    isOn: bindable.performLayoutCompat
                )

                SettingsDivider()

                SettingsToggleRow(
                    icon: "shield.fill",
                    iconColor: .accentColor,
                    title: "Chế độ an toàn",
                    subtitle: "Tự phục hồi khi Accessibility API gặp lỗi",
                    isOn: bindable.safeMode
                )

                if appState.safeMode {
                    SettingsDivider()

                    safeModeNote
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 0.18),
                value: appState.safeMode
            )
        }
    }

    private var safeModeNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(
                "Phù hợp với Mac chạy OpenCore Legacy Patcher (OCLP) "
                    + "hoặc thường gặp lỗi Accessibility."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}

private enum AppSelectionResolver {
    static func metadata(for bundleIdentifier: String) -> (name: String, path: String) {
        if let runningApp = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == bundleIdentifier
        }), let name = runningApp.localizedName {
            return (name, runningApp.bundleURL?.path ?? "")
        }

        if let appURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: bundleIdentifier
        ) {
            let bundle = Bundle(url: appURL)
            let name = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? appURL.deletingPathExtension().lastPathComponent
            return (name, appURL.path)
        }

        return (
            bundleIdentifier.components(separatedBy: ".").last ?? bundleIdentifier,
            ""
        )
    }
}

#Preview {
    AppsSettingsView()
        .environment(AppState.shared)
        .frame(width: 620, height: 680)
}
