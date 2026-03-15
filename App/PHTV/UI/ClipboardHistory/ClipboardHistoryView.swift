//
//  ClipboardHistoryView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI
import AppKit
import Carbon

private enum ClipboardHistoryKeyboardFocus: Equatable {
    case search
    case list
}

private enum ClipboardHistorySearchCommand {
    case moveForward
    case moveBackward
    case activateSelection
}

private enum ClipboardHistoryListCommand {
    case moveUp
    case moveDown
    case moveNext
    case movePrevious
    case activateSelection
    case close
}

struct ClipboardHistoryView: View {
    let onItemSelected: (ClipboardHistoryItem) -> Void
    let onClose: () -> Void

    @ObservedObject private var manager = ClipboardHistoryManager.shared
    @State private var hoveredItemId: UUID?
    @State private var selectedItemId: UUID?
    @State private var searchText = ""
    @State private var keyboardFocus: ClipboardHistoryKeyboardFocus = .search
    @State private var isSearchFieldFocused = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

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

    private var selectedIndex: Int? {
        filteredItems.firstIndex { $0.id == selectedItemId }
    }

    private var selectedItem: ClipboardHistoryItem? {
        guard let selectedItemId else { return nil }
        return filteredItems.first { $0.id == selectedItemId }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
                .contentShape(Rectangle())
                .background(WindowDragHandle())

            searchBar

            Divider()
                .opacity(0.5)

            if filteredItems.isEmpty {
                emptyState
            } else {
                itemList
            }

            Divider()
                .opacity(0.5)
            HStack {
                Text("\(manager.items.count) mục")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("Mũi tên / Tab để chọn • Enter để dán")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(width: 380, height: 480)
        .background {
            clipboardBackground
        }
        .onAppear {
            syncSelectionWithFilteredItems()
            DispatchQueue.main.async {
                keyboardFocus = .search
                isSearchFieldFocused = true
            }
        }
        .onChange(of: filteredItems.map(\.id)) { _ in
            syncSelectionWithFilteredItems()
        }
        .onChange(of: isSearchFieldFocused) { isFocused in
            if isFocused {
                keyboardFocus = .search
            }
        }
    }

    // MARK: - Header View

    @ViewBuilder
    private var headerView: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary.opacity(0.6))
                .frame(width: 24, height: 24)
                .background {
                    Circle()
                        .fill(Color.primary.opacity(colorScheme == .dark ? 0.1 : 0.08))
                }
                .help("Kéo để di chuyển")

            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.accentColor)

            Text("Lịch sử Clipboard")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)

            Spacer()

            if !manager.items.isEmpty {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        manager.clearAll()
                        syncSelectionWithFilteredItems()
                        keyboardFocus = .search
                        isSearchFieldFocused = true
                    }
                }) {
                    Text("Xoá tất cả")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background {
                            PHTVRoundedRect(cornerRadius: 6)
                                .fill(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.05))
                        }
                }
                .buttonStyle(.plain)
            }

            GlassCloseButton {
                onClose()
            }
            .help("Đóng (ESC)")
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    // MARK: - Search Bar

    @ViewBuilder
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 12))

            ClipboardHistorySearchField(
                placeholder: "Tìm kiếm...",
                text: $searchText,
                isFocused: $isSearchFieldFocused,
                onCommand: handleSearchCommand
            )
            .frame(height: 20)
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
        .contentShape(Rectangle())
        .onTapGesture {
            focusSearch()
        }
    }

    // MARK: - Items List

    @ViewBuilder
    private var itemList: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredItems) { item in
                        ClipboardItemRow(
                            item: item,
                            isHovered: hoveredItemId == item.id,
                            isSelected: selectedItemId == item.id,
                            colorScheme: colorScheme,
                            onSelect: { select(item) },
                            onDelete: { delete(item) }
                        )
                        .onHover { isHovered in
                            hoveredItemId = isHovered ? item.id : nil
                        }

                        if item.id != filteredItems.last?.id {
                            Divider()
                                .opacity(0.4)
                                .padding(.leading, 54)
                        }
                    }
                }
                .padding(.vertical, 4)
                .background(
                    ClipboardHistoryListKeyboardHandler(
                        isActive: keyboardFocus == .list && !filteredItems.isEmpty,
                        onCommand: handleListCommand,
                        onInsertTextIntoSearch: insertTextIntoSearch,
                        onDeleteFromSearch: deleteLastSearchCharacter
                    )
                    .frame(width: 0, height: 0)
                )
            }
            .onChange(of: selectedItemId) { newValue in
                guard let newValue else { return }
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.12)) {
                        scrollProxy.scrollTo(newValue, anchor: .center)
                    }
                }
            }
        }
    }

    // MARK: - Background

    @ViewBuilder
    private var clipboardBackground: some View {
        if #available(macOS 26.0, *), !reduceTransparency {
            PHTVRoundedRect(cornerRadius: 16)
                .fill(Color(NSColor.windowBackgroundColor).opacity(colorScheme == .dark ? 0.2 : 0.25))
                .glassEffect(
                    .regular,
                    in: .rect(corners: .fixed(16), isUniform: true)
                )
                .overlay(
                    PHTVRoundedRect(cornerRadius: 16)
                        .stroke(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.06), lineWidth: 1)
                )
        } else {
            ZStack {
                PHTVRoundedRect(cornerRadius: 16)
                    .fill(Color(NSColor.windowBackgroundColor).opacity(0.85))
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
            }
            .clipShape(PHTVRoundedRect(cornerRadius: 16))
        }
    }

    // MARK: - Empty State

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

    // MARK: - Selection Logic

    private func syncSelectionWithFilteredItems() {
        guard !filteredItems.isEmpty else {
            selectedItemId = nil
            keyboardFocus = .search
            return
        }

        if let selectedItemId,
           filteredItems.contains(where: { $0.id == selectedItemId }) {
            return
        }

        selectedItemId = filteredItems.first?.id
    }

    private func focusSearch() {
        keyboardFocus = .search
        isSearchFieldFocused = true
    }

    private func focusList(at index: Int) -> Bool {
        guard !filteredItems.isEmpty else {
            return false
        }

        let clampedIndex = min(max(index, 0), filteredItems.count - 1)
        selectedItemId = filteredItems[clampedIndex].id
        keyboardFocus = .list
        isSearchFieldFocused = false
        return true
    }

    private func activateSelectedItem() -> Bool {
        guard let selectedItem else { return false }
        onItemSelected(selectedItem)
        return true
    }

    private func moveSelection(by delta: Int) {
        guard !filteredItems.isEmpty else { return }

        let currentIndex = selectedIndex ?? 0
        let nextIndex = min(max(currentIndex + delta, 0), filteredItems.count - 1)
        selectedItemId = filteredItems[nextIndex].id
    }

    private func handleSearchCommand(_ command: ClipboardHistorySearchCommand) -> Bool {
        switch command {
        case .moveForward:
            return focusList(at: selectedIndex ?? 0)

        case .moveBackward:
            guard !filteredItems.isEmpty else { return false }
            return focusList(at: filteredItems.count - 1)

        case .activateSelection:
            return activateSelectedItem()
        }
    }

    private func handleListCommand(_ command: ClipboardHistoryListCommand) {
        switch command {
        case .moveUp:
            if let selectedIndex, selectedIndex == 0 {
                focusSearch()
            } else {
                moveSelection(by: -1)
            }

        case .moveDown:
            moveSelection(by: 1)

        case .moveNext:
            moveSelection(by: 1)

        case .movePrevious:
            if let selectedIndex, selectedIndex == 0 {
                focusSearch()
            } else {
                moveSelection(by: -1)
            }

        case .activateSelection:
            _ = activateSelectedItem()

        case .close:
            onClose()
        }
    }

    private func insertTextIntoSearch(_ text: String) {
        guard !text.isEmpty else { return }
        searchText.append(text)
        focusSearch()
    }

    private func deleteLastSearchCharacter() {
        guard !searchText.isEmpty else { return }
        searchText.removeLast()
        focusSearch()
    }

    private func select(_ item: ClipboardHistoryItem) {
        selectedItemId = item.id
        keyboardFocus = .list
        onItemSelected(item)
    }

    private func delete(_ item: ClipboardHistoryItem) {
        let currentSelectionId = selectedItemId
        let deletedSelectedItem = currentSelectionId == item.id
        let nextSelectionIndex = selectedIndex
        manager.removeItem(item)

        guard !filteredItems.isEmpty else {
            selectedItemId = nil
            focusSearch()
            return
        }

        if !deletedSelectedItem,
           let currentSelectionId,
           filteredItems.contains(where: { $0.id == currentSelectionId }) {
            selectedItemId = currentSelectionId
            return
        }

        let fallbackIndex = min(nextSelectionIndex ?? 0, filteredItems.count - 1)
        _ = focusList(at: fallbackIndex)
    }
}

// MARK: - Clipboard Item Row

private struct ClipboardItemRow: View {
    let item: ClipboardHistoryItem
    let isHovered: Bool
    let isSelected: Bool
    let colorScheme: ColorScheme
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                contentIcon
                    .frame(width: 32, height: 32)

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
            .background {
                if isSelected {
                    PHTVRoundedRect(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(colorScheme == .dark ? 0.18 : 0.12))
                } else if isHovered {
                    PHTVRoundedRect(cornerRadius: 8)
                        .fill(Color.primary.opacity(colorScheme == .dark ? 0.1 : 0.06))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .id(item.id)
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
                    .clipShape(PHTVRoundedRect(cornerRadius: 6))
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
            .background(color.opacity(colorScheme == .dark ? 0.15 : 0.1))
            .clipShape(PHTVRoundedRect(cornerRadius: 6))
    }

    private var timeAgoText: String {
        let interval = Date().timeIntervalSince(item.timestamp)
        if interval < 60 { return "Vừa xong" }
        if interval < 3600 { return "\(Int(interval / 60)) phút trước" }
        if interval < 86400 { return "\(Int(interval / 3600)) giờ trước" }
        return "\(Int(interval / 86400)) ngày trước"
    }
}

// MARK: - Search Field

private struct ClipboardHistorySearchField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    @Binding var isFocused: Bool
    let onCommand: (ClipboardHistorySearchCommand) -> Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isFocused: $isFocused, onCommand: onCommand)
    }

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField(string: text)
        textField.delegate = context.coordinator
        textField.placeholderString = placeholder
        textField.isBezeled = false
        textField.isBordered = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.font = .systemFont(ofSize: 13)
        textField.lineBreakMode = .byClipping
        textField.maximumNumberOfLines = 1
        textField.usesSingleLineMode = true
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        context.coordinator.onCommand = onCommand

        if nsView.stringValue != text {
            nsView.stringValue = text
        }

        if isFocused {
            DispatchQueue.main.async {
                guard let window = nsView.window,
                      window.firstResponder !== nsView.currentEditor() else { return }
                window.makeFirstResponder(nsView)
            }
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding var text: String
        @Binding var isFocused: Bool
        var onCommand: (ClipboardHistorySearchCommand) -> Bool

        init(
            text: Binding<String>,
            isFocused: Binding<Bool>,
            onCommand: @escaping (ClipboardHistorySearchCommand) -> Bool
        ) {
            self._text = text
            self._isFocused = isFocused
            self.onCommand = onCommand
        }

        func controlTextDidBeginEditing(_ notification: Notification) {
            isFocused = true
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else { return }
            text = textField.stringValue
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            isFocused = false
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.moveDown(_:)),
                 #selector(NSResponder.insertTab(_:)):
                return onCommand(.moveForward)

            case #selector(NSResponder.moveUp(_:)),
                 #selector(NSResponder.insertBacktab(_:)):
                return onCommand(.moveBackward)

            case #selector(NSResponder.insertNewline(_:)),
                 #selector(NSResponder.insertLineBreak(_:)):
                return onCommand(.activateSelection)

            default:
                return false
            }
        }
    }
}

// MARK: - List Keyboard Handler

private struct ClipboardHistoryListKeyboardHandler: NSViewRepresentable {
    let isActive: Bool
    let onCommand: (ClipboardHistoryListCommand) -> Void
    let onInsertTextIntoSearch: (String) -> Void
    let onDeleteFromSearch: () -> Void

    func makeNSView(context: Context) -> ClipboardHistoryListKeyCaptureView {
        let view = ClipboardHistoryListKeyCaptureView()
        view.onCommand = onCommand
        view.onInsertTextIntoSearch = onInsertTextIntoSearch
        view.onDeleteFromSearch = onDeleteFromSearch
        return view
    }

    func updateNSView(_ nsView: ClipboardHistoryListKeyCaptureView, context: Context) {
        nsView.isActive = isActive
        nsView.onCommand = onCommand
        nsView.onInsertTextIntoSearch = onInsertTextIntoSearch
        nsView.onDeleteFromSearch = onDeleteFromSearch

        if isActive {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}

private final class ClipboardHistoryListKeyCaptureView: NSView {
    var isActive = false
    var onCommand: ((ClipboardHistoryListCommand) -> Void)?
    var onInsertTextIntoSearch: ((String) -> Void)?
    var onDeleteFromSearch: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard isActive else {
            super.keyDown(with: event)
            return
        }

        if handleNavigation(event) || handleSearchEditing(event) {
            return
        }

        super.keyDown(with: event)
    }

    private func handleNavigation(_ event: NSEvent) -> Bool {
        let normalizedFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        switch Int(event.keyCode) {
        case kVK_Tab:
            onCommand?(normalizedFlags.contains(.shift) ? .movePrevious : .moveNext)
            return true

        case kVK_UpArrow:
            onCommand?(.moveUp)
            return true

        case kVK_DownArrow:
            onCommand?(.moveDown)
            return true

        case kVK_Return, kVK_ANSI_KeypadEnter, kVK_Space:
            onCommand?(.activateSelection)
            return true

        case kVK_Escape:
            onCommand?(.close)
            return true

        default:
            return false
        }
    }

    private func handleSearchEditing(_ event: NSEvent) -> Bool {
        let normalizedFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if normalizedFlags.contains(.command) ||
            normalizedFlags.contains(.control) ||
            normalizedFlags.contains(.option) {
            return false
        }

        if Int(event.keyCode) == kVK_Delete || Int(event.keyCode) == kVK_ForwardDelete {
            onDeleteFromSearch?()
            return true
        }

        guard let characters = event.characters, !characters.isEmpty else {
            return false
        }

        let printableScalars = characters.unicodeScalars.filter {
            !CharacterSet.controlCharacters.contains($0)
        }
        guard !printableScalars.isEmpty else {
            return false
        }

        onInsertTextIntoSearch?(String(String.UnicodeScalarView(printableScalars)))
        return true
    }
}
