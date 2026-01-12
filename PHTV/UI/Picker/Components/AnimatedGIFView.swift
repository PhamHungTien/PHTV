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
        URLSession.shared.dataTask(with: url) { data, response, error in
            // Check for network errors
            if let error = error {
                NSLog("[AnimatedGIF] Failed to load GIF: %@", error.localizedDescription)
                return
            }

            // Check HTTP status code
            if let httpResponse = response as? HTTPURLResponse {
                guard 200...299 ~= httpResponse.statusCode else {
                    NSLog("[AnimatedGIF] HTTP error loading GIF: %d", httpResponse.statusCode)
                    return
                }
            }

            // Ensure we have data and can create image
            guard let data = data else {
                NSLog("[AnimatedGIF] No data received for GIF")
                return
            }

            guard let image = NSImage(data: data) else {
                NSLog("[AnimatedGIF] Failed to create NSImage from data")
                return
            }

            DispatchQueue.main.async {
                nsView.image = image
            }
        }.resume()
    }
}


