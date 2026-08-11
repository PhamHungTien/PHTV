//
//  ClipboardSavedModels.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation

enum ClipboardPanelSection: String, CaseIterable, Identifiable {
    case history
    case saved

    var id: String { rawValue }

    var title: String {
        switch self {
        case .history: return "Lịch sử"
        case .saved: return "Mục đã lưu"
        }
    }
}

struct ClipboardSavedGroup: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    let createdAt: Date

    init(id: UUID = UUID(), name: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}

struct ClipboardSavedItem: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var content: String
    var groupID: UUID?
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        content: String,
        groupID: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.groupID = groupID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum ClipboardSavedLibraryError: LocalizedError, Equatable {
    case emptyGroupName
    case groupNameTooLong
    case duplicateGroupName
    case emptyTitle
    case titleTooLong
    case emptyContent
    case contentTooLong
    case missingGroup
    case missingItem

    var errorDescription: String? {
        switch self {
        case .emptyGroupName: return "Hãy nhập tên nhóm."
        case .groupNameTooLong: return "Tên nhóm không được dài quá 40 ký tự."
        case .duplicateGroupName: return "Đã có một nhóm cùng tên."
        case .emptyTitle: return "Hãy nhập tên cho mục đã lưu."
        case .titleTooLong: return "Tên mục không được dài quá 80 ký tự."
        case .emptyContent: return "Hãy nhập nội dung cần lưu."
        case .contentTooLong: return "Nội dung không được dài quá 50.000 ký tự."
        case .missingGroup: return "Nhóm đã chọn không còn tồn tại."
        case .missingItem: return "Mục đã lưu không còn tồn tại."
        }
    }
}

/// A user-managed library, deliberately separate from automatically captured
/// clipboard history. History retention and "clear all" never affect this data.
struct ClipboardSavedLibrary: Codable, Equatable {
    static let currentVersion = 1
    static let maximumGroupNameLength = 40
    static let maximumTitleLength = 80
    static let maximumContentLength = 50_000

    var version: Int
    private(set) var groups: [ClipboardSavedGroup]
    private(set) var items: [ClipboardSavedItem]

    init(
        version: Int = Self.currentVersion,
        groups: [ClipboardSavedGroup] = [],
        items: [ClipboardSavedItem] = []
    ) {
        self.version = version
        self.groups = groups
        self.items = items
    }

    @discardableResult
    mutating func addGroup(named rawName: String, now: Date = Date()) throws -> ClipboardSavedGroup {
        let name = try validatedGroupName(rawName)
        let group = ClipboardSavedGroup(name: name, createdAt: now)
        groups.append(group)
        return group
    }

    mutating func renameGroup(id: UUID, to rawName: String) throws {
        guard let index = groups.firstIndex(where: { $0.id == id }) else {
            throw ClipboardSavedLibraryError.missingGroup
        }
        groups[index].name = try validatedGroupName(rawName, excluding: id)
    }

    /// Deleting a folder never deletes its contents. Items are moved to the
    /// ungrouped section so an accidental folder deletion remains recoverable.
    mutating func removeGroup(id: UUID) throws {
        guard groups.contains(where: { $0.id == id }) else {
            throw ClipboardSavedLibraryError.missingGroup
        }
        groups.removeAll { $0.id == id }
        for index in items.indices where items[index].groupID == id {
            items[index].groupID = nil
            items[index].updatedAt = Date()
        }
    }

    @discardableResult
    mutating func saveItem(
        id: UUID? = nil,
        title rawTitle: String,
        content rawContent: String,
        groupID: UUID?,
        now: Date = Date()
    ) throws -> ClipboardSavedItem {
        let title = try Self.validatedTitle(rawTitle)
        let content = try Self.validatedContent(rawContent)
        if let groupID, !groups.contains(where: { $0.id == groupID }) {
            throw ClipboardSavedLibraryError.missingGroup
        }

        if let id {
            guard let index = items.firstIndex(where: { $0.id == id }) else {
                throw ClipboardSavedLibraryError.missingItem
            }
            items[index].title = title
            items[index].content = content
            items[index].groupID = groupID
            items[index].updatedAt = now
            return items[index]
        }

        let item = ClipboardSavedItem(
            title: title,
            content: content,
            groupID: groupID,
            createdAt: now,
            updatedAt: now
        )
        items.insert(item, at: 0)
        return item
    }

    mutating func removeItem(id: UUID) throws {
        guard items.contains(where: { $0.id == id }) else {
            throw ClipboardSavedLibraryError.missingItem
        }
        items.removeAll { $0.id == id }
    }

    func groupName(for groupID: UUID?) -> String {
        guard let groupID else { return "Chưa phân loại" }
        return groups.first(where: { $0.id == groupID })?.name ?? "Chưa phân loại"
    }

    func matchingItems(searchText: String, groupID: UUID? = nil, includesAllGroups: Bool = true) -> [ClipboardSavedItem] {
        let scopedItems = includesAllGroups ? items : items.filter { $0.groupID == groupID }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return scopedItems }

        return scopedItems.filter { item in
            item.title.localizedCaseInsensitiveContains(query)
                || item.content.localizedCaseInsensitiveContains(query)
                || groupName(for: item.groupID).localizedCaseInsensitiveContains(query)
        }
    }

    private func validatedGroupName(_ rawName: String, excluding excludedID: UUID? = nil) throws -> String {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw ClipboardSavedLibraryError.emptyGroupName }
        guard name.count <= Self.maximumGroupNameLength else {
            throw ClipboardSavedLibraryError.groupNameTooLong
        }
        guard !groups.contains(where: {
            $0.id != excludedID && $0.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) else {
            throw ClipboardSavedLibraryError.duplicateGroupName
        }
        return name
    }

    private static func validatedTitle(_ rawTitle: String) throws -> String {
        let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { throw ClipboardSavedLibraryError.emptyTitle }
        guard title.count <= maximumTitleLength else { throw ClipboardSavedLibraryError.titleTooLong }
        return title
    }

    private static func validatedContent(_ rawContent: String) throws -> String {
        let content = rawContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { throw ClipboardSavedLibraryError.emptyContent }
        guard content.count <= maximumContentLength else { throw ClipboardSavedLibraryError.contentTooLong }
        return content
    }
}
