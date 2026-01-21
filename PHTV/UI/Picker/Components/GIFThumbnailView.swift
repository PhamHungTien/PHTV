//
//  GIFThumbnailView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI

struct GIFThumbnailView: View {
    let gif: KlipyGIF
    let onTap: () -> Void
    var contentType: String = "GIF"  // "GIF" or "Sticker"

    @State private var isHovered = false
    @State private var hasTrackedImpression = false

    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.05)

            // GIF content
            AnimatedGIFView(url: URL(string: gif.previewURL))
                .frame(width: 120, height: 120)
                .clipped()

            // Ad badge (nếu là ad)
            if gif.isAd {
                VStack {
                    HStack {
                        Spacer()
                        Text("Ad")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.8))
                            .cornerRadius(4)
                    }
                    Spacer()
                }
                .padding(8)
                .allowsHitTesting(false)
            }
        }
        .frame(width: 120, height: 120)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isHovered ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onTap()
        }
        .help(gif.isAd ? "Quảng cáo - Click để xem" : "Click để tải và gửi \(contentType)")
        .onAppear {
            if gif.isAd && !hasTrackedImpression {
                KlipyAPIClient.shared.trackImpression(for: gif)
                hasTrackedImpression = true
            }
        }
    }
}
