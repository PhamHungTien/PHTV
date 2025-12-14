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
                }

                Section("Nội dung") {
                    TextEditor(text: $macroCode)
                        .frame(minHeight: 100)
                        .font(.system(.body, design: .monospaced))
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
        let trimmedName = macroName.trimmingCharacters(in: .whitespaces)
        let trimmedCode = macroCode.trimmingCharacters(in: .whitespaces)

        if isEditMode {
            // EDIT MODE: Find and update existing macro
            if let index = macros.firstIndex(where: {
                $0.shortcut.lowercased() == editingMacro!.shortcut.lowercased()
            }) {
                print("[MacroEditor] Editing macro: \(editingMacro!.shortcut)")
                macros[index].expansion = trimmedCode
                // Don't change shortcut in edit mode
                print("[MacroEditor] Updated expansion to: \(trimmedCode)")
            } else {
                errorMessage = "Không tìm thấy gõ tắt để chỉnh sửa"
                showError = true
                return
            }
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
        }

        // Save to UserDefaults
        if let encoded = try? JSONEncoder().encode(macros) {
            defaults.set(encoded, forKey: "macroList")
            defaults.synchronize()
            print("[MacroEditor] Saved \(macros.count) macros to UserDefaults")
            print("[MacroEditor] macroList data size: \(encoded.count) bytes")

            // Important: Wait a tiny bit to ensure synchronize completes
            // Then post notification so AppDelegate reads fresh data
            print("[MacroEditor] Posting MacrosUpdated notification after 50ms delay")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                NotificationCenter.default.post(
                    name: NSNotification.Name("MacrosUpdated"), object: nil)
                print("[MacroEditor] Notification posted")
                // Close the editor after a short delay; no restart here
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    isPresented = true // ensure still presented until saved
                    isPresented = false // then close
                }
            }
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

#Preview {
    @Previewable @State var isPresented = true
    return MacroEditorView(isPresented: $isPresented)
}

