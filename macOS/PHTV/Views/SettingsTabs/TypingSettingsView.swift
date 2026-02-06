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
    @State private var showingUpperCaseFilePicker = false
    @State private var showingUpperCaseRunningApps = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
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

                // Status Card (only show when permission is missing)
                if !appState.hasAccessibilityPermission {
                    StatusCard(hasPermission: false)
                }

                // Input Configuration
                SettingsCard(
                    title: "Thiết lập bộ gõ",
                    subtitle: "Chọn phương pháp gõ và bảng mã phù hợp",
                    icon: "keyboard.fill"
                ) {
                    VStack(spacing: 12) {
                        // Input Method Picker - inline style
                        HStack {
                            Text("Phương pháp gõ")
                                .font(.body)
                                .foregroundStyle(.primary)

                            Spacer()

                            Picker("", selection: $appState.inputMethod) {
                                ForEach(InputMethod.allCases) { method in
                                    Text(method.displayName).tag(method)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 140)
                        }

                        Divider()

                        // Code Table Picker - inline style
                        HStack {
                            Text("Bảng mã")
                                .font(.body)
                                .foregroundStyle(.primary)

                            Spacer()

                            Picker("", selection: $appState.codeTable) {
                                ForEach(CodeTable.allCases) { table in
                                    Text(table.displayName).tag(table)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 140)
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
                            icon: "textformat.abc.dottedunderline",
                            iconColor: .accentColor,
                            title: "Kiểm tra chính tả",
                            subtitle: "Tự động sửa lỗi khi gõ sai cấu trúc tiếng Việt",
                            isOn: $appState.checkSpelling
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
                            icon: "textformat.abc",
                            iconColor: .accentColor,
                            title: "Viết hoa đầu câu",
                            subtitle: "Tự động viết hoa sau dấu kết thúc câu",
                            isOn: $appState.upperCaseFirstChar
                        )

                        // Upper Case Excluded Apps (only show when feature is enabled)
                        if appState.upperCaseFirstChar {
                            SettingsDivider()

                            UpperCaseExcludedAppsSection(
                                showingFilePicker: $showingUpperCaseFilePicker,
                                showingRunningApps: $showingUpperCaseRunningApps
                            )
                        }

                        SettingsDivider()

                        SettingsToggleRow(
                            icon: "text.magnifyingglass",
                            iconColor: .accentColor,
                            title: "Tự động khôi phục tiếng Anh",
                            subtitle: "Không biến đổi từ tiếng Anh khi đang gõ tiếng Việt",
                            isOn: $appState.autoRestoreEnglishWord
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
                    title: "Phụ âm nhanh",
                    subtitle: "Gõ tắt phụ âm đầu và cuối",
                    icon: "character.textbox"
                ) {
                    VStack(spacing: 0) {
                        SettingsToggleRow(
                            icon: "character.cursor.ibeam",
                            iconColor: .accentColor,
                            title: "Phụ âm Z, F, W, J",
                            subtitle: "Cho phép gõ các phụ âm không có trong tiếng Việt",
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

// Components moved to SettingsComponents.swift


// MARK: - Upper Case Excluded Apps Section

struct UpperCaseExcludedAppsSection: View {
    @EnvironmentObject var appState: AppState
    @Binding var showingFilePicker: Bool
    @Binding var showingRunningApps: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with add button
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ứng dụng không viết hoa")
                        .font(.headline)
                    Text("Tắt viết hoa đầu câu khi dùng các ứng dụng này")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Menu {
                    Button(action: { showingRunningApps = true }) {
                        Label("Chọn từ ứng dụng đang chạy", systemImage: "apps.iphone")
                    }

                    Button(action: { showingFilePicker = true }) {
                        Label("Chọn từ thư mục Applications", systemImage: "folder")
                    }
                } label: {
                    Label("Thêm", systemImage: "plus.circle.fill")
                        .font(.system(size: 13, weight: .medium))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            // Apps List
            if appState.upperCaseExcludedApps.isEmpty {
                UpperCaseEmptyAppsView(
                    onPickRunningApps: { showingRunningApps = true },
                    onPickFromApplications: { showingFilePicker = true }
                )
            } else {
                UpperCaseExcludedAppsList(apps: appState.upperCaseExcludedApps) { app in
                    appState.removeUpperCaseExcludedApp(app)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.application],
            allowsMultipleSelection: true
        ) { result in
            handleFilePickerResult(result)
        }
        .sheet(isPresented: $showingRunningApps) {
            UpperCaseRunningAppsPickerView { apps in
                for app in apps {
                    appState.addUpperCaseExcludedApp(app)
                }
            }
        }
    }

    private func handleFilePickerResult(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result else { return }

        for url in urls {
            if let app = ExcludedApp(from: url) {
                appState.addUpperCaseExcludedApp(app)
            }
        }
    }
}

// MARK: - Upper Case Empty Apps View

private struct UpperCaseEmptyAppsView: View {
    let onPickRunningApps: () -> Void
    let onPickFromApplications: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "app.badge.checkmark")
                .font(.system(size: 24))
                .foregroundStyle(.tertiary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Chưa có ứng dụng nào")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    Button("Đang chạy") {
                        onPickRunningApps()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.accentColor)

                    Text("•")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)

                    Button("Applications") {
                        onPickFromApplications()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.accentColor)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            if #available(macOS 26.0, *), SettingsVisualEffects.enableMaterials {
                PHTVRoundedRect(cornerRadius: 8)
                    .fill(.ultraThinMaterial)
                    .settingsGlassEffect(cornerRadius: 8)
                    .overlay(
                        PHTVRoundedRect(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                    )
            } else {
                ZStack {
                    PHTVRoundedRect(cornerRadius: 8)
                        .fill(Color(NSColor.controlBackgroundColor))
                    PHTVRoundedRect(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                }
            }
        }
    }
}

// MARK: - Upper Case Excluded Apps List

private struct UpperCaseExcludedAppsList: View {
    let apps: [ExcludedApp]
    let onRemove: (ExcludedApp) -> Void

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(apps) { app in
                UpperCaseExcludedAppRow(app: app) {
                    onRemove(app)
                }

                if app.id != apps.last?.id {
                    Divider()
                        .padding(.leading, 52)
                }
            }
        }
        .background {
            if #available(macOS 26.0, *), SettingsVisualEffects.enableMaterials {
                PHTVRoundedRect(cornerRadius: 10)
                    .fill(.ultraThinMaterial)
                    .settingsGlassEffect(cornerRadius: 10)
            } else {
                PHTVRoundedRect(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor))
            }
        }
    }
}

// MARK: - Upper Case Excluded App Row

private struct UpperCaseExcludedAppRow: View {
    let app: ExcludedApp
    let onRemove: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // App Icon
            if let icon = AppIconCache.shared.icon(for: app.path, size: 32) {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
            }

            // App Info
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                Text(app.bundleIdentifier)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Remove Button
            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red)
                    .imageScale(.medium)
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0.5)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isHovered ? Color.primary.opacity(0.05) : Color.clear)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Upper Case Running Apps Picker

struct UpperCaseRunningAppsPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: ([ExcludedApp]) -> Void

    @State private var runningApps: [ExcludedApp] = []
    @State private var selectedApps: Set<String> = []
    @State private var searchText = ""

    var filteredApps: [ExcludedApp] {
        if searchText.isEmpty {
            return runningApps
        }
        return runningApps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Chọn ứng dụng")
                    .font(.headline)

                Spacer()

                Button("Huỷ") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding()

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Tìm kiếm...", text: $searchText)
                    .settingsTextField()
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal)

            // Apps List
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredApps) { app in
                        UpperCaseRunningAppRow(
                            app: app,
                            isSelected: selectedApps.contains(app.bundleIdentifier)
                        ) {
                            if selectedApps.contains(app.bundleIdentifier) {
                                selectedApps.remove(app.bundleIdentifier)
                            } else {
                                selectedApps.insert(app.bundleIdentifier)
                            }
                        }

                        if app.id != filteredApps.last?.id {
                            Divider()
                                .padding(.leading, 52)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(maxHeight: 300)

            Divider()

            // Footer
            HStack {
                Text("\(selectedApps.count) ứng dụng được chọn")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Thêm") {
                    let appsToAdd = runningApps.filter { selectedApps.contains($0.bundleIdentifier) }
                    onSelect(appsToAdd)
                    dismiss()
                }
                .adaptiveProminentButtonStyle()
                .disabled(selectedApps.isEmpty)
            }
            .padding()
        }
        .frame(width: 400, height: 500)
        .onAppear {
            loadRunningApps()
        }
        .onDisappear {
            runningApps = []
            selectedApps = []
            searchText = ""
        }
    }

    private func loadRunningApps() {
        let workspace = NSWorkspace.shared
        let apps = workspace.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> ExcludedApp? in
                guard let bundleId = app.bundleIdentifier,
                      let name = app.localizedName,
                      let url = app.bundleURL
                else { return nil }
                return ExcludedApp(bundleIdentifier: bundleId, name: name, path: url.path)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        // Remove duplicates
        var seen = Set<String>()
        runningApps = apps.filter { seen.insert($0.bundleIdentifier).inserted }
    }
}

// MARK: - Upper Case Running App Row

private struct UpperCaseRunningAppRow: View {
    let app: ExcludedApp
    let isSelected: Bool
    let onToggle: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Checkbox
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .imageScale(.large)

                // App Icon
                if let icon = AppIconCache.shared.icon(for: app.path, size: 28) {
                    Image(nsImage: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                }

                // App Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(app.bundleIdentifier)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isHovered ? Color.primary.opacity(0.05) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

#Preview {
    TypingSettingsView()
        .environmentObject(AppState.shared)
        .frame(width: 500, height: 800)
}
