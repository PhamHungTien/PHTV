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
                    .adaptiveProminentButtonStyle()
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
                    .adaptiveProminentButtonStyle()
                    .controlSize(.small)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: 700)
        .background {
            if #available(macOS 26.0, *), SettingsVisualEffects.enableMaterials {
                PHTVRoundedRect(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .settingsGlassEffect(cornerRadius: 12)
            } else {
                PHTVRoundedRect(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .compositingGroup()
                    .overlay(
                        PHTVRoundedRect(cornerRadius: 12)
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
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

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
            // Header - compact design
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tint)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)

                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                trailing
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(headerRowBackground)

            SettingsDivider()

            // Content
            content
                .padding(14)
        }
        .clipShape(PHTVRoundedRect(cornerRadius: 12, style: .continuous))
        .frame(maxWidth: 700)
        .background(cardBackground)
    }

    @ViewBuilder
    private var cardBackground: some View {
        let fillColor = Color(NSColor.controlBackgroundColor).opacity(colorScheme == .light ? 0.95 : 0.62)
        if SettingsVisualEffects.enableMaterials, !reduceTransparency {
            PHTVRoundedRect(cornerRadius: 12)
                .fill(.regularMaterial)
                .overlay(SettingsSurfaceBorder(cornerRadius: 12))
        } else {
            PHTVRoundedRect(cornerRadius: 12)
                .fill(fillColor)
                .overlay(SettingsSurfaceBorder(cornerRadius: 12))
        }
    }

    @ViewBuilder
    private var headerRowBackground: some View {
        if SettingsVisualEffects.enableMaterials {
            ZStack {
                // Base layer for contrast
                if colorScheme == .dark {
                    Color.black.opacity(0.25)
                } else {
                    Color.primary.opacity(0.04)
                }

                // Pronounced accent tint
                Color.accentColor.opacity(colorScheme == .dark ? 0.08 : 0.05)

                // Modern gradient for depth
                LinearGradient(
                    colors: [
                        Color.primary.opacity(colorScheme == .dark ? 0.1 : 0.05),
                        Color.primary.opacity(colorScheme == .dark ? 0.02 : 0.01)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        } else {
            ZStack {
                Color(NSColor.controlBackgroundColor).opacity(colorScheme == .light ? 0.78 : 0.5)
                Color.accentColor.opacity(colorScheme == .light ? 0.04 : 0.08)
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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Compact icon
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(iconColor)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(iconColor)
                .accessibilityLabel(Text(title))
                .accessibilityHint(Text(subtitle))
        }
        .padding(.vertical, 5)
    }
}

struct SettingsDivider: View {
    var leadingInset: CGFloat = 36
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let outer = Color.black.opacity(colorScheme == .dark ? 0.55 : 0.12)
        let highlight = Color.white.opacity(colorScheme == .dark ? 0.12 : 0.5)
        Rectangle()
            .fill(outer)
            .frame(height: 1)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(highlight)
                    .frame(height: 0.5)
            }
            .padding(.leading, leadingInset)
    }
}

// MARK: - Restore Key Button Component
struct RestoreKeyButton: View {
    let key: RestoreKey
    let isSelected: Bool
    let themeColor: Color
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

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
                if isSelected {
                    PHTVRoundedRect(cornerRadius: 10)
                        .fill(themeColor)
                } else {
                    // Clearer unselected state with subtle fill and visible border
                    PHTVRoundedRect(cornerRadius: 10)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(colorScheme == .dark ? 0.5 : 0.8))
                        .overlay(
                            PHTVRoundedRect(cornerRadius: 10)
                                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.2 : 0.15), lineWidth: 1)
                        )
                }
            }
            .scaleEffect(isSelected ? 1.0 : 1.0)
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
