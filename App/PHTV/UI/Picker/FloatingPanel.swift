//
//  FloatingPanel.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import SwiftUI
import AppKit

/// Filters duplicate deliveries of one physical hotkey press before they can
/// start overlapping panel transitions.
struct FloatingPanelHotkeyGate {
    let minimumInterval: TimeInterval
    private var lastAcceptedUptime: TimeInterval?

    init(minimumInterval: TimeInterval = 0.20) {
        self.minimumInterval = minimumInterval
    }

    mutating func shouldAccept(at uptime: TimeInterval) -> Bool {
        if let lastAcceptedUptime,
           uptime >= lastAcceptedUptime,
           uptime - lastAcceptedUptime < minimumInterval {
            return false
        }

        // If the monotonic clock ever resets, accept the request and establish
        // a new baseline instead of leaving the hotkey permanently blocked.
        lastAcceptedUptime = uptime
        return true
    }
}

/// Ensures PHTV never has two independent floating pickers fighting for key
/// status. Replacing one picker with another suppresses the old focus-restore
/// callback so it cannot immediately dismiss the new panel.
@MainActor
private final class FloatingPanelExclusivityCoordinator {
    static let shared = FloatingPanelExclusivityCoordinator()

    private var activeOwner: ObjectIdentifier?
    private var dismissActivePanel: (@MainActor () -> Void)?

    func claim(owner: AnyObject, dismiss: @escaping @MainActor () -> Void) {
        let ownerID = ObjectIdentifier(owner)
        if activeOwner != ownerID {
            let previousDismissal = dismissActivePanel
            activeOwner = nil
            dismissActivePanel = nil
            previousDismissal?()
        }

        activeOwner = ownerID
        dismissActivePanel = dismiss
    }

    func release(owner: AnyObject) {
        guard activeOwner == ObjectIdentifier(owner) else { return }
        activeOwner = nil
        dismissActivePanel = nil
    }
}

/// Owns the complete AppKit lifecycle for one floating SwiftUI panel. Keeping
/// panel identity and notification tasks together prevents an old panel from
/// closing or focusing a newer one after a rapid hotkey transition.
@MainActor
final class FloatingPanelSession<Content: View> {
    private(set) var panel: FloatingPanel<Content>?

    private var activationTask: Task<Void, Never>?
    private var resignKeyObserver: NSObjectProtocol?
    private var closeObserver: NSObjectProtocol?
    private var onDismiss: (@MainActor () -> Void)?

    var isVisible: Bool {
        panel?.isVisible == true
    }

    @discardableResult
    func focusIfVisible() -> Bool {
        guard let panel, panel.isVisible else { return false }
        panel.orderFrontRegardless()
        panel.makeKey()
        return true
    }

    func present(
        _ newPanel: FloatingPanel<Content>,
        onDismiss: @escaping @MainActor () -> Void
    ) {
        discardStalePanel()
        FloatingPanelExclusivityCoordinator.shared.claim(owner: self) { [weak self] in
            self?.dismissForReplacement()
        }

        panel = newPanel
        self.onDismiss = onDismiss

        newPanel.standardWindowButton(.closeButton)?.isHidden = true
        newPanel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        newPanel.standardWindowButton(.zoomButton)?.isHidden = true

        observeLifecycle(of: newPanel)
        newPanel.showAtMousePosition()
        newPanel.makeKey()

        activationTask = Task { @MainActor [weak self, weak newPanel] in
            await Task.yield()
            guard let self,
                  let newPanel,
                  !Task.isCancelled,
                  self.panel === newPanel,
                  newPanel.isVisible else { return }
            newPanel.makeKey()
        }
    }

    func dismiss() {
        guard let panel else { return }
        finishDismissal(of: panel, closeIfVisible: true)
    }

    private func observeLifecycle(of observedPanel: FloatingPanel<Content>) {
        // Block observers are registered synchronously, before the panel is
        // shown. The MainActor hop keeps all AppKit ownership transitions
        // serialized even if a future macOS version posts from another queue.
        resignKeyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: observedPanel,
            queue: .main
        ) { [weak self, weak observedPanel] _ in
            Task { @MainActor in
                guard let self, let observedPanel else { return }
                self.finishDismissal(of: observedPanel, closeIfVisible: true)
            }
        }

        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: observedPanel,
            queue: .main
        ) { [weak self, weak observedPanel] _ in
            Task { @MainActor in
                guard let self, let observedPanel else { return }
                self.finishDismissal(of: observedPanel, closeIfVisible: false)
            }
        }
    }

    private func finishDismissal(
        of expectedPanel: FloatingPanel<Content>,
        closeIfVisible: Bool,
        notifyDismissal: Bool = true
    ) {
        guard panel === expectedPanel else { return }

        let shouldClose = closeIfVisible && expectedPanel.isVisible
        let dismissalHandler = notifyDismissal ? onDismiss : nil
        detachTasks()
        panel = nil
        onDismiss = nil
        FloatingPanelExclusivityCoordinator.shared.release(owner: self)

        if shouldClose {
            expectedPanel.close()
        }
        dismissalHandler?()
    }

    private func dismissForReplacement() {
        guard let panel else { return }
        finishDismissal(
            of: panel,
            closeIfVisible: true,
            notifyDismissal: false
        )
    }

    private func discardStalePanel() {
        guard let stalePanel = panel else {
            detachTasks()
            onDismiss = nil
            return
        }

        detachTasks()
        panel = nil
        onDismiss = nil
        if stalePanel.isVisible {
            stalePanel.close()
        }
    }

    private func detachTasks() {
        activationTask?.cancel()
        activationTask = nil
        if let resignKeyObserver {
            NotificationCenter.default.removeObserver(resignKeyObserver)
            self.resignKeyObserver = nil
        }
        if let closeObserver {
            NotificationCenter.default.removeObserver(closeObserver)
            self.closeObserver = nil
        }
    }
}

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

    /// Shows the panel at current mouse position, on the screen containing the cursor.
    func showAtMousePosition() {
        let mouseLocation = NSEvent.mouseLocation
        // Use the screen that actually contains the cursor (critical for multi-monitor setups).
        // NSScreen.main returns the screen with the menu bar, which may differ from the
        // screen the user is working on.
        let screenFrame = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) })?.frame
            ?? NSScreen.main?.frame
            ?? .zero

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
