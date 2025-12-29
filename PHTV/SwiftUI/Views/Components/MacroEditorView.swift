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
    @EnvironmentObject var themeManager: ThemeManager
    @State private var macroName: String
    @State private var macroCode: String
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var selectedCategoryId: UUID?
    @State private var snippetType: SnippetType

    // Edit mode support
    let editingMacro: MacroItem?
    var isEditMode: Bool { editingMacro != nil }

    // Category support - user categories only
    let categories: [MacroCategory]
    let defaultCategoryId: UUID?

    init(
        isPresented: Binding<Bool>,
        editingMacro: MacroItem? = nil,
        categories: [MacroCategory] = [],
        defaultCategoryId: UUID? = nil
    ) {
        self._isPresented = isPresented
        self.editingMacro = editingMacro
        self.categories = categories
        self.defaultCategoryId = defaultCategoryId

        // Initialize state with editing macro values or empty
        _macroName = State(initialValue: editingMacro?.shortcut ?? "")
        _macroCode = State(initialValue: editingMacro?.expansion ?? "")
        _selectedCategoryId = State(initialValue: editingMacro?.categoryId ?? defaultCategoryId)
        _snippetType = State(initialValue: editingMacro?.snippetType ?? .static)
    }

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

                Section("Loại nội dung") {
                    Picker("Loại", selection: $snippetType) {
                        ForEach(SnippetType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.menu)

                    Text(snippetType.helpText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section(snippetType == .static ? "Nội dung" : (snippetType == .clipboard ? "Ghi chú" : "Định dạng")) {
                    if snippetType == .clipboard {
                        Text("Nội dung từ clipboard sẽ được dán tự động")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                    } else {
                        TextEditor(text: $macroCode)
                            .frame(minHeight: snippetType == .static ? 100 : 60)
                            .font(.system(.body, design: .monospaced))
                            .roundedTextArea()

                        if snippetType != .static {
                            Text("Gợi ý: \(snippetType.placeholder)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Category picker - only show if there are custom categories
                if !categories.isEmpty {
                    Section("Danh mục") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                // "None" option - uncategorized
                                Button {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        selectedCategoryId = nil
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "tag.slash")
                                            .font(.system(size: 12))
                                        Text("Không có")
                                            .font(.subheadline)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(selectedCategoryId == nil ? Color.gray : Color(NSColor.controlBackgroundColor))
                                    )
                                    .foregroundStyle(selectedCategoryId == nil ? .white : .primary)
                                }
                                .buttonStyle(.plain)

                                // User categories
                                ForEach(categories) { category in
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            selectedCategoryId = category.id
                                        }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: category.icon)
                                                .font(.system(size: 12))
                                            Text(category.name)
                                                .font(.subheadline)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(selectedCategoryId == category.id ? category.swiftUIColor : Color(NSColor.controlBackgroundColor))
                                        )
                                        .foregroundStyle(selectedCategoryId == category.id ? .white : .primary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
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
                .tint(themeManager.themeColor)
                .disabled(macroName.isEmpty || (snippetType != .clipboard && macroCode.isEmpty))
            }
            .padding()
        }
        .padding()
        .frame(minWidth: 400, minHeight: categories.isEmpty ? 300 : 360)
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

        // For clipboard type, content is not required
        if snippetType != .clipboard {
            guard !macroCode.trimmingCharacters(in: .whitespaces).isEmpty else {
                errorMessage = "Vui lòng nhập nội dung"
                showError = true
                return
            }
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
            macros[index].categoryId = selectedCategoryId
            macros[index].snippetType = snippetType
            print("[MacroEditor] Updated to: \(trimmedName) -> \(trimmedCode), category: \(selectedCategoryId?.uuidString ?? "nil"), type: \(snippetType.rawValue)")
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
                expansion: trimmedCode,
                categoryId: selectedCategoryId,
                snippetType: snippetType)
            macros.append(newMacro)
            print("[MacroEditor] Added new macro: \(newMacro.shortcut) -> \(newMacro.expansion), category: \(selectedCategoryId?.uuidString ?? "nil"), type: \(snippetType.rawValue)")

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
        MacroEditorView(
            isPresented: .constant(true),
            categories: [
                MacroCategory(name: "Công việc", icon: "briefcase.fill", color: "#FF9500"),
                MacroCategory(name: "Email", icon: "envelope.fill", color: "#5856D6")
            ]
        )
        .environmentObject(AppState.shared)
        .environmentObject(ThemeManager.shared)
    }
}

