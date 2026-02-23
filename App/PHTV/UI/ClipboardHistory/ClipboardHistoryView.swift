//
//  ClipboardHistoryView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

struct ClipboardHistoryView: View {
    let onItemSelected: (ClipboardHistoryItem) -> Void
    let onClose: () -> Void

    @ObservedObject private var manager = ClipboardHistoryManager.shared
    @State private var hoveredItemId: UUID?
    @State private var searchText = ""

    private var filteredItems: [ClipboardHistoryItem] {
        if searchText.isEmpty { return manager.items }
        return manager.items.filter { item in
            if let text = item.textContent {
                return text.localizedCaseInsensitiveContains(searchText)
            }
            if let paths = item.filePaths {
                return paths.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
            return false
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.accentColor)

                Text("Lịch sử Clipboard")
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                if !manager.items.isEmpty {
                    Button(action: {
                        manager.clearAll()
                    }) {
                        Text("Xoá tất cả")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Search
            if manager.items.count > 5 {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 12))
                    TextField("Tìm kiếm...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(8)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }

            Divider()

            // Items list
            if filteredItems.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredItems) { item in
                            ClipboardItemRow(
                                item: item,
                                isHovered: hoveredItemId == item.id,
                                onSelect: { onItemSelected(item) },
                                onDelete: { manager.removeItem(item) }
                            )
                            .onHover { isHovered in
                                hoveredItemId = isHovered ? item.id : nil
                            }

                            if item.id != filteredItems.last?.id {
                                Divider()
                                    .padding(.leading, 12)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            // Footer
            Divider()
            HStack {
                Text("\(manager.items.count) mục")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("Click để dán")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(width: 380, height: 480)
        .background {
            if #available(macOS 26.0, *) {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text(searchText.isEmpty ? "Chưa có nội dung nào" : "Không tìm thấy")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
            Text(searchText.isEmpty ? "Nội dung bạn sao chép sẽ xuất hiện ở đây" : "Thử từ khoá khác")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Clipboard Item Row

private struct ClipboardItemRow: View {
    let item: ClipboardHistoryItem
    let isHovered: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                // Content type icon
                contentIcon
                    .frame(width: 32, height: 32)

                // Content preview
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayText)
                        .font(.system(size: 13))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(timeAgoText)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                // Delete button (only on hover)
                if isHovered {
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .imageScale(.small)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isHovered ? Color.primary.opacity(0.06) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var contentIcon: some View {
        switch item.contentType {
        case .image:
            if let image = item.previewImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                iconView("photo.fill", color: .blue)
            }
        case .file:
            iconView("doc.fill", color: .orange)
        case .mixed:
            iconView("doc.richtext.fill", color: .purple)
        case .text:
            iconView("text.alignleft", color: .accentColor)
        }
    }

    private func iconView(_ systemName: String, color: Color) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 14))
            .foregroundStyle(color)
            .frame(width: 32, height: 32)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var timeAgoText: String {
        let interval = Date().timeIntervalSince(item.timestamp)
        if interval < 60 { return "Vừa xong" }
        if interval < 3600 { return "\(Int(interval / 60)) phút trước" }
        if interval < 86400 { return "\(Int(interval / 3600)) giờ trước" }
        return "\(Int(interval / 86400)) ngày trước"
    }
}

// MARK: - Visual Effect View

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
