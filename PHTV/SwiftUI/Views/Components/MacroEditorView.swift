//
//  MacroEditorView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

struct MacroEditorView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var appState: AppState
    @State private var macroName = ""
    @State private var macroCode = ""
    @State private var errorMessage = ""
    @State private var showError = false

    // Edit mode support
    var editingMacro: MacroItem? = nil
    var isEditMode: Bool { editingMacro != nil }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(isEditMode ? "Chỉnh sửa gõ tắt" : "Thêm gõ tắt mới")
                    .font(.headline)
                Spacer()
                Button("Đóng") {
                    isPresented = false
                }
            }

            Form {
                Section("Tên gõ tắt") {
                    TextField("Ví dụ: tvn (Việt Nam)", text: $macroName)
                        .settingsTextField()
                        .textFieldStyle(.roundedBorder)
                }

                Section("Nội dung") {
                    TextEditor(text: $macroCode)
                        .frame(minHeight: 100)
                        .font(.system(.body, design: .monospaced))
                        .roundedTextArea()
                }
            }

            HStack {
                Spacer()
                Button("Hủy", role: .cancel) {
                    isPresented = false
                }
                Button("Lưu") {
                    saveMacro()
                }
                .buttonStyle(.borderedProminent)
                .disabled(macroName.isEmpty || macroCode.isEmpty)
            }
            .padding()
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
        .alert("Lỗi", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            // Initialize fields if editing
            if let macro = editingMacro {
                macroName = macro.shortcut
                macroCode = macro.expansion
            }
        }
    }

    private func saveMacro() {
        // Validate input
        guard !macroName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Vui lòng nhập tên gõ tắt"
            showError = true
            return
        }

        guard !macroCode.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Vui lòng nhập nội dung"
            showError = true
            return
        }

        // Load existing macros
        let defaults = UserDefaults.standard
        var macros = loadMacros()
        var trimmedName = macroName.trimmingCharacters(in: .whitespaces)
        var trimmedCode = macroCode.trimmingCharacters(in: .whitespaces)
        // Normalize Unicode to NFC to avoid duplicate variants and ensure stable encoding
        trimmedName = (trimmedName as NSString).precomposedStringWithCanonicalMapping
        trimmedCode = (trimmedCode as NSString).precomposedStringWithCanonicalMapping

        if isEditMode {
            guard let editingMacro else {
                errorMessage = "Không tìm thấy gõ tắt để chỉnh sửa"
                showError = true
                return
            }

            // EDIT MODE: Prefer matching by id to allow renaming
            let matchById = macros.firstIndex(where: { $0.id == editingMacro.id })
            let matchByName = macros.firstIndex(where: {
                $0.shortcut.lowercased() == editingMacro.shortcut.lowercased()
            })

            guard let index = matchById ?? matchByName else {
                errorMessage = "Không tìm thấy gõ tắt để chỉnh sửa"
                showError = true
                return
            }

            // Prevent duplicate names when renaming
            if trimmedName.lowercased() != editingMacro.shortcut.lowercased(),
               macros.contains(where: {
                   $0.id != editingMacro.id &&
                   $0.shortcut.lowercased() == trimmedName.lowercased()
               }) {
                errorMessage = "Gõ tắt '\(trimmedName)' đã tồn tại"
                showError = true
                return
            }

            print("[MacroEditor] Editing macro: \(editingMacro.shortcut)")
            macros[index].shortcut = trimmedName
            macros[index].expansion = trimmedCode
            print("[MacroEditor] Updated to: \(trimmedName) -> \(trimmedCode)")
        } else {
            // ADD MODE: Check if macro already exists
            if macros.contains(where: { $0.shortcut.lowercased() == trimmedName.lowercased() }) {
                errorMessage = "Gõ tắt '\(trimmedName)' đã tồn tại"
                showError = true
                return
            }

            // Add new macro
            let newMacro = MacroItem(
                shortcut: trimmedName,
                expansion: trimmedCode)
            macros.append(newMacro)
            print("[MacroEditor] Added new macro: \(newMacro.shortcut) -> \(newMacro.expansion)")

            // Auto-enable macro feature when creating first macro
            if !appState.useMacro {
                appState.useMacro = true
                print("[MacroEditor] Auto-enabled macro feature")
            }
        }

        // Sort macros by shortcut for stable order
        macros.sort { $0.shortcut.localizedCompare($1.shortcut) == .orderedAscending }

        // Save to UserDefaults atomically then notify immediately (no artificial delay)
        if let encoded = try? JSONEncoder().encode(macros) {
            defaults.set(encoded, forKey: "macroList")
            defaults.synchronize()
            print("[MacroEditor] Saved \(macros.count) macros to UserDefaults")
            print("[MacroEditor] macroList data size: \(encoded.count) bytes")

            // Post notification immediately; AppDelegate will rebuild macroData synchronously
            NotificationCenter.default.post(name: NSNotification.Name("MacrosUpdated"), object: nil)
            print("[MacroEditor] Notification posted")

            // Close the editor promptly
            isPresented = false
        } else {
            errorMessage = "Không thể lưu gõ tắt"
            showError = true
            print("[MacroEditor] ERROR: Failed to encode macros")
        }
    }

    private func loadMacros() -> [MacroItem] {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: "macroList"),
            let macros = try? JSONDecoder().decode([MacroItem].self, from: data)
        {
            return macros
        }
        return []
    }
}

struct MacroEditorView_Previews: PreviewProvider {
    static var previews: some View {
        MacroEditorView(isPresented: .constant(true))
    }
}

