//
//  MacroCategoryEditorView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

struct MacroCategoryEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let editingCategory: MacroCategory?
    let existingCategories: [MacroCategory]
    let onSave: (MacroCategory) -> Void

    @State private var name: String
    @State private var selectedIcon: String
    @State private var selectedColor: String
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    var isEditMode: Bool { editingCategory != nil }

    init(
        editingCategory: MacroCategory?,
        existingCategories: [MacroCategory],
        onSave: @escaping (MacroCategory) -> Void
    ) {
        self.editingCategory = editingCategory
        self.existingCategories = existingCategories
        self.onSave = onSave

        // Initialize state with editing category values or defaults
        _name = State(initialValue: editingCategory?.name ?? "")
        _selectedIcon = State(initialValue: editingCategory?.icon ?? "folder.fill")
        _selectedColor = State(initialValue: editingCategory?.color ?? "#007AFF")
    }

    private let availableIcons = [
        "folder.fill", "tray.fill", "archivebox.fill",
        "doc.fill", "book.fill", "bookmark.fill",
        "tag.fill", "star.fill", "heart.fill",
        "briefcase.fill", "building.2.fill", "house.fill",
        "person.fill", "person.2.fill", "envelope.fill",
        "phone.fill", "bubble.left.fill", "ellipsis.bubble.fill",
        "cart.fill", "creditcard.fill", "banknote.fill",
        "gift.fill", "airplane", "car.fill",
        "leaf.fill", "flame.fill", "bolt.fill",
        "wrench.fill", "hammer.fill", "paintbrush.fill",
        "music.note", "gamecontroller.fill", "tv.fill",
        "desktopcomputer", "keyboard.fill", "terminal.fill"
    ]

    // Darker colors for better white text contrast
    private let availableColors = [
        "#0066CC", "#5856D6", "#7B3FA0", "#D63384",
        "#CC3333", "#E65C00", "#B8860B", "#2E8B57",
        "#008080", "#0097A7", "#007ACC", "#6B6B70"
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header - consistent with MacroEditorView
            HStack {
                Text(isEditMode ? "Chỉnh sửa danh mục" : "Thêm danh mục mới")
                    .font(.headline)
                Spacer()
                Button("Đóng") {
                    dismiss()
                }
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Name field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tên danh mục")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)

                        TextField("VD: Công việc, Email...", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Icon picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Icon")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8), spacing: 8) {
                            ForEach(availableIcons, id: \.self) { icon in
                                Button {
                                    selectedIcon = icon
                                } label: {
                                    Image(systemName: icon)
                                        .font(.system(size: 16))
                                        .frame(width: 36, height: 36)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(selectedIcon == icon ? (Color(hex: selectedColor) ?? .blue) : Color(NSColor.controlBackgroundColor))
                                        )
                                        .foregroundStyle(selectedIcon == icon ? .white : .primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Color picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Màu sắc")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                            ForEach(availableColors, id: \.self) { colorHex in
                                Button {
                                    selectedColor = colorHex
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: colorHex) ?? .blue)
                                            .frame(width: 32, height: 32)

                                        if selectedColor == colorHex {
                                            Circle()
                                                .strokeBorder(.white, lineWidth: 2)
                                                .frame(width: 32, height: 32)

                                            Image(systemName: "checkmark")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Preview
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Xem trước")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 12) {
                            Image(systemName: selectedIcon)
                                .font(.system(size: 16))
                                .foregroundStyle(Color(hex: selectedColor) ?? .blue)
                                .frame(width: 28, height: 28)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill((Color(hex: selectedColor) ?? .blue).opacity(0.15))
                                )

                            Text(name.isEmpty ? "Tên danh mục" : name)
                                .foregroundStyle(name.isEmpty ? .secondary : .primary)

                            Spacer()

                            Text("(0)")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(NSColor.controlBackgroundColor))
                        )
                    }

                    if showError {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(errorMessage)
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.red.opacity(0.1))
                        )
                    }
                }
                .padding()
            }

            Divider()

            // Footer buttons - consistent with MacroEditorView
            HStack {
                Spacer()
                Button("Hủy", role: .cancel) {
                    dismiss()
                }
                Button("Lưu") {
                    saveCategory()
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .frame(width: 400, height: 520)
    }

    private func saveCategory() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            showError = true
            errorMessage = "Vui lòng nhập tên danh mục"
            return
        }

        // Check duplicate name (case-insensitive), exclude current editing category
        let isDuplicate = existingCategories.contains { category in
            if let editing = editingCategory, category.id == editing.id {
                return false
            }
            return category.name.lowercased() == trimmedName.lowercased()
        }

        if isDuplicate {
            showError = true
            errorMessage = "Danh mục '\(trimmedName)' đã tồn tại"
            return
        }

        let category: MacroCategory
        if let editing = editingCategory {
            category = MacroCategory(
                id: editing.id,
                name: trimmedName,
                icon: selectedIcon,
                color: selectedColor
            )
        } else {
            category = MacroCategory(
                name: trimmedName,
                icon: selectedIcon,
                color: selectedColor
            )
        }

        onSave(category)
        dismiss()
    }
}

#Preview {
    MacroCategoryEditorView(
        editingCategory: nil,
        existingCategories: [],
        onSave: { _ in }
    )
}
