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

    func makeNSView(context: Context) -> NSImageView {
        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.animates = true // Enable GIF animation
        return imageView
    }

    func updateNSView(_ nsView: NSImageView, context: Context) {
        guard let url = url else { return }

        // Load GIF data asynchronously
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data, let image = NSImage(data: data) else { return }
            DispatchQueue.main.async {
                nsView.image = image
            }
        }.resume()
    }
}


