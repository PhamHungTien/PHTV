//
//  SendKeyStepByStepAppsView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers

struct SendKeyStepByStepAppsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingFilePicker = false
    @State private var showingRunningApps = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ứng dụng gửi từng phím")
                        .font(.headline)

                    Text("Tự động bật chức năng gửi từng phím khi sử dụng các ứng dụng này")
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
            if appState.sendKeyStepByStepApps.isEmpty {
                EmptySendKeyStepByStepAppsView()
            } else {
                SendKeyStepByStepAppsList(apps: appState.sendKeyStepByStepApps) { app in
                    appState.removeSendKeyStepByStepApp(app)
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
            SendKeyStepByStepRunningAppsPickerView { apps in
                for app in apps {
                    appState.addSendKeyStepByStepApp(app)
                }
            }
        }
    }

    private func handleFilePickerResult(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result else { return }

        for url in urls {
            if let app = SendKeyStepByStepApp(from: url) {
                appState.addSendKeyStepByStepApp(app)
            }
        }
    }
}

// MARK: - Empty State View
private struct EmptySendKeyStepByStepAppsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "keyboard.badge.ellipsis")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)

            Text("Chưa có ứng dụng nào được thêm")
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

// MARK: - Send Key Step By Step Apps List
private struct SendKeyStepByStepAppsList: View {
    let apps: [SendKeyStepByStepApp]
    let onRemove: (SendKeyStepByStepApp) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(apps) { app in
                SendKeyStepByStepAppRow(app: app) {
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

// MARK: - Send Key Step By Step App Row
private struct SendKeyStepByStepAppRow: View {
    let app: SendKeyStepByStepApp
    let onRemove: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // App Icon
            SendKeyStepByStepAppIconView(path: app.path)
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
private struct SendKeyStepByStepAppIconView: View {
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
struct SendKeyStepByStepRunningAppsPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: ([SendKeyStepByStepApp]) -> Void

    @State private var runningApps: [SendKeyStepByStepApp] = []
    @State private var selectedApps: Set<String> = []
    @State private var searchText = ""

    var filteredApps: [SendKeyStepByStepApp] {
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
                        SendKeyStepByStepRunningAppRow(
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
            .compactMap { app -> SendKeyStepByStepApp? in
                guard let bundleId = app.bundleIdentifier,
                      let name = app.localizedName,
                      let url = app.bundleURL
                else { return nil }
                return SendKeyStepByStepApp(bundleIdentifier: bundleId, name: name, path: url.path)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        // Remove duplicates
        var seen = Set<String>()
        runningApps = apps.filter { seen.insert($0.bundleIdentifier).inserted }
    }
}

// MARK: - Running App Row
private struct SendKeyStepByStepRunningAppRow: View {
    let app: SendKeyStepByStepApp
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
                SendKeyStepByStepAppIconView(path: app.path)
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
    SendKeyStepByStepAppsView()
        .environmentObject(AppState.shared)
        .frame(width: 400)
        .padding()
}
