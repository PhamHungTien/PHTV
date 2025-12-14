//
//  MacroSettingsView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

struct MacroSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var macros: [MacroItem] = []
    @State private var selectedMacro: UUID?
    @State private var showingAddMacro = false

    var body: some View {
        VStack(spacing: 0) {
            // Configuration Header
            VStack(spacing: 16) {
                // Main Toggle
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                appState.useMacro
                                    ? Color.blue.opacity(0.12) : Color.gray.opacity(0.12)
                            )
                            .frame(width: 48, height: 48)

                        Image(systemName: "text.badge.plus")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(appState.useMacro ? .blue : .secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Gõ tắt")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text(appState.useMacro ? "Đang bật" : "Đang tắt")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: $appState.useMacro)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .tint(.blue)
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(10)

                // Options
                VStack(spacing: 12) {
                    MacroOptionButton(
                        icon: "globe",
                        title: "Bật trong chế độ tiếng Anh",
                        isOn: $appState.useMacroInEnglishMode,
                        disabled: !appState.useMacro
                    )

                    MacroOptionButton(
                        icon: "textformat.abc",
                        title: "Tự động viết hoa ký tự đầu",
                        isOn: $appState.autoCapsMacro,
                        disabled: !appState.useMacro
                    )
                }
            }
            .padding(20)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Toolbar
            HStack(spacing: 12) {
                Button(action: { showingAddMacro = true }) {
                    Image(systemName: "plus.circle.fill")
                    Text("Thêm")
                }
                .buttonStyle(.bordered)
                .disabled(!appState.useMacro)

                Button(action: { deleteMacro() }) {
                    Image(systemName: "minus.circle.fill")
                    Text("Xóa")
                }
                .buttonStyle(.bordered)
                .disabled(selectedMacro == nil || !appState.useMacro)

                Button(action: { editMacro() }) {
                    Image(systemName: "pencil.circle.fill")
                    Text("Chỉnh sửa")
                }
                .buttonStyle(.bordered)
                .disabled(selectedMacro == nil || !appState.useMacro)

                Spacer()

                Text("\(macros.count) gõ tắt")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.gray.opacity(0.15)))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

            Divider()

            // Content
            if macros.isEmpty {
                EmptyMacroView(useMacro: appState.useMacro, onAdd: { showingAddMacro = true })
            } else {
                MacroListView(macros: macros, selectedMacro: $selectedMacro)
            }
        }
        .sheet(isPresented: $showingAddMacro) {
            MacroEditorView(isPresented: $showingAddMacro)
                .environmentObject(appState)
                .onDisappear {
                    loadMacros()
                }
        }
        .onAppear {
            loadMacros()
        }
    }

    private func loadMacros() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: "macroList"),
            let loadedMacros = try? JSONDecoder().decode([MacroItem].self, from: data)
        {
            macros = loadedMacros
        } else {
            macros = []
        }
    }

    private func deleteMacro() {
        guard let selectedId = selectedMacro,
            let index = macros.firstIndex(where: { $0.id == selectedId })
        else {
            return
        }

        macros.remove(at: index)
        selectedMacro = nil
        saveMacros()
    }

    private func editMacro() {
        // Edit functionality: delete old and add new
        deleteMacro()
    }

    private func saveMacros() {
        let defaults = UserDefaults.standard
        if let encoded = try? JSONEncoder().encode(macros) {
            defaults.set(encoded, forKey: "macroList")
            // Removed synchronize() - let UserDefaults auto-save periodically for better performance
            // Notify backend to reload macro data
            NotificationCenter.default.post(name: NSNotification.Name("MacrosUpdated"), object: nil)
        }
    }
}

// MARK: - Subviews

struct MacroOptionButton: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool
    let disabled: Bool

    var body: some View {
        Button(action: { isOn.toggle() }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))

                Text(title)
                    .font(.subheadline)

                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(isOn ? .green : .secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isOn ? Color.blue.opacity(0.1) : Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                isOn ? Color.blue.opacity(0.3) : Color.gray.opacity(0.2),
                                lineWidth: 1)
                    )
            )
            .foregroundStyle(disabled ? .secondary : .primary)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
    }
}

struct EmptyMacroView: View {
    let useMacro: Bool
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "text.badge.plus")
                    .font(.system(size: 36))
                    .foregroundStyle(.blue)
            }

            VStack(spacing: 8) {
                Text("Chưa có gõ tắt")
                    .font(.title3)
                    .fontWeight(.semibold)
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
            .controlSize(.large)
            .disabled(!useMacro)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
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
            Image(systemName: "text.badge.plus")
                .foregroundStyle(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(macro.shortcut)
                    .font(.body)
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
