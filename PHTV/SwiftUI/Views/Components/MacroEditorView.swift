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

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Thêm gõ tắt mới")
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

        // Check if macro already exists
        if macros.contains(where: { $0.shortcut.lowercased() == macroName.lowercased() }) {
            errorMessage = "Gõ tắt '\(macroName)' đã tồn tại"
            showError = true
            return
        }

        // Add new macro
        let newMacro = MacroItem(
            shortcut: macroName.trimmingCharacters(in: .whitespaces),
            expansion: macroCode.trimmingCharacters(in: .whitespaces))
        macros.append(newMacro)

        // Save to UserDefaults
        if let encoded = try? JSONEncoder().encode(macros) {
            defaults.set(encoded, forKey: "macroList")
            // Removed synchronize() - let UserDefaults auto-save periodically for better performance

            // Update macro data for backend
            updateMacroDataForBackend(macros)

            isPresented = false
        } else {
            errorMessage = "Không thể lưu gõ tắt"
            showError = true
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

    private func updateMacroDataForBackend(_ macros: [MacroItem]) {
        // Notify backend to reload macro data
        NotificationCenter.default.post(name: NSNotification.Name("MacrosUpdated"), object: nil)
    }
}

#Preview {
    @Previewable @State var isPresented = true
    return MacroEditorView(isPresented: $isPresented)
}
