//
//  EmojiPickerView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

struct EmojiPickerView: View {
    var onEmojiSelected: (String) -> Void
    var onClose: (() -> Void)?

    @AppStorage(Self.lastTabKey) private var storedSelectedCategory = -2
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private static let lastTabKey = "PHTVPickerLastTab"
    private static let validCategories: Set<Int> = [-2, -3, -4, -5]

    init(onEmojiSelected: @escaping (String) -> Void, onClose: (() -> Void)? = nil) {
        self.onEmojiSelected = onEmojiSelected
        self.onClose = onClose
    }

    private var selectedCategory: Int {
        get { Self.validCategories.contains(storedSelectedCategory) ? storedSelectedCategory : -2 }
        nonmutating set { storedSelectedCategory = newValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with close button and drag handle
            headerView
                .contentShape(Rectangle())
                .background(WindowDragHandle())


            Picker("Nội dung PHTV Picker", selection: Binding(
                get: { selectedCategory },
                set: { selectedCategory = $0 }
            )) {
                Text("Tất cả").tag(-2)
                Text("Emoji").tag(-3)
                Text("GIF").tag(-4)
                Text("Sticker").tag(-5)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.regular)
            .padding(.horizontal, 12)
            .padding(.bottom, 10)

            Divider()
                .opacity(0.5)

            // Content area - show different tabs based on selectedCategory
            if selectedCategory == -2 {
                // All Content tab with search (Emojis, GIFs, Stickers)
                UnifiedContentView(onEmojiSelected: onEmojiSelected, onClose: onClose)
                    .frame(height: 320)
            } else if selectedCategory == -3 {
                // Emoji tab - show all emoji categories
                EmojiCategoriesView(onEmojiSelected: onEmojiSelected)
                    .frame(height: 320)
            } else if selectedCategory == -4 {
                // GIF tab
                GIFOnlyView(onClose: onClose)
                    .frame(height: 320)
            } else if selectedCategory == -5 {
                // Sticker tab
                StickerOnlyView(onClose: onClose)
                    .frame(height: 320)
            }
        }
        .frame(width: 380)
        .environment(KlipyAPIClient.shared)
        .background {
            pickerBackground
        }
    }

    // MARK: - Header View

    @ViewBuilder
    private var headerView: some View {
        HStack(spacing: 8) {
            // Drag handle icon (left side)
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .help("Kéo để di chuyển")

            Text("PHTV Picker")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)

            Spacer()

            // Close button
            GlassCloseButton {
                onClose?()
            }
            .help("Đóng (ESC)")
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    // MARK: - Picker Background

    // MARK: - Picker Background

    @ViewBuilder
    private var pickerBackground: some View {
        if #available(macOS 26.0, *), !reduceTransparency {
            Color.clear
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
        } else if reduceTransparency {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(nsColor: .windowBackgroundColor))
        } else {
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
        }
    }
}
