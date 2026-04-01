//
//  AnimatedGIFView.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI
import AppKit

// MARK: - Animated GIF View

/// SwiftUI wrapper for NSImageView to display animated GIFs
struct AnimatedGIFView: NSViewRepresentable {
    let url: URL?

    final class Coordinator {
        var loadTask: Task<Void, Never>?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSImageView {
        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.animates = true // Enable GIF animation
        return imageView
    }

    func updateNSView(_ nsView: NSImageView, context: Context) {
        context.coordinator.loadTask?.cancel()
        nsView.image = nil

        guard let url else { return }

        context.coordinator.loadTask = Task {
            guard let data = await downloadRemoteData(
                from: url,
                logPrefix: "[AnimatedGIF]",
                itemDescription: "GIF"
            ) else {
                return
            }

            guard let image = NSImage(data: data) else {
                NSLog("[AnimatedGIF] Failed to create NSImage from data")
                return
            }

            await MainActor.run {
                guard !Task.isCancelled else { return }
                nsView.image = image
            }
        }
    }

    static func dismantleNSView(_ nsView: NSImageView, coordinator: Coordinator) {
        coordinator.loadTask?.cancel()
        nsView.image = nil
    }
}
