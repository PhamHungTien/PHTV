//
//  MacroSettingsView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers

struct MacroSettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @State private var macros: [MacroItem] = []
    @State private var selectedMacro: UUID?
    @State private var showingAddMacro = false
    @State private var showingEditMacro = false
    @State private var editingMacro: MacroItem? = nil
    @State private var refreshTrigger = UUID()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Macro Configuration
                SettingsCard(title: "Cấu hình gõ tắt", icon: "text.badge.plus") {
                    VStack(spacing: 0) {
                        SettingsToggleRow(
                            icon: "text.badge.plus",
                            iconColor: themeManager.themeColor,
                            title: "Bật gõ tắt",
                            subtitle: appState.useMacro ? "Đang hoạt động" : "Đang tắt",
                            isOn: $appState.useMacro
                        )

                        SettingsDivider()

                        SettingsToggleRow(
                            icon: "globe",
                            iconColor: themeManager.themeColor,
                            title: "Bật trong chế độ tiếng Anh",
                            subtitle: "Cho phép gõ tắt khi đang ở chế độ tiếng Anh",
                            isOn: $appState.useMacroInEnglishMode
                        )
                        .disabled(!appState.useMacro)
                        .opacity(appState.useMacro ? 1 : 0.5)

                        SettingsDivider()

                        SettingsToggleRow(
                            icon: "textformat.abc",
                            iconColor: themeManager.themeColor,
                            title: "Tự động viết hoa ký tự đầu",
                            subtitle: "Viết hoa ký tự đầu tiên của từ mở rộng",
                            isOn: $appState.autoCapsMacro
                        )
                        .disabled(!appState.useMacro)
                        .opacity(appState.useMacro ? 1 : 0.5)
                    }
                }

                // Macro List
                SettingsCard(title: "Danh sách gõ tắt", icon: "list.bullet.rectangle") {
                    VStack(spacing: 0) {
                        // Toolbar
                        HStack(spacing: 12) {
                            Button(action: { showingAddMacro = true }) {
                                Label("Thêm", systemImage: "plus.circle.fill")
                                    .font(.subheadline)
                            }
                            .buttonStyle(.bordered)
                            .disabled(!appState.useMacro)

                            Button(action: { editMacro() }) {
                                Label("Sửa", systemImage: "pencil.circle.fill")
                                    .font(.subheadline)
                            }
                            .buttonStyle(.bordered)
                            .disabled(selectedMacro == nil || !appState.useMacro)

                            Button(action: { deleteMacro() }) {
                                Label("Xóa", systemImage: "minus.circle.fill")
                                    .font(.subheadline)
                            }
                            .buttonStyle(.bordered)
                            .disabled(selectedMacro == nil || !appState.useMacro)

                            Spacer()

                            Button(action: { importMacros() }) {
                                Label("Import", systemImage: "square.and.arrow.down")
                                    .font(.subheadline)
                            }
                            .buttonStyle(.bordered)
                            .disabled(!appState.useMacro)

                            Text("\(macros.count)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(themeManager.themeColor))
                        }
                        .padding(.bottom, 12)

                        Divider()
                            .padding(.bottom, 8)

                        // Content
                        if macros.isEmpty {
                            EmptyMacroView(useMacro: appState.useMacro, onAdd: {
                                showingAddMacro = true
                            })
                        } else {
                            MacroListView(macros: macros, selectedMacro: $selectedMacro)
                                .frame(height: 300)
                        }
                    }
                }

                Spacer(minLength: 20)
            }
            .padding(20)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(isPresented: $showingAddMacro) {
            MacroEditorView(isPresented: $showingAddMacro)
                .environmentObject(appState)
        }
        .sheet(isPresented: $showingEditMacro) {
            MacroEditorView(isPresented: $showingEditMacro, editingMacro: editingMacro)
                .environmentObject(appState)
        }
        .onAppear {
            loadMacros()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MacrosUpdated")))
        { _ in
            DispatchQueue.main.async {
                print("[MacroSettings] Received MacrosUpdated notification, reloading...")
                loadMacros()
                refreshTrigger = UUID()
            }
        }
    }

    private func loadMacros() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: "macroList"),
            let loadedMacros = try? JSONDecoder().decode([MacroItem].self, from: data)
        {
            macros = loadedMacros
            print(
                "[MacroSettings] Loaded \(loadedMacros.count) macros: \(loadedMacros.map { $0.shortcut }.joined(separator: ", "))"
            )
        } else {
            macros = []
            print("[MacroSettings] No macros found in UserDefaults")
        }
    }

    private func deleteMacro() {
        guard let selectedId = selectedMacro,
            let index = macros.firstIndex(where: { $0.id == selectedId })
        else {
            return
        }

        let deletedMacro = macros[index]
        macros.remove(at: index)
        selectedMacro = nil
        print(
            "[MacroSettings] Deleted macro: \(deletedMacro.shortcut) -> \(deletedMacro.expansion)")
        saveMacros()
    }

    private func editMacro() {
        guard let selectedId = selectedMacro,
            let macro = macros.first(where: { $0.id == selectedId })
        else {
            return
        }
        editingMacro = macro
        showingEditMacro = true
    }

    private func importMacros() {
        // macOS file picker
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.json, UTType.commaSeparatedText, UTType.plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "Chọn file gõ tắt (JSON/CSV)"

        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try Data(contentsOf: url)
                var imported: [MacroItem] = []

                if url.pathExtension.lowercased() == "json" {
                    // Expect array of {"shortcut": "...", "expansion": "..."}
                    struct RawMacro: Decodable { let shortcut: String; let expansion: String }
                    let raw = try JSONDecoder().decode([RawMacro].self, from: data)
                    imported = raw.map { MacroItem(shortcut: normalize($0.shortcut), expansion: normalize($0.expansion)) }
                } else {
                    // CSV/TXT: lines "shortcut,expansion"; ignore empty and comments (#)
                    if let text = String(data: data, encoding: .utf8) {
                        imported = text
                            .split(whereSeparator: { $0.isNewline })
                            .compactMap { line -> MacroItem? in
                                let s = String(line).trimmingCharacters(in: .whitespaces)
                                if s.isEmpty || s.hasPrefix("#") { return nil }
                                let parts = s.split(separator: ",", maxSplits: 1).map(String.init)
                                guard parts.count == 2 else { return nil }
                                let shortcut = normalize(parts[0])
                                let expansion = normalize(parts[1])
                                guard !shortcut.isEmpty, !expansion.isEmpty else { return nil }
                                return MacroItem(shortcut: shortcut, expansion: expansion)
                            }
                    }
                }

                // Merge: dedupe by shortcut (case-insensitive), prefer imported entries
                var map: [String: MacroItem] = [:]
                // Use normalized key for compare but keep original MacroItem to preserve id
                for m in macros {
                    let key = normalize(m.shortcut).lowercased()
                    map[key] = m
                }
                for m in imported {
                    let key = normalize(m.shortcut).lowercased()
                    map[key] = m
                }

                macros = Array(map.values)
                    .sorted { $0.shortcut.localizedCompare($1.shortcut) == .orderedAscending }
                saveMacros()
            } catch {
                print("[MacroSettings] Import failed: \(error.localizedDescription)")
            }
        }
    }

    private func normalize(_ s: String) -> String {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed as NSString).precomposedStringWithCanonicalMapping
    }

    private func saveMacros() {
        let defaults = UserDefaults.standard
        if let encoded = try? JSONEncoder().encode(macros) {
            defaults.set(encoded, forKey: "macroList")
            defaults.synchronize()
            print("[MacroSettings] Saved \(macros.count) macros to UserDefaults")
            print("[MacroSettings] macroList data size: \(encoded.count) bytes")
            // Notify immediately; backend rebuilds macroData synchronously
            NotificationCenter.default.post(name: NSNotification.Name("MacrosUpdated"), object: nil)
            print("[MacroSettings] Notification posted")
        } else {
            print("[MacroSettings] ERROR: Failed to encode macros")
        }
    }
}

// MARK: - Subviews

struct EmptyMacroView: View {
    let useMacro: Bool
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 64, height: 64)

                Image(systemName: "text.badge.plus")
                    .font(.system(size: 28))
                    .foregroundStyle(.tint)
            }

            VStack(spacing: 6) {
                Text("Chưa có gõ tắt")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("Tạo gõ tắt để nhập văn bản nhanh hơn")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: onAdd) {
                Label("Tạo gõ tắt đầu tiên", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(!useMacro)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

struct MacroListView: View {
    let macros: [MacroItem]
    @Binding var selectedMacro: UUID?

    var body: some View {
        List(macros, selection: $selectedMacro) { macro in
            MacroRowView(macro: macro)
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }
}

struct MacroRowView: View {
    let macro: MacroItem

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 32, height: 32)

                Image(systemName: "text.badge.plus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.tint)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(macro.shortcut)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Text(macro.expansion)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    MacroSettingsView()
        .environmentObject(AppState.shared)
        .frame(width: 500, height: 600)
}
