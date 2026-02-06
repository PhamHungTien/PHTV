//
//  FloatingPanel.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI
import AppKit

class FloatingPanel<Content: View>: NSPanel, NSWindowDelegate {

    init(view: Content, contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .closable, .borderless],
            backing: .buffered,
            defer: false
        )

        // Panel behavior
        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Visual styling
        self.isMovableByWindowBackground = true  // Enable window dragging
        self.backgroundColor = .clear

        // Performance
        self.isOpaque = false
        self.hasShadow = false  // Shadow handled by SwiftUI layer

        // Disable resizing completely
        self.minSize = contentRect.size
        self.maxSize = contentRect.size

        // Set content view
        self.contentView = NSHostingView(rootView: view)

        // Set delegate to handle close button
        self.delegate = self

        // Center on screen
        self.center()
    }

    // Handle close button click
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        NSLog("[FloatingPanel] windowShouldClose called")
        return true
    }

    // Override performClose to handle close button for nonactivating panels
    override func performClose(_ sender: Any?) {
        NSLog("[FloatingPanel] performClose called - closing panel")
        self.close()
    }

    /// Shows the panel at current mouse position
    func showAtMousePosition() {
        let mouseLocation = NSEvent.mouseLocation
        let screenFrame = NSScreen.main?.frame ?? .zero

        // Position panel near mouse, but ensure it stays on screen
        var origin = mouseLocation
        origin.x = min(max(origin.x, screenFrame.minX), screenFrame.maxX - self.frame.width)
        origin.y = min(max(origin.y - self.frame.height, screenFrame.minY), screenFrame.maxY - self.frame.height)

        self.setFrameOrigin(origin)
        self.orderFrontRegardless()
    }

    /// Key event handling - close on Escape
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: // Escape key
            close()
        default:
            super.keyDown(with: event)
        }
    }

    // Override canBecomeKey to allow keyboard input
    override var canBecomeKey: Bool {
        return true
    }
}


