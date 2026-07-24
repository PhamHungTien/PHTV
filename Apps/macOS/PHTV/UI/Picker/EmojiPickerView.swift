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
    @Namespace private var categoryNamespace
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

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


            // Category tabs with GlassEffectContainer for efficient morphing (Apple guideline)
            ScrollViewReader { scrollProxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    categoryTabsContent()
                        .padding(.horizontal, 12)
                }
                .padding(.bottom, 8)
                .task(id: selectedCategory) {
                    try? await Task.sleep(for: .milliseconds(100))
                    guard !Task.isCancelled else { return }
                    scrollProxy.scrollTo(selectedCategory, anchor: .center)
                }
            }

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
                .foregroundColor(.secondary.opacity(0.6))
                .frame(width: 24, height: 24)
                .background {
                    Circle()
                        .fill(Color.primary.opacity(colorScheme == .dark ? 0.1 : 0.08))
                }
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

    // MARK: - Category Tabs with GlassEffectContainer

    @ViewBuilder
    private func categoryTabsContent() -> some View {
        HStack(spacing: 6) {
            categoryTabItems()
        }
    }

    @ViewBuilder
    private func categoryTabItems() -> some View {
        // All Content tab
        CategoryTab(
            isSelected: selectedCategory == -2,
            icon: "sparkles",
            label: "Tất cả",
            namespace: categoryNamespace
        ) {
            withAnimation(.phtvMorph) {
                selectedCategory = -2
            }
        }
        .id(-2)

        // Emoji tab
        CategoryTab(
            isSelected: selectedCategory == -3,
            icon: "face.smiling.fill",
            label: "Emoji",
            namespace: categoryNamespace
        ) {
            withAnimation(.phtvMorph) {
                selectedCategory = -3
            }
        }
        .id(-3)

        // GIF tab
        CategoryTab(
            isSelected: selectedCategory == -4,
            icon: "photo.on.rectangle.angled",
            label: "GIF",
            namespace: categoryNamespace
        ) {
            withAnimation(.phtvMorph) {
                selectedCategory = -4
            }
        }
        .id(-4)

        // Sticker tab
        CategoryTab(
            isSelected: selectedCategory == -5,
            icon: "sparkle",
            label: "Sticker",
            namespace: categoryNamespace
        ) {
            withAnimation(.phtvMorph) {
                selectedCategory = -5
            }
        }
        .id(-5)
    }

    // MARK: - Picker Background

    @ViewBuilder
    private var pickerBackground: some View {
        if #available(macOS 26.0, *), !reduceTransparency {
            // Enhanced Liquid Glass design for macOS 26+
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
            // Fallback glassmorphism for older macOS
            ZStack {
                PHTVRoundedRect(cornerRadius: 16)
                    .fill(Color(NSColor.windowBackgroundColor).opacity(0.85))
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
            }
            .clipShape(PHTVRoundedRect(cornerRadius: 16))
        }
    }
}
