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
    @State private var macros: [MacroItem] = []
    @State private var selectedMacro: UUID?
    @State private var showingAddMacro = false
    @State private var editingMacro: MacroItem? = nil  // nil = not editing, set to show edit sheet

    // Animation and highlight states
    @State private var recentlyAddedId: UUID? = nil
    @State private var recentlyEditedId: UUID? = nil
    // Category states
    @State private var selectedCategoryId: UUID? = nil  // nil = show all
    @State private var showingAddCategory = false
    @State private var editingCategory: MacroCategory? = nil  // nil = not editing, set to show edit sheet

    private static var cachedMacrosData: Data?
    private static var cachedMacros: [MacroItem] = []

    /// Filtered macros based on selected category
    private var filteredMacros: [MacroItem] {
        guard let categoryId = selectedCategoryId else {
            return macros  // Show all when "Tất cả" is selected
        }
        return macros.filter { $0.categoryId == categoryId }
    }

    /// Count macros for a category
    private func macroCount(for categoryId: UUID) -> Int {
        return macros.filter { $0.categoryId == categoryId }.count
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                SettingsHeaderView(
                    title: "Gõ tắt & Macro",
                    subtitle: "Tạo từ viết tắt, quản lý danh mục và tăng tốc độ nhập liệu.",
                    icon: "text.badge.plus",
                    accent: .green
                ) {
                    VStack(alignment: .trailing, spacing: 6) {
                        SettingsStatusPill(
                            text: appState.useMacro ? "Đang hoạt động" : "Đang tắt",
                            color: appState.useMacro ? .accentColor : .secondary
                        )
                        SettingsStatusPill(
                            text: "Tổng: \(macros.count)",
                            color: .compatTeal
                        )
                    }
                }

                // Macro Configuration
                SettingsCard(
                    title: "Thiết lập gõ tắt",
                    subtitle: "Bật/tắt và cấu hình hành vi mở rộng",
                    icon: "text.badge.plus"
                ) {
                    VStack(spacing: 0) {
                        SettingsToggleRow(
                            icon: "text.badge.plus",
                            iconColor: .accentColor,
                            title: "Bật gõ tắt",
                            subtitle: appState.useMacro ? "Cho phép mở rộng từ viết tắt" : "Tắt mở rộng từ viết tắt",
                            isOn: $appState.useMacro
                        )

                        SettingsDivider()

                        SettingsToggleRow(
                            icon: "globe",
                            iconColor: .accentColor,
                            title: "Gõ tắt trong chế độ tiếng Anh",
                            subtitle: "Cho phép mở rộng ngay cả khi đang ở chế độ Anh",
                            isOn: $appState.useMacroInEnglishMode
                        )
                        .disabled(!appState.useMacro)
                        .opacity(appState.useMacro ? 1 : 0.5)

                        SettingsDivider()

                        SettingsToggleRow(
                            icon: "textformat.abc",
                            iconColor: .accentColor,
                            title: "Tự động viết hoa",
                            subtitle: "Viết hoa ký tự đầu của nội dung mở rộng",
                            isOn: $appState.autoCapsMacro
                        )
                        .disabled(!appState.useMacro)
                        .opacity(appState.useMacro ? 1 : 0.5)
                    }
                }

                // Categories
                SettingsCard(
                    title: "Danh mục",
                    subtitle: "Nhóm gõ tắt theo chủ đề để dễ quản lý",
                    icon: "folder.fill"
                ) {
                    VStack(spacing: 0) {
                        // Category toolbar
                        HStack(spacing: 12) {
                            Button(action: { showingAddCategory = true }) {
                                Label("Thêm", systemImage: "plus.circle.fill")
                                    .font(.subheadline)
                            }
                            .adaptiveBorderedButtonStyle()

                            Button(action: { editCategory() }) {
                                Label("Sửa", systemImage: "pencil.circle.fill")
                                    .font(.subheadline)
                            }
                            .adaptiveBorderedButtonStyle()
                            .disabled(selectedCategoryId == nil || selectedCategoryId == MacroCategory.defaultCategory.id)

                            Button(action: { deleteCategory() }) {
                                Label("Xóa", systemImage: "minus.circle.fill")
                                    .font(.subheadline)
                            }
                            .adaptiveBorderedButtonStyle()
                            .disabled(selectedCategoryId == nil || selectedCategoryId == MacroCategory.defaultCategory.id)

                            Spacer()
                        }
                        .padding(.bottom, 12)

                        Divider()
                            .padding(.bottom, 8)

                        // Category list
                        VStack(spacing: 4) {
                            // "All" option - shows all macros
                            CategoryRowView(
                                name: "Tất cả",
                                icon: "tray.2.fill",
                                color: .accentColor,
                                count: macros.count,
                                isSelected: selectedCategoryId == nil,
                                isEditable: false
                            )
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    selectedCategoryId = nil
                                }
                            }

                            // User categories
                            ForEach(appState.macroCategories) { category in
                                CategoryRowView(
                                    name: category.name,
                                    icon: category.icon,
                                    color: category.swiftUIColor,
                                    count: macroCount(for: category.id),
                                    isSelected: selectedCategoryId == category.id,
                                    isEditable: true,
                                    onEdit: {
                                        editingCategory = category  // Setting this opens the sheet
                                    }
                                )
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        selectedCategoryId = category.id
                                    }
                                }
                            }
                        }
                    }
                }
                .disabled(!appState.useMacro)
                .opacity(appState.useMacro ? 1 : 0.5)

                // Macro List
                SettingsCard(
                    title: "Danh sách gõ tắt",
                    subtitle: "Quản lý và tìm nhanh theo danh mục",
                    icon: "list.bullet.rectangle"
                ) {
                    VStack(spacing: 0) {
                        // Toolbar
                        HStack(spacing: 12) {
                            Button(action: { showingAddMacro = true }) {
                                Label("Thêm", systemImage: "plus.circle.fill")
                                    .font(.subheadline)
                            }
                            .adaptiveBorderedButtonStyle()
                            .disabled(!appState.useMacro)

                            Button(action: { editMacro() }) {
                                Label("Sửa", systemImage: "pencil.circle.fill")
                                    .font(.subheadline)
                            }
                            .adaptiveBorderedButtonStyle()
                            .disabled(selectedMacro == nil || !appState.useMacro)

                            Button(action: { deleteMacro() }) {
                                Label("Xóa", systemImage: "minus.circle.fill")
                                    .font(.subheadline)
                            }
                            .adaptiveBorderedButtonStyle()
                            .disabled(selectedMacro == nil || !appState.useMacro)

                            Spacer()

                            Button(action: { exportMacros() }) {
                                Label("Xuất", systemImage: "square.and.arrow.up")
                                    .font(.subheadline)
                            }
                            .adaptiveBorderedButtonStyle()
                            .disabled(macros.isEmpty || !appState.useMacro)

                            Button(action: { importMacros() }) {
                                Label("Nhập", systemImage: "square.and.arrow.down")
                                    .font(.subheadline)
                            }
                            .adaptiveBorderedButtonStyle()
                            .disabled(!appState.useMacro)

                            Text("\(filteredMacros.count)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.accentColor)
                                )
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: filteredMacros.count)
                                .transition(.scale.combined(with: .opacity))
                        }
                        .padding(.bottom, 12)

                        Divider()
                            .padding(.bottom, 8)

                        // Content
                        if filteredMacros.isEmpty {
                            EmptyMacroView(
                                useMacro: appState.useMacro,
                                isFiltered: selectedCategoryId != nil,
                                onAdd: { showingAddMacro = true }
                            )
                        } else {
                            MacroListView(
                                macros: filteredMacros,
                                categories: allCategories,
                                selectedMacro: $selectedMacro,
                                recentlyAddedId: recentlyAddedId,
                                recentlyEditedId: recentlyEditedId,
                                onEdit: { macro in
                                    editingMacro = macro  // Setting this opens the sheet
                                }
                            )
                        }
                    }
                }

                Spacer(minLength: 20)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
        }
        .settingsBackground()
        .sheet(isPresented: $showingAddMacro) {
            MacroEditorView(
                isPresented: $showingAddMacro,
                categories: appState.macroCategories,
                defaultCategoryId: selectedCategoryId
            )
            .environmentObject(appState)
        }
        .sheet(item: $editingMacro) { macro in
            MacroEditorView(
                isPresented: Binding(
                    get: { editingMacro != nil },
                    set: { if !$0 { editingMacro = nil } }
                ),
                editingMacro: macro,
                categories: appState.macroCategories
            )
            .environmentObject(appState)
        }
        .sheet(isPresented: $showingAddCategory) {
            MacroCategoryEditorView(
                editingCategory: nil,
                existingCategories: appState.macroCategories,
                onSave: { category in
                    appState.macroCategories.append(category)
                    appState.saveSettings()
                }
            )
        }
        .sheet(item: $editingCategory) { category in
            MacroCategoryEditorView(
                editingCategory: category,
                existingCategories: appState.macroCategories,
                onSave: { updatedCategory in
                    if let index = appState.macroCategories.firstIndex(where: { $0.id == updatedCategory.id }) {
                        appState.macroCategories[index] = updatedCategory
                        appState.saveSettings()
                    }
                    editingCategory = nil  // Close sheet
                }
            )
        }
        .onAppear {
            loadMacros()
        }
        .onDisappear {
            macros = []
            selectedMacro = nil
            recentlyAddedId = nil
            recentlyEditedId = nil
            editingMacro = nil
            editingCategory = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MacrosUpdated")))
        { notification in
            // Note: .onReceive already runs on main thread in SwiftUI
            print("[MacroSettings] Received MacrosUpdated notification, reloading...")

            // Check if notification contains info about added/edited macro
            if let userInfo = notification.userInfo,
               let macroId = userInfo["macroId"] as? UUID,
               let action = userInfo["action"] as? String {

                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    loadMacros()

                    if action == "added" {
                        recentlyAddedId = macroId
                    } else if action == "edited" {
                        recentlyEditedId = macroId
                    }
                }

                // Clear highlight after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation {
                        if recentlyAddedId == macroId {
                            recentlyAddedId = nil
                        }
                        if recentlyEditedId == macroId {
                            recentlyEditedId = nil
                        }
                    }
                }
            } else {
                // Default animation for other updates
                withAnimation(.easeInOut(duration: 0.3)) {
                    loadMacros()
                }
            }

        }
    }

    /// All user-created categories
    private var allCategories: [MacroCategory] {
        appState.macroCategories
    }

    private func loadMacros() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: "macroList") {
            if let cached = Self.cachedMacrosData, cached == data {
                macros = Self.cachedMacros
                return
            }
            if let loadedMacros = try? JSONDecoder().decode([MacroItem].self, from: data) {
                macros = loadedMacros
                Self.cachedMacros = loadedMacros
                Self.cachedMacrosData = data
            } else {
                macros = []
                Self.cachedMacros = []
                Self.cachedMacrosData = data
            }
        } else {
            macros = []
            Self.cachedMacros = []
            Self.cachedMacrosData = nil
        }
    }

    private func deleteMacro() {
        guard let selectedId = selectedMacro,
            let index = macros.firstIndex(where: { $0.id == selectedId })
        else {
            return
        }

        let deletedMacro = macros[index]

        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            macros.remove(at: index)
            selectedMacro = nil
        }

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
        editingMacro = macro  // Setting this opens the sheet
    }

    private func editCategory() {
        guard let categoryId = selectedCategoryId,
              let category = appState.macroCategories.first(where: { $0.id == categoryId })
        else {
            return
        }
        editingCategory = category  // Setting this opens the sheet
    }

    private func deleteCategory() {
        guard let categoryId = selectedCategoryId,
              let index = appState.macroCategories.firstIndex(where: { $0.id == categoryId })
        else {
            return
        }

        // Move all macros in this category to uncategorized (nil)
        for i in macros.indices {
            if macros[i].categoryId == categoryId {
                macros[i].categoryId = nil
            }
        }
        saveMacros()

        // Remove category
        appState.macroCategories.remove(at: index)
        appState.saveSettings()

        selectedCategoryId = nil
    }

    private func exportMacros() {
        guard !macros.isEmpty else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.json]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "phtv-macros.json"
        panel.title = "Xuất danh sách gõ tắt"
        panel.message = "Chọn vị trí lưu file gõ tắt"

        if panel.runModal() == .OK, let url = panel.url {
            do {
                struct ExportMacro: Encodable {
                    let shortcut: String
                    let expansion: String
                    let categoryId: String?
                }

                struct ExportData: Encodable {
                    let categories: [MacroCategory]
                    let macros: [ExportMacro]
                }

                let exportMacros = macros.map {
                    ExportMacro(
                        shortcut: $0.shortcut,
                        expansion: $0.expansion,
                        categoryId: $0.categoryId?.uuidString
                    )
                }

                let exportData = ExportData(
                    categories: appState.macroCategories,
                    macros: exportMacros
                )

                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let jsonData = try encoder.encode(exportData)

                try jsonData.write(to: url)
                print("[MacroSettings] Exported \(macros.count) macros to: \(url.path)")
            } catch {
                print("[MacroSettings] Export failed: \(error.localizedDescription)")
            }
        }
    }

    private func importMacros() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.json, UTType.commaSeparatedText, UTType.plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "Chọn file gõ tắt (JSON/CSV)"

        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try Data(contentsOf: url)
                var imported: [MacroItem] = []
                var importedCategories: [MacroCategory] = []

                if url.pathExtension.lowercased() == "json" {
                    // Try new format first
                    struct ImportData: Decodable {
                        let categories: [MacroCategory]?
                        let macros: [ImportMacro]?

                        struct ImportMacro: Decodable {
                            let shortcut: String
                            let expansion: String
                            let categoryId: String?
                        }
                    }

                    if let importData = try? JSONDecoder().decode(ImportData.self, from: data),
                       let macroList = importData.macros {
                        // New format with categories
                        importedCategories = importData.categories ?? []
                        imported = macroList.map {
                            MacroItem(
                                shortcut: normalize($0.shortcut),
                                expansion: normalize($0.expansion),
                                categoryId: $0.categoryId.flatMap { UUID(uuidString: $0) }
                            )
                        }
                    } else {
                        // Old format: array of {shortcut, expansion}
                        struct RawMacro: Decodable { let shortcut: String; let expansion: String }
                        let raw = try JSONDecoder().decode([RawMacro].self, from: data)
                        imported = raw.map { MacroItem(shortcut: normalize($0.shortcut), expansion: normalize($0.expansion)) }
                    }
                } else {
                    // CSV/TXT: lines "shortcut,expansion"
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

                // Merge categories
                for cat in importedCategories {
                    if !appState.macroCategories.contains(where: { $0.id == cat.id }) {
                        appState.macroCategories.append(cat)
                    }
                }
                appState.saveSettings()

                // Merge macros
                var map: [String: MacroItem] = [:]
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
            Self.cachedMacros = macros
            Self.cachedMacrosData = encoded
            print("[MacroSettings] Saved \(macros.count) macros to UserDefaults")
            NotificationCenter.default.post(name: NSNotification.Name("MacrosUpdated"), object: nil)
        } else {
            print("[MacroSettings] ERROR: Failed to encode macros")
        }
    }
}

// MARK: - Category Row View

struct CategoryRowView: View {
    let name: String
    let icon: String
    let color: Color
    let count: Int
    let isSelected: Bool
    var isEditable: Bool = false
    var onEdit: (() -> Void)? = nil

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
                .frame(width: 24, height: 24)
                .background(
                    PHTVRoundedRect(cornerRadius: 5)
                        .fill(color.opacity(0.15))
                )

            Text(name)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()

            // Edit button - always present for editable categories
            if isEditable {
                Button {
                    onEdit?()
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(isHovering || isSelected ? Color.secondary : Color.clear)
                }
                .buttonStyle(.borderless)
                .help("Sửa danh mục")
            }

            Text("(\(count))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: count)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            PHTVRoundedRect(cornerRadius: 8)
                .fill(isSelected ? color.opacity(0.12) : Color.clear)
        )
        .overlay(
            PHTVRoundedRect(cornerRadius: 8)
                .stroke(isSelected ? color.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .animation(nil, value: isHovering)
    }
}

// MARK: - Subviews

struct EmptyMacroView: View {
    let useMacro: Bool
    var isFiltered: Bool = false
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 64, height: 64)

                Image(systemName: isFiltered ? "folder" : "text.badge.plus")
                    .font(.system(size: 28))
                    .foregroundStyle(.tint)
            }

            VStack(spacing: 6) {
                Text(isFiltered ? "Danh mục trống" : "Chưa có gõ tắt")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(isFiltered ? "Thêm gõ tắt vào danh mục này" : "Tạo gõ tắt để nhập liệu nhanh hơn")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: onAdd) {
                Label(isFiltered ? "Thêm gõ tắt" : "Tạo gõ tắt đầu tiên", systemImage: "plus.circle.fill")
            }
            .adaptiveProminentButtonStyle()
            .controlSize(.regular)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

struct MacroListView: View {
    let macros: [MacroItem]
    let categories: [MacroCategory]
    @Binding var selectedMacro: UUID?
    var recentlyAddedId: UUID? = nil
    var recentlyEditedId: UUID? = nil
    var onEdit: ((MacroItem) -> Void)? = nil

    var body: some View {
        LazyVStack(spacing: 4) {
            ForEach(macros) { macro in
                MacroRowView(
                    macro: macro,
                    category: categoryFor(macro),
                    isSelected: selectedMacro == macro.id,
                    isRecentlyAdded: macro.id == recentlyAddedId,
                    isRecentlyEdited: macro.id == recentlyEditedId,
                    onEdit: { onEdit?(macro) }
                )
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedMacro = macro.id
                    }
                }
            }
        }
    }

    private func categoryFor(_ macro: MacroItem) -> MacroCategory? {
        guard let categoryId = macro.categoryId else { return nil }
        return categories.first { $0.id == categoryId }
    }
}

struct MacroRowView: View {
    let macro: MacroItem
    var category: MacroCategory? = nil
    var isSelected: Bool = false
    var isRecentlyAdded: Bool = false
    var isRecentlyEdited: Bool = false
    var onEdit: (() -> Void)? = nil

    @State private var isHovering = false

    private var rowColor: Color {
        category?.swiftUIColor ?? .accentColor
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon with background - matching CategoryRowView style
            Image(systemName: category?.icon ?? "text.badge.plus")
                .font(.system(size: 14))
                .foregroundStyle(rowColor)
                .frame(width: 24, height: 24)
                .background(
                    PHTVRoundedRect(cornerRadius: 5)
                        .fill(rowColor.opacity(0.15))
                )
                .scaleEffect(isRecentlyAdded ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isRecentlyAdded)

            // Shortcut text
            Text(macro.shortcut)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)

            // Arrow
            Image(systemName: "arrow.right")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            // Expansion text
            Text(macro.expansion)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()

            // Edit button
            if isHovering || isSelected {
                Button {
                    onEdit?()
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.secondary)
                }
                .buttonStyle(.borderless)
                .help("Sửa gõ tắt")
            }

            // Category badge
            if let cat = category {
                Text(cat.name)
                    .font(.caption2)
                    .foregroundStyle(cat.swiftUIColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(cat.swiftUIColor.opacity(0.12))
                    )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            PHTVRoundedRect(cornerRadius: 8)
                .fill(backgroundColor)
        )
        .overlay(
            PHTVRoundedRect(cornerRadius: 8)
                .stroke(borderColor, lineWidth: borderWidth)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .animation(nil, value: isHovering)
    }

    private var backgroundColor: Color {
        if isRecentlyAdded {
            return .green.opacity(0.12)
        } else if isRecentlyEdited {
            return .blue.opacity(0.12)
        } else if isSelected {
            return rowColor.opacity(0.12)
        } else {
            return .clear
        }
    }

    private var borderColor: Color {
        if isRecentlyAdded {
            return .green.opacity(0.3)
        } else if isRecentlyEdited {
            return .blue.opacity(0.3)
        } else if isSelected {
            return rowColor.opacity(0.3)
        } else {
            return .clear
        }
    }

    private var borderWidth: CGFloat {
        (isRecentlyAdded || isRecentlyEdited || isSelected) ? 1 : 0
    }
}

#Preview {
    MacroSettingsView()
        .environmentObject(AppState.shared)
        .frame(width: 500, height: 800)
}
