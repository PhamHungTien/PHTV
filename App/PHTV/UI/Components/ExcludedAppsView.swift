//
//  ExcludedAppsView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers

struct ExcludedAppsView: View {
    @Environment(AppState.self) private var appState
    @Binding var showingFilePicker: Bool
    @Binding var showingRunningApps: Bool
    @Binding var showingBundleIdInput: Bool
    @State private var manualBundleId = ""
    var showHeader: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if showHeader {
                header
            }
            
            // Apps List
            if appState.excludedApps.isEmpty {
                AppSelectionEmptyStateView(
                    iconName: "app.badge.checkmark",
                    title: "Chưa có ứng dụng nào",
                    subtitle: "Tự chuyển sang tiếng Anh khi dùng các ứng dụng này",
                    onPickRunningApps: { showingRunningApps = true },
                    onPickFromApplications: { showingFilePicker = true }
                )
            } else {
                AppSelectionList(apps: appState.excludedApps) { app in
                    appState.removeExcludedApp(app)
                }
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.application],
            allowsMultipleSelection: true
        ) { result in
            handleFilePickerResult(result)
        }
        .sheet(isPresented: $showingRunningApps) {
            RunningAppsPickerView { apps in
                for app in apps {
                    appState.addExcludedApp(app)
                }
            }
        }
        .sheet(isPresented: $showingBundleIdInput) {
            ManualBundleIdInputView { bundleId in
                let name = resolveAppName(for: bundleId)
                let app = ExcludedApp(bundleIdentifier: bundleId, name: name, path: "")
                appState.addExcludedApp(app)
            }
        }
    }

    private func resolveAppName(for bundleId: String) -> String {
        // Try to find the app name from running applications
        if let runningApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleId }),
           let name = runningApp.localizedName {
            return name
        }
        // Fallback: use last component of bundle ID as name
        return bundleId.components(separatedBy: ".").last ?? bundleId
    }

    private func handleFilePickerResult(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result else { return }
        
        for url in urls {
            if let app = ExcludedApp(from: url) {
                appState.addExcludedApp(app)
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Ứng dụng được loại trừ")
                    .font(.headline)
                
                Text("Tự chuyển sang tiếng Anh khi dùng các ứng dụng này")
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

                Divider()

                Button(action: {
                    manualBundleId = ""
                    showingBundleIdInput = true
                }) {
                    Label("Nhập Bundle ID thủ công", systemImage: "keyboard")
                }
            } label: {
                Label("Thêm", systemImage: "plus.circle.fill")
                    .font(.system(size: 13, weight: .medium))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }
}

// MARK: - Empty State View
struct AppSelectionEmptyStateView: View {
    let iconName: String
    let title: String
    let subtitle: String
    let onPickRunningApps: () -> Void
    let onPickFromApplications: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 24))
                .foregroundStyle(.tertiary)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)

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

// MARK: - Excluded Apps List
struct AppSelectionList<Item: AppSelectionEntry>: View {
    let apps: [Item]
    let onRemove: (Item) -> Void
    
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
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(4)
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
    ExcludedAppsView(
        showingFilePicker: .constant(false),
        showingRunningApps: .constant(false),
        showingBundleIdInput: .constant(false)
    )
        .environment(AppState.shared)
        .frame(width: 400)
        .padding()
}
