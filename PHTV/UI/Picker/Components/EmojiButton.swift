//
//  EmojiButton.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

// MARK: - Emoji Button Component

struct EmojiButton: View {
    let emoji: EmojiItem
    let size: CGFloat
    let isHovered: Bool
    let frequencyCount: Int?
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            isPressed = true
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
            }
        }) {
            ZStack(alignment: .topTrailing) {
                Text(emoji.emoji)
                    .font(.system(size: size * 0.65))
                    .frame(width: size, height: size)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isHovered ? Color.accentColor.opacity(0.12) : Color(NSColor.controlBackgroundColor).opacity(0.3))
                    )
                    .scaleEffect(isHovered ? 1.15 : (isPressed ? 0.95 : 1.0))
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
                    .animation(.spring(response: 0.2, dampingFraction: 0.5), value: isPressed)

                // Frequency badge
                if let count = frequencyCount, count > 3 {
                    Text("\(count)")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.accentColor)
                        )
                        .offset(x: 4, y: -4)
                }
            }
        }
        .buttonStyle(.plain)
        .help(emoji.name)
    }
}

