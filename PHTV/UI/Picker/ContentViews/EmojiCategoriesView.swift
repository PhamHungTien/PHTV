//
//  EmojiCategoriesView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

// MARK: - Emoji Categories View

struct EmojiCategoriesView: View {
    var onEmojiSelected: (String) -> Void

    private let database = EmojiDatabase.shared
    @State private var selectedSubCategory: Int
    @State private var searchText = ""
    @State private var searchResults: [EmojiItem] = []
    @State private var searchTask: DispatchWorkItem?
    @FocusState private var isSearchFocused: Bool
    @Namespace private var subCategoryNamespace

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

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary.opacity(0.7))
                TextField("Tìm emoji...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($isSearchFocused)
                    .onChange(of: searchText) { newValue in
                        // Cancel previous search
                        searchTask?.cancel()

                        if newValue.isEmpty {
                            searchResults = []
                        } else {
                            // Debounce search
                            let task = DispatchWorkItem {
                                searchResults = database.search(newValue)
                            }
                            searchTask = task
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: task)
                        }
                    }
                if !searchText.isEmpty {
                    Button(action: {
                        searchTask?.cancel()
                        searchText = ""
                        searchResults = []
                        isSearchFocused = true
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
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
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
                                .id(index)  // ID for scrolling
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .onAppear {
                        // Scroll to saved/selected sub-category when view appears
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            scrollProxy.scrollTo(selectedSubCategory, anchor: .center)
                        }
                    }
                }
            }

            Divider()

            // Emoji grid for selected category or search results
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
                        ForEach(displayedEmojis, id: \.id) { emojiItem in
                            Button(action: {
                                onEmojiSelected(emojiItem.emoji)
                            }) {
                                Text(emojiItem.emoji)
                                    .font(.system(size: 30))
                            }
                            .buttonStyle(.plain)
                            .frame(height: 40)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .onAppear {
            isSearchFocused = true
        }
        .onChange(of: selectedSubCategory) { newValue in
            // Save selected sub-category to UserDefaults
            UserDefaults.standard.set(newValue, forKey: EmojiCategoriesView.lastSubCategoryKey)
        }
    }
}


