//
//  ClipboardSavedItemsView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

private enum ClipboardSavedGroupFilter: Hashable {
    case all
    case ungrouped
    case group(UUID)
}

private struct ClipboardSavedItemDraft {
    let id: UUID?
    var title: String
    var content: String
    var groupID: UUID?

    init(item: ClipboardSavedItem? = nil, initialContent: String = "", groupID: UUID? = nil) {
        id = item?.id
        title = item?.title ?? Self.suggestedTitle(from: initialContent)
        content = item?.content ?? initialContent
        self.groupID = item?.groupID ?? groupID
    }

    private static func suggestedTitle(from content: String) -> String {
        let firstLine = content
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return String(firstLine.prefix(60))
    }
}

private struct ClipboardSavedGroupDraft {
    let id: UUID?
    var name: String
}

private enum ClipboardSavedDeletion {
    case item(ClipboardSavedItem)
    case group(ClipboardSavedGroup)
}

struct ClipboardSavedItemsView: View {
    let initialContent: String
    let onInitialContentConsumed: () -> Void
    let onItemSelected: (ClipboardSavedItem) -> Void
    let onEditingChanged: (Bool) -> Void

    var manager = ClipboardHistoryManager.shared
    @State private var searchText = ""
    @State private var groupFilter: ClipboardSavedGroupFilter = .all
    @State private var hoveredItemID: UUID?
    @State private var itemDraft: ClipboardSavedItemDraft?
    @State private var groupDraft: ClipboardSavedGroupDraft?
    @State private var pendingDeletion: ClipboardSavedDeletion?
    @State private var errorMessage: String?
    @Environment(\.colorScheme) private var colorScheme

    private var filteredItems: [ClipboardSavedItem] {
        switch groupFilter {
        case .all:
            return manager.savedLibrary.matchingItems(searchText: searchText)
        case .ungrouped:
            return manager.savedLibrary.matchingItems(
                searchText: searchText,
                groupID: nil,
                includesAllGroups: false
            )
        case .group(let id):
            return manager.savedLibrary.matchingItems(
                searchText: searchText,
                groupID: id,
                includesAllGroups: false
            )
        }
    }

    var body: some View {
        Group {
            if let itemDraft {
                ClipboardSavedItemEditor(
                    draft: itemDraft,
                    groups: manager.savedLibrary.groups,
                    errorMessage: errorMessage,
                    onCancel: closeEditor,
                    onSave: saveItem
                )
            } else if let groupDraft {
                ClipboardSavedGroupEditor(
                    draft: groupDraft,
                    errorMessage: errorMessage,
                    onCancel: closeEditor,
                    onSave: saveGroup
                )
            } else if let pendingDeletion {
                ClipboardSavedDeleteConfirmation(
                    deletion: pendingDeletion,
                    onCancel: { self.pendingDeletion = nil },
                    onConfirm: performDeletion
                )
            } else {
                libraryView
            }
        }
        .task(id: initialContent) {
            guard !initialContent.isEmpty else { return }
            itemDraft = ClipboardSavedItemDraft(
                initialContent: initialContent,
                groupID: selectedGroupID
            )
            onInitialContentConsumed()
        }
        .onChange(of: manager.savedLibrary.groups.map(\.id)) { _, groupIDs in
            if case .group(let id) = groupFilter, !groupIDs.contains(id) {
                groupFilter = .all
            }
        }
        .onChange(of: isPresentingEditor) { _, isEditing in
            onEditingChanged(isEditing)
        }
        .onDisappear {
            onEditingChanged(false)
        }
    }

    private var isPresentingEditor: Bool {
        itemDraft != nil || groupDraft != nil || pendingDeletion != nil
    }

    private var selectedGroupID: UUID? {
        if case .group(let id) = groupFilter { return id }
        return nil
    }

    @ViewBuilder
    private var libraryView: some View {
        VStack(spacing: 0) {
            controls
            searchBar

            Divider()
                .opacity(0.5)

            if filteredItems.isEmpty {
                emptyState
            } else {
                savedItemList
            }
        }
    }

    @ViewBuilder
    private var controls: some View {
        HStack(spacing: 8) {
            Picker("Nhóm", selection: $groupFilter) {
                Label("Tất cả mục", systemImage: "tray.full").tag(ClipboardSavedGroupFilter.all)
                Divider()
                ForEach(manager.savedLibrary.groups) { group in
                    Label(group.name, systemImage: "folder").tag(ClipboardSavedGroupFilter.group(group.id))
                }
                Label("Chưa phân loại", systemImage: "tray").tag(ClipboardSavedGroupFilter.ungrouped)
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)

            if let selectedGroup {
                Menu {
                    Button("Đổi tên nhóm", systemImage: "pencil") {
                        groupDraft = ClipboardSavedGroupDraft(id: selectedGroup.id, name: selectedGroup.name)
                    }
                    Button("Xoá nhóm", systemImage: "trash", role: .destructive) {
                        pendingDeletion = .group(selectedGroup)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 14))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Tuỳ chọn nhóm")
            }

            Menu {
                Button("Mục mới", systemImage: "bookmark.fill") {
                    itemDraft = ClipboardSavedItemDraft(groupID: selectedGroupID)
                }
                Button("Nhóm mới", systemImage: "folder.badge.plus") {
                    groupDraft = ClipboardSavedGroupDraft(id: nil, name: "")
                }
            } label: {
                Label("Thêm", systemImage: "plus")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Thêm mục hoặc nhóm")
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var selectedGroup: ClipboardSavedGroup? {
        guard case .group(let id) = groupFilter else { return nil }
        return manager.savedLibrary.groups.first { $0.id == id }
    }

    @ViewBuilder
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 12))

            TextField("Tìm tên, nội dung hoặc nhóm...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Xoá tìm kiếm")
            }
        }
        .padding(8)
        .background {
            PHTVRoundedRect(cornerRadius: 8)
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.05))
                .overlay(
                    PHTVRoundedRect(cornerRadius: 8)
                        .stroke(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.06), lineWidth: 1)
                )
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var savedItemList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if groupFilter == .all {
                    ForEach(populatedGroups, id: \.id) { group in
                        savedSectionHeader(group.name, systemImage: "folder.fill")
                        savedRows(for: group.items)
                    }
                } else {
                    savedRows(for: filteredItems)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private struct PopulatedGroup: Identifiable {
        let id: String
        let name: String
        let items: [ClipboardSavedItem]
    }

    private var populatedGroups: [PopulatedGroup] {
        var sections = manager.savedLibrary.groups.compactMap { group -> PopulatedGroup? in
            let items = filteredItems.filter { $0.groupID == group.id }
            guard !items.isEmpty else { return nil }
            return PopulatedGroup(id: group.id.uuidString, name: group.name, items: items)
        }
        let ungroupedItems = filteredItems.filter { $0.groupID == nil }
        if !ungroupedItems.isEmpty {
            sections.append(PopulatedGroup(id: "ungrouped", name: "Chưa phân loại", items: ungroupedItems))
        }
        return sections
    }

    @ViewBuilder
    private func savedRows(for items: [ClipboardSavedItem]) -> some View {
        ForEach(items) { item in
            ClipboardSavedItemRow(
                item: item,
                groupName: manager.savedLibrary.groupName(for: item.groupID),
                isHovered: hoveredItemID == item.id,
                colorScheme: colorScheme,
                onSelect: { onItemSelected(item) },
                onEdit: { itemDraft = ClipboardSavedItemDraft(item: item) },
                onDelete: { pendingDeletion = .item(item) }
            )
            .onHover { isHovered in
                hoveredItemID = isHovered ? item.id : nil
            }

            if item.id != items.last?.id {
                Divider()
                    .opacity(0.4)
                    .padding(.leading, 54)
            }
        }
    }

    @ViewBuilder
    private func savedSectionHeader(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 9, weight: .semibold))
            Text(title)
                .font(.system(size: 10, weight: .semibold))
            Spacer()
        }
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 3)
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: searchText.isEmpty ? "bookmark" : "magnifyingglass")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(.secondary.opacity(0.45))

            Text(searchText.isEmpty ? "Chưa có mục đã lưu" : "Không tìm thấy")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(searchText.isEmpty
                 ? "Lưu nội dung thường dùng để dán nhanh khi cần."
                 : "Thử từ khoá hoặc nhóm khác.")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            if searchText.isEmpty {
                Button("Tạo mục đầu tiên", systemImage: "plus") {
                    itemDraft = ClipboardSavedItemDraft(groupID: selectedGroupID)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 44)
        .padding(.horizontal, 24)
    }

    private func closeEditor() {
        itemDraft = nil
        groupDraft = nil
        errorMessage = nil
    }

    private func saveItem(_ draft: ClipboardSavedItemDraft) {
        do {
            try manager.saveSavedItem(
                id: draft.id,
                title: draft.title,
                content: draft.content,
                groupID: draft.groupID
            )
            closeEditor()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveGroup(_ draft: ClipboardSavedGroupDraft) {
        do {
            if let id = draft.id {
                try manager.renameSavedGroup(id: id, to: draft.name)
            } else {
                let group = try manager.addSavedGroup(named: draft.name)
                groupFilter = .group(group.id)
            }
            closeEditor()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func performDeletion() {
        guard let pendingDeletion else { return }
        do {
            switch pendingDeletion {
            case .item(let item):
                try manager.removeSavedItem(id: item.id)
            case .group(let group):
                try manager.removeSavedGroup(id: group.id)
                groupFilter = .all
            }
            self.pendingDeletion = nil
        } catch {
            errorMessage = error.localizedDescription
            self.pendingDeletion = nil
        }
    }
}

private struct ClipboardSavedItemRow: View {
    let item: ClipboardSavedItem
    let groupName: String
    let isHovered: Bool
    let colorScheme: ColorScheme
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 32, height: 32)
                    .background(Color.accentColor.opacity(colorScheme == .dark ? 0.15 : 0.1))
                    .clipShape(PHTVRoundedRect(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(item.content.replacingOccurrences(of: "\n", with: " "))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text(groupName)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                if isHovered {
                    HStack(spacing: 7) {
                        Button(action: onEdit) {
                            Image(systemName: "pencil")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Sửa")

                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Xoá")
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                if isHovered {
                    PHTVRoundedRect(cornerRadius: 8)
                        .fill(Color.primary.opacity(colorScheme == .dark ? 0.1 : 0.06))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Dán", systemImage: "doc.on.clipboard") { onSelect() }
            Button("Sửa", systemImage: "pencil") { onEdit() }
            Divider()
            Button("Xoá", systemImage: "trash", role: .destructive) { onDelete() }
        }
        .help("Bấm để dán \(item.title)")
    }
}

private struct ClipboardSavedItemEditor: View {
    @State var draft: ClipboardSavedItemDraft
    let groups: [ClipboardSavedGroup]
    let errorMessage: String?
    let onCancel: () -> Void
    let onSave: (ClipboardSavedItemDraft) -> Void
    @FocusState private var focusedField: Field?

    private enum Field { case title, content }

    var body: some View {
        VStack(spacing: 0) {
            editorHeader(title: draft.id == nil ? "Mục mới" : "Sửa mục")

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Tên")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Ví dụ: Địa chỉ công ty", text: $draft.title)
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedField, equals: .title)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Nhóm")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("", selection: $draft.groupID) {
                            Text("Chưa phân loại").tag(nil as UUID?)
                            ForEach(groups) { group in
                                Text(group.name).tag(Optional(group.id))
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Nội dung")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $draft.content)
                            .font(.system(size: 13))
                            .scrollContentBackground(.hidden)
                            .padding(6)
                            .frame(minHeight: 112)
                            .background(Color.primary.opacity(0.05))
                            .clipShape(PHTVRoundedRect(cornerRadius: 7))
                            .overlay {
                                PHTVRoundedRect(cornerRadius: 7)
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                            }
                            .focused($focusedField, equals: .content)
                    }

                    Label(
                        "Mục đã lưu nằm trên máy và không được mã hoá. Không lưu mật khẩu, mã OTP hoặc khoá bí mật.",
                        systemImage: "lock.open.trianglebadge.exclamationmark"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(9)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(PHTVRoundedRect(cornerRadius: 8))

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding(14)
            }
        }
        .task {
            await Task.yield()
            focusedField = draft.title.isEmpty ? .title : .content
        }
    }

    private func editorHeader(title: String) -> some View {
        HStack {
            Button("Huỷ", action: onCancel)
                .keyboardShortcut(.cancelAction)

            Spacer()

            Text(title)
                .font(.system(size: 13, weight: .semibold))

            Spacer()

            Button("Lưu") { onSave(draft) }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("s", modifiers: .command)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.035))
        .overlay(alignment: .bottom) { Divider().opacity(0.5) }
    }
}

private struct ClipboardSavedGroupEditor: View {
    @State var draft: ClipboardSavedGroupDraft
    let errorMessage: String?
    let onCancel: () -> Void
    let onSave: (ClipboardSavedGroupDraft) -> Void
    @FocusState private var isNameFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Huỷ", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Text(draft.id == nil ? "Nhóm mới" : "Đổi tên nhóm")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button("Lưu") { onSave(draft) }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.035))
            .overlay(alignment: .bottom) { Divider().opacity(0.5) }

            VStack(alignment: .leading, spacing: 8) {
                Text("Tên nhóm")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Ví dụ: Công việc", text: $draft.name)
                    .textFieldStyle(.roundedBorder)
                    .focused($isNameFocused)
                    .onSubmit { onSave(draft) }

                Text("Dùng nhóm để sắp xếp nội dung thường dùng. Một mục vẫn có thể để ở Chưa phân loại.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)

            Spacer()
        }
        .task {
            await Task.yield()
            isNameFocused = true
        }
    }
}

private struct ClipboardSavedDeleteConfirmation: View {
    let deletion: ClipboardSavedDeletion
    let onCancel: () -> Void
    let onConfirm: () -> Void

    private var title: String {
        switch deletion {
        case .item: return "Xoá mục đã lưu?"
        case .group: return "Xoá nhóm?"
        }
    }

    private var message: String {
        switch deletion {
        case .item(let item):
            return "“\(item.title)” sẽ bị xoá vĩnh viễn."
        case .group(let group):
            return "Nhóm “\(group.name)” sẽ bị xoá. Các mục trong nhóm sẽ được chuyển về Chưa phân loại."
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            Spacer()

            Image(systemName: "trash.circle.fill")
                .font(.system(size: 38))
                .foregroundStyle(.red)

            Text(title)
                .font(.title3.weight(.semibold))

            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button("Huỷ", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Xoá", role: .destructive, action: onConfirm)
                    .keyboardShortcut(.defaultAction)
            }

            Spacer()
        }
        .padding(28)
    }
}
