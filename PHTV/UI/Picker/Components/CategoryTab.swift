//
//  CategoryTab.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

// MARK: - Category Tab Components

struct CategoryTab: View {
    let isSelected: Bool
    let icon: String
    let label: String
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                Text(label)
                    .font(.system(size: 9, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
            }
            .foregroundColor(isSelected ? .accentColor : .secondary)
            .padding(.horizontal, 8)
            .frame(minWidth: 60)
            .frame(height: 40)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.15))
                            .matchedGeometryEffect(id: "categoryBackground", in: namespace)
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }
}

