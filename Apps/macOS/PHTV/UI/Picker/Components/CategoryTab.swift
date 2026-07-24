//
//  CategoryTab.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI
import AppKit

// MARK: - Category Tab Components

struct CategoryTab: View {
    let isSelected: Bool
    let icon: String
    let label: String
    let namespace: Namespace.ID
    let action: () -> Void
    @State private var isHovering = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Computed Properties

    private var iconColor: Color {
        if isSelected {
            return .accentColor
        } else if isHovering {
            return .primary
        } else {
            return .secondary
        }
    }

    private var labelColor: Color {
        if isSelected {
            return .accentColor
        } else if isHovering {
            return .primary.opacity(0.8)
        } else {
            return .secondary
        }
    }

    // MARK: - Body

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                iconView
                Text(label)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
                    .foregroundColor(labelColor)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(minWidth: 64)
            .frame(height: 44)
            .background {
                tabBackground
            }
            .scaleEffect(isHovering && !isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .onDisappear {
            if isHovering {
                NSCursor.pop()
                isHovering = false
            }
        }
    }

    // MARK: - Icon View

    @ViewBuilder
    private var iconView: some View {
        Image(systemName: icon)
            .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
            .foregroundColor(iconColor)
            .symbolRenderingMode(.hierarchical)
    }

    // MARK: - Tab Background

    @ViewBuilder
    private var tabBackground: some View {
        if isSelected {
            // Simple colored fill with matchedGeometryEffect for smooth animation
            PHTVRoundedRect(cornerRadius: 10)
                .fill(Color.accentColor.opacity(colorScheme == .dark ? 0.2 : 0.15))
                .overlay(
                    PHTVRoundedRect(cornerRadius: 10)
                        .stroke(Color.accentColor.opacity(colorScheme == .dark ? 0.35 : 0.25), lineWidth: 1.5)
                )
                .matchedGeometryEffect(id: "categoryBackground", in: namespace)
        } else if isHovering {
            // Subtle hover feedback
            PHTVRoundedRect(cornerRadius: 10)
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08))
                .overlay(
                    PHTVRoundedRect(cornerRadius: 10)
                        .stroke(Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.1), lineWidth: 1)
                )
        }
    }
}
