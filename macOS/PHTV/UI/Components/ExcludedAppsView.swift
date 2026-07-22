//
//  ExcludedAppsView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

enum AppSelectionPickerDestination: String, Identifiable {
    case runningApps
    case applicationsFolder
    case bundleIdentifier

    var id: String { rawValue }
}

struct AppSelectionAddMenu: View {
    let title: String
    let onSelect: (AppSelectionPickerDestination) -> Void

    init(
        title: String = "Thêm",
        onSelect: @escaping (AppSelectionPickerDestination) -> Void
    ) {
        self.title = title
        self.onSelect = onSelect
    }

    var body: some View {
        Menu {
            Button {
                onSelect(.runningApps)
            } label: {
                Label("Ứng dụng đang chạy", systemImage: "macwindow")
            }

            Button {
                onSelect(.applicationsFolder)
            } label: {
                Label("Chọn trong Applications…", systemImage: "folder")
            }

            Divider()

            Button {
                onSelect(.bundleIdentifier)
            } label: {
                Label("Nhập Bundle ID…", systemImage: "number")
            }
        } label: {
            Label(title, systemImage: "plus")
        }
        .menuStyle(.borderlessButton)
        .controlSize(.small)
        .fixedSize()
        .accessibilityLabel("\(title) ứng dụng")
    }
}

struct AlwaysEnglishAppsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if appState.excludedApps.isEmpty {
                AppSelectionEmptyStateView(
                    iconName: "e.circle",
                    title: "Chưa có quy tắc ứng dụng",
                    subtitle: "Thêm ứng dụng rồi chọn Tự chuyển hoặc Khóa tiếng Anh",
                    showsQuickActions: false,
                    onPickRunningApps: {},
                    onPickFromApplications: {}
                )
                .transition(.opacity)
            } else {
                EnglishAppRulesList(
                    apps: appState.excludedApps,
                    onChangeBehavior: { app, behavior in
                        appState.updateExcludedApp(app, behavior: behavior)
                    },
                    onRemove: { app in
                        appState.removeExcludedApp(app)
                    }
                )
                .transition(.opacity)
            }

            priorityNote
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: appState.excludedApps)
    }

    private var priorityNote: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Image(systemName: "info.circle")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)

            Text("“Tự chuyển” vẫn cho phép bật tiếng Việt; “Khóa tiếng Anh” chặn bật tiếng Việt.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.top, 7)
        .padding(.bottom, 3)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - English App Rules
private struct EnglishAppRulesList: View {
    let apps: [ExcludedApp]
    let onChangeBehavior: (ExcludedApp, EnglishAppBehavior) -> Void
    let onRemove: (ExcludedApp) -> Void

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(apps) { app in
                EnglishAppRuleRow(
                    app: app,
                    onChangeBehavior: { onChangeBehavior(app, $0) },
                    onRemove: { onRemove(app) }
                )

                if app.id != apps.last?.id {
                    Divider()
                        .padding(.leading, 52)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

private struct EnglishAppRuleRow: View {
    let app: ExcludedApp
    let onChangeBehavior: (EnglishAppBehavior) -> Void
    let onRemove: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            AppSelectionIconView(path: app.path)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                Text(app.bundleIdentifier)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            Menu {
                ForEach(EnglishAppBehavior.allCases) { behavior in
                    Button {
                        onChangeBehavior(behavior)
                    } label: {
                        Label(
                            behavior.displayName,
                            systemImage: behavior == app.englishBehavior
                                ? "checkmark"
                                : behavior.systemImage
                        )
                    }
                }
            } label: {
                Label(
                    app.englishBehavior.displayName,
                    systemImage: app.englishBehavior.systemImage
                )
                .font(.system(size: 11.5, weight: .medium))
            }
            .menuStyle(.borderlessButton)
            .controlSize(.small)
            .fixedSize()
            .frame(width: 132, alignment: .trailing)
            .help(app.englishBehavior.helpText)
            .accessibilityLabel("Cách dùng tiếng Anh trong \(app.name)")
            .accessibilityValue(app.englishBehavior.displayName)

            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(isHovered ? Color.red : .secondary)
                    .imageScale(.medium)
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0.65)
            .help("Xóa \(app.name) khỏi danh sách")
            .accessibilityLabel("Xóa \(app.name)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isHovered ? Color.primary.opacity(0.05) : Color.clear)
        .onHover { isHovered = $0 }
        .contextMenu {
            ForEach(EnglishAppBehavior.allCases) { behavior in
                Button {
                    onChangeBehavior(behavior)
                } label: {
                    Label(
                        behavior.displayName,
                        systemImage: behavior == app.englishBehavior
                            ? "checkmark"
                            : behavior.systemImage
                    )
                }
            }

            Divider()

            Button("Xóa khỏi danh sách", role: .destructive, action: onRemove)
        }
    }
}

// MARK: - Empty State View
struct AppSelectionEmptyStateView: View {
    let iconName: String
    let title: String
    let subtitle: String
    let showsQuickActions: Bool
    let onPickRunningApps: () -> Void
    let onPickFromApplications: () -> Void

    init(
        iconName: String,
        title: String,
        subtitle: String,
        showsQuickActions: Bool = true,
        onPickRunningApps: @escaping () -> Void,
        onPickFromApplications: @escaping () -> Void
    ) {
        self.iconName = iconName
        self.title = title
        self.subtitle = subtitle
        self.showsQuickActions = showsQuickActions
        self.onPickRunningApps = onPickRunningApps
        self.onPickFromApplications = onPickFromApplications
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 20))
                .foregroundStyle(.tertiary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)

                if showsQuickActions {
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
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - App Selection List
struct AppSelectionList<Item: AppSelectionEntry>: View {
    let apps: [Item]
    let onRemove: (Item) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(apps) { app in
                AppSelectionRow(app: app) {
                    onRemove(app)
                }
                
                if app.id != apps.last?.id {
                    Divider()
                        .padding(.leading, 52)
                }
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: apps)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - App Row
struct AppSelectionRow<Item: AppSelectionEntry>: View {
    let app: Item
    let onRemove: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // App Icon
            AppSelectionIconView(path: app.path)
                .frame(width: 32, height: 32)
            
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
                    .foregroundStyle(isHovered ? Color.red : .secondary)
                    .imageScale(.medium)
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0.65)
            .help("Xóa \(app.name) khỏi danh sách")
            .accessibilityLabel("Xóa \(app.name)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isHovered ? Color.primary.opacity(0.05) : Color.clear)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Xóa khỏi danh sách", role: .destructive, action: onRemove)
        }
    }
}

// MARK: - App Icon View
struct AppSelectionIconView: View {
    let path: String
    var size: CGFloat = 32
    
    var body: some View {
        if let icon = AppIconCache.shared.icon(for: path, size: size) {
            Image(nsImage: icon)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "app.fill")
                .font(.system(size: size * 0.75))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Running Apps Picker
struct AppSelectionRunningAppsPickerView<Item: AppSelectionEntry>: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: ([Item]) -> Void
    
    @State private var runningApps: [Item] = []
    @State private var selectedApps: Set<String> = []
    @State private var searchText = ""
    
    var filteredApps: [Item] {
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
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal)
            
            // Apps List
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredApps) { app in
                        AppSelectionRunningAppRow(
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
        .task {
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
            .filter { $0.activationPolicy != .prohibited }
            .compactMap { app -> Item? in
                guard let bundleId = app.bundleIdentifier,
                      let name = app.localizedName,
                      let url = app.bundleURL
                else { return nil }
                return Item(bundleIdentifier: bundleId, name: name, path: url.path)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        
        // Remove duplicates
        var seen = Set<String>()
        runningApps = apps.filter { seen.insert($0.bundleIdentifier).inserted }
    }
}

struct RunningAppsPickerView: View {
    let onSelect: ([ExcludedApp]) -> Void

    var body: some View {
        AppSelectionRunningAppsPickerView(onSelect: onSelect)
    }
}

// MARK: - Running App Row
struct AppSelectionRunningAppRow<Item: AppSelectionEntry>: View {
    let app: Item
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
                AppSelectionIconView(path: app.path, size: 28)
                    .frame(width: 28, height: 28)
                
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

// MARK: - Manual Bundle ID Input
struct ManualBundleIdInputView: View {
    @Environment(\.dismiss) private var dismiss
    let onSubmit: (String) -> Void

    @State private var bundleId = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Nhập Bundle ID")
                    .font(.headline)

                Spacer()

                Button("Huỷ") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding()

            VStack(alignment: .leading, spacing: 8) {
                Text("Bundle ID của ứng dụng")
                    .font(.subheadline)
                    .fontWeight(.medium)

                TextField("com.example.app", text: $bundleId)
                    .settingsTextField()
                    .textFieldStyle(.roundedBorder)

                Text("Mẹo: Mở Terminal và chạy lệnh sau để tìm Bundle ID:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("osascript -e 'id of app \"Tên App\"'")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(6)
                    .textSelection(.enabled)
            }
            .padding(.horizontal)

            Spacer()

            Divider()

            HStack {
                Spacer()

                Button("Thêm") {
                    let trimmed = bundleId.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        onSubmit(trimmed)
                        dismiss()
                    }
                }
                .adaptiveProminentButtonStyle()
                .disabled(bundleId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .frame(width: 400, height: 280)
    }
}

#Preview {
    AlwaysEnglishAppsView()
        .environment(AppState.shared)
        .frame(width: 400)
        .padding()
}
