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
    @EnvironmentObject var appState: AppState
    @State private var showingFilePicker = false
    @State private var showingRunningApps = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ứng dụng loại trừ")
                        .font(.headline)
                    
                    Text("Tự động gõ tiếng Anh khi sử dụng các ứng dụng này")
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
            if appState.excludedApps.isEmpty {
                EmptyExcludedAppsView()
            } else {
                ExcludedAppsList(apps: appState.excludedApps) { app in
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
    }
    
    private func handleFilePickerResult(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result else { return }
        
        for url in urls {
            if let app = ExcludedApp(from: url) {
                appState.addExcludedApp(app)
            }
        }
    }
}

// MARK: - Empty State View
private struct EmptyExcludedAppsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "app.badge.checkmark")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            
            Text("Chưa có ứng dụng nào được loại trừ")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text("Nhấn \"Thêm\" để chọn ứng dụng")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor))
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            }
        )
    }
}

// MARK: - Excluded Apps List
private struct ExcludedAppsList: View {
    let apps: [ExcludedApp]
    let onRemove: (ExcludedApp) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(apps) { app in
                ExcludedAppRow(app: app) {
                    onRemove(app)
                }
                
                if app.id != apps.last?.id {
                    Divider()
                        .padding(.leading, 52)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}

// MARK: - Excluded App Row
private struct ExcludedAppRow: View {
    let app: ExcludedApp
    let onRemove: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // App Icon
            AppIconView(path: app.path)
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
private struct AppIconView: View {
    let path: String
    
    var body: some View {
        if let icon = NSWorkspace.shared.icon(forFile: path) as NSImage? {
            Image(nsImage: icon)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "app.fill")
                .font(.system(size: 24))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Running Apps Picker
struct RunningAppsPickerView: View {
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
                        RunningAppRow(
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
                .buttonStyle(.borderedProminent)
                .disabled(selectedApps.isEmpty)
            }
            .padding()
        }
        .frame(width: 400, height: 500)
        .onAppear {
            loadRunningApps()
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

// MARK: - Running App Row
private struct RunningAppRow: View {
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
                AppIconView(path: app.path)
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

#Preview {
    ExcludedAppsView()
        .environmentObject(AppState.shared)
        .frame(width: 400)
        .padding()
}
