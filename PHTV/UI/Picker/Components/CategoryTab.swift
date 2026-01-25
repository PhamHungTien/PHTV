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

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                iconView
                Text(label)
                    .font(.system(size: 9, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
            }
            .foregroundColor(isSelected ? .accentColor : .secondary)
            .padding(.horizontal, 8)
            .frame(minWidth: 60)
            .frame(height: 40)
            .background {
                tabBackground
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .scaleEffect(isHovering && !isSelected ? 1.02 : 1.0)
        .animation(.phtvMorph, value: isHovering)
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

    @ViewBuilder
    private var iconView: some View {
        if #available(macOS 14.0, *) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                .symbolEffect(.bounce, value: isSelected)
        } else {
            Image(systemName: icon)
                .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
        }
    }

    @ViewBuilder
    private var tabBackground: some View {
        if isSelected {
            if #available(macOS 26.0, *), !reduceTransparency {
                // Liquid Glass for selected tab with morphing
                PHTVRoundedRect(cornerRadius: 8)
                    .fill(.ultraThinMaterial)
                    .glassEffect(
                        .regular.interactive().tint(.accentColor),
                        in: .rect(corners: .fixed(8), isUniform: true)
                    )
                    .glassEffectID("categoryTab", in: namespace)
                    .overlay(
                        PHTVRoundedRect(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(colorScheme == .dark ? 0.18 : 0.12))
                    )
            } else {
                // Fallback with matchedGeometryEffect
                PHTVRoundedRect(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.15))
                    .matchedGeometryEffect(id: "categoryBackground", in: namespace)
            }
        } else if isHovering {
            // Simple fill for hover - no glassEffect to avoid re-creation
            PHTVRoundedRect(cornerRadius: 8)
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.05))
        }
    }
}
