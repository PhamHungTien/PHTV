//
//  EmojiCategoriesView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI
import AppKit
import Carbon

// MARK: - Emoji Categories View

struct EmojiCategoriesView: View {
    var onEmojiSelected: (String) -> Void

    private let database = EmojiDatabase.shared
    @State private var selectedSubCategory: Int
    @State private var searchText = ""
    @State private var searchResults: [EmojiItem] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var isSearchFocused = false
    @State private var keyboardFocus: EmojiPickerKeyboardFocus = .search

    private let iconColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 7)

    // Key for saving last selected emoji sub-category
    private static let lastSubCategoryKey = "PHTVPickerLastEmojiSubCategory"

    init(onEmojiSelected: @escaping (String) -> Void) {
        self.onEmojiSelected = onEmojiSelected
        // Load last selected sub-category, default to 0 if not set or invalid
        let savedSubCategory = UserDefaults.standard.integer(forKey: EmojiCategoriesView.lastSubCategoryKey)
        // Validate saved value is within valid range
        if savedSubCategory >= 0 && savedSubCategory < EmojiDatabase.shared.categories.count {
            _selectedSubCategory = State(initialValue: savedSubCategory)
        } else {
            _selectedSubCategory = State(initialValue: 0)
        }
    }

    // Display emojis - from search results or current category
    private var displayedEmojis: [EmojiItem] {
        if searchText.isEmpty {
            return database.categories[selectedSubCategory].emojis
        }
        return searchResults
    }

    private var displayedEmojiKeys: [String] {
        displayedEmojis.map(\.emoji)
    }

    private var focusedEmojiKey: String? {
        guard case .grid(let index) = keyboardFocus,
              displayedEmojis.indices.contains(index) else {
            return nil
        }
        return displayedEmojis[index].emoji
    }

    private var isGridActive: Bool {
        if case .grid = keyboardFocus {
            return true
        }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary.opacity(0.7))
                EmojiPickerSearchField(
                    placeholder: "Tìm emoji...",
                    text: $searchText,
                    isFocused: $isSearchFocused,
                    onMoveToGrid: moveFocusIntoEmojiGrid
                )
                .frame(maxWidth: .infinity)

                if !searchText.isEmpty {
                    Button(action: {
                        searchTask?.cancel()
                        searchTask = nil
                        searchText = ""
                        searchResults = []
                        returnFocusToSearch()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                PHTVRoundedRect(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .overlay(
                        PHTVRoundedRect(cornerRadius: 8)
                            .strokeBorder(Color.accentColor.opacity(isSearchFocused ? 0.3 : 0), lineWidth: 1.5)
                    )
            )
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Sub-category tabs (hidden when searching)
            if searchText.isEmpty {
                ScrollViewReader { scrollProxy in
                    ScrollView(.horizontal, showsIndicators: true) {
                        HStack(spacing: 8) {
                            ForEach(0..<database.categories.count, id: \.self) { index in
                                Button(action: {
                                    withAnimation {
                                        selectedSubCategory = index
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Text(database.categories[index].icon)
                                            .font(.system(size: 16))
                                        Text(database.categories[index].name)
                                            .font(.system(size: 11, weight: selectedSubCategory == index ? .semibold : .regular))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        selectedSubCategory == index ?
                                            Color.accentColor.opacity(0.15) : Color.clear
                                    )
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                                .id(index)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .onAppear {
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(100))
                            guard !Task.isCancelled else { return }
                            scrollProxy.scrollTo(selectedSubCategory, anchor: .center)
                        }
                    }
                }
            }

            Divider()

            ScrollViewReader { scrollProxy in
                ScrollView {
                    if displayedEmojis.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 32))
                                .foregroundColor(.secondary.opacity(0.5))
                            Text("Không tìm thấy emoji")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(40)
                    } else {
                        LazyVGrid(columns: iconColumns, spacing: 12) {
                            ForEach(Array(displayedEmojis.enumerated()), id: \.element.id) { index, emojiItem in
                                emojiButton(for: emojiItem, at: index)
                            }
                        }
                        .padding(16)
                    }
                }
                .background(
                    EmojiGridKeyboardHandler(
                        isActive: isGridActive,
                        onCommand: handleGridCommand,
                        onInsertTextIntoSearch: appendTextToSearch,
                        onDeleteFromSearch: deleteBackwardFromSearch
                    )
                )
                .onChange(of: focusedEmojiKey) { _, newValue in
                    guard let newValue else { return }
                    withAnimation(.easeInOut(duration: 0.15)) {
                        scrollProxy.scrollTo(newValue, anchor: .center)
                    }
                }
            }
        }
        .onAppear {
            keyboardFocus = .search
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(50))
                guard !Task.isCancelled else { return }
                isSearchFocused = true
            }
        }
        .onChange(of: searchText) { _, newValue in
            keyboardFocus = .search
            scheduleSearch(for: newValue)
        }
        .onChange(of: selectedSubCategory) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: EmojiCategoriesView.lastSubCategoryKey)
        }
        .onChange(of: displayedEmojiKeys) { _, _ in
            synchronizeGridFocusWithDisplayedEmojis()
        }
    }

    private func emojiButton(for emojiItem: EmojiItem, at index: Int) -> some View {
        let isKeyboardFocused = keyboardFocus == .grid(index: index)

        return Button(action: {
            keyboardFocus = .grid(index: index)
            selectEmoji(at: index)
        }) {
            Text(emojiItem.emoji)
                .font(.system(size: 30))
                .frame(maxWidth: .infinity, minHeight: 40, maxHeight: 40)
                .background(
                    PHTVRoundedRect(cornerRadius: 8)
                        .fill(isKeyboardFocused ? Color.accentColor.opacity(0.18) : Color.clear)
                )
                .overlay(
                    PHTVRoundedRect(cornerRadius: 8)
                        .strokeBorder(
                            isKeyboardFocused ? Color.accentColor.opacity(0.45) : Color.clear,
                            lineWidth: 1.2
                        )
                )
        }
        .buttonStyle(.plain)
        .help(emojiItem.name)
        .id(emojiItem.emoji)
    }

    private func scheduleSearch(for query: String) {
        searchTask?.cancel()
        searchTask = nil

        if query.isEmpty {
            searchResults = []
            return
        }

        searchTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            searchResults = database.search(query)
        }
    }

    private func moveFocusIntoEmojiGrid() -> Bool {
        refreshSearchResultsImmediatelyIfNeeded()

        guard !displayedEmojis.isEmpty else { return false }

        keyboardFocus = .grid(index: 0)
        isSearchFocused = false
        return true
    }

    private func returnFocusToSearch() {
        keyboardFocus = .search
        isSearchFocused = true
    }

    private func refreshSearchResultsImmediatelyIfNeeded() {
        guard !searchText.isEmpty else { return }

        // ArrowDown/Tab should work immediately after typing without waiting for debounce.
        searchTask?.cancel()
        searchTask = nil
        searchResults = database.search(searchText)
    }

    private func handleGridCommand(_ command: EmojiPickerKeyboardCommand) {
        let navigator = EmojiPickerKeyboardNavigator(
            itemCount: displayedEmojis.count,
            columnCount: iconColumns.count
        )

        applyKeyboardAction(navigator.action(for: command, from: keyboardFocus))
    }

    private func applyKeyboardAction(_ action: EmojiPickerKeyboardAction) {
        switch action {
        case .focus(let focus):
            keyboardFocus = focus
            isSearchFocused = (focus == .search)

        case .activate(let index):
            selectEmoji(at: index)

        case .noop:
            break
        }
    }

    private func selectEmoji(at index: Int) {
        guard displayedEmojis.indices.contains(index) else { return }
        onEmojiSelected(displayedEmojis[index].emoji)
    }

    private func appendTextToSearch(_ text: String) {
        guard !text.isEmpty else { return }
        searchText.append(text)
        returnFocusToSearch()
    }

    private func deleteBackwardFromSearch() {
        if !searchText.isEmpty {
            searchText.removeLast()
        }
        returnFocusToSearch()
    }

    private func synchronizeGridFocusWithDisplayedEmojis() {
        guard case .grid(let index) = keyboardFocus else { return }

        guard !displayedEmojis.isEmpty else {
            returnFocusToSearch()
            return
        }

        if index >= displayedEmojis.count {
            keyboardFocus = .grid(index: displayedEmojis.count - 1)
        }
    }
}

private struct EmojiPickerSearchField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    @Binding var isFocused: Bool
    let onMoveToGrid: () -> Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isFocused: $isFocused, onMoveToGrid: onMoveToGrid)
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
        context.coordinator.onMoveToGrid = onMoveToGrid

        if nsView.stringValue != text {
            nsView.stringValue = text
        }

        if isFocused {
            Task { @MainActor [weak nsView] in
                await Task.yield()
                guard let nsView,
                      let window = nsView.window,
                      window.firstResponder !== nsView.currentEditor() else { return }
                window.makeFirstResponder(nsView)
            }
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding var text: String
        @Binding var isFocused: Bool
        var onMoveToGrid: () -> Bool

        init(
            text: Binding<String>,
            isFocused: Binding<Bool>,
            onMoveToGrid: @escaping () -> Bool
        ) {
            self._text = text
            self._isFocused = isFocused
            self.onMoveToGrid = onMoveToGrid
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
                return onMoveToGrid()

            default:
                return false
            }
        }
    }
}

private struct EmojiGridKeyboardHandler: NSViewRepresentable {
    let isActive: Bool
    let onCommand: (EmojiPickerKeyboardCommand) -> Void
    let onInsertTextIntoSearch: (String) -> Void
    let onDeleteFromSearch: () -> Void

    func makeNSView(context: Context) -> EmojiGridKeyCaptureView {
        let view = EmojiGridKeyCaptureView()
        view.onCommand = onCommand
        view.onInsertTextIntoSearch = onInsertTextIntoSearch
        view.onDeleteFromSearch = onDeleteFromSearch
        return view
    }

    func updateNSView(_ nsView: EmojiGridKeyCaptureView, context: Context) {
        nsView.isActive = isActive
        nsView.onCommand = onCommand
        nsView.onInsertTextIntoSearch = onInsertTextIntoSearch
        nsView.onDeleteFromSearch = onDeleteFromSearch

        if isActive {
            Task { @MainActor [weak nsView] in
                await Task.yield()
                guard let nsView else { return }
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}

private final class EmojiGridKeyCaptureView: NSView {
    var isActive = false
    var onCommand: ((EmojiPickerKeyboardCommand) -> Void)?
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

        if Int(event.keyCode) == kVK_Escape {
            window?.performClose(nil)
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

        case kVK_LeftArrow:
            onCommand?(.moveLeft)
            return true

        case kVK_RightArrow:
            onCommand?(.moveRight)
            return true

        case kVK_UpArrow:
            onCommand?(.moveUp)
            return true

        case kVK_DownArrow:
            onCommand?(.moveDown)
            return true

        case kVK_Return, kVK_Space:
            onCommand?(.activateSelection)
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
