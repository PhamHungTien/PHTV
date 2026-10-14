import AppKit
import SwiftUI

/// Enforce a readable minimum at the window boundary, without adding a competing
/// minimum-size proposal to NavigationSplitView during sidebar animation.
struct SettingsWindowMinimumSize: NSViewRepresentable {
    func makeNSView(context: Context) -> MinimumSizeView { MinimumSizeView() }
    func updateNSView(_ nsView: MinimumSizeView, context: Context) { nsView.configureWindow() }

    static func dismantleNSView(_ nsView: MinimumSizeView, coordinator: ()) {
        nsView.stopObserving()
    }

    final class MinimumSizeView: NSView {
        private var resizeObserver: NSObjectProtocol?

        func stopObserving() {
            if let resizeObserver { NotificationCenter.default.removeObserver(resizeObserver) }
            resizeObserver = nil
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stopObserving()
            guard let attachedWindow = window else { return }
            configureWindow()
            // SwiftUI applies restoration and scene sizing after attaching the hosting view.
            DispatchQueue.main.async { [weak self, weak attachedWindow] in
                guard let self, let attachedWindow, self.window === attachedWindow else { return }
                self.configureWindow()
                let minimum = SettingsLayout.windowMinSize
                let current = attachedWindow.contentRect(forFrameRect: attachedWindow.frame).size
                if current.width < minimum.width || current.height < minimum.height {
                    attachedWindow.setContentSize(NSSize(width: max(current.width, minimum.width), height: max(current.height, minimum.height)))
                }
            }
            resizeObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.willStartLiveResizeNotification, object: attachedWindow, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.configureWindow() }
            }
        }

        func configureWindow() {
            guard let window else { return }
            window.isRestorable = false
            let minimum = SettingsLayout.windowMinSize
            if window.contentMinSize != minimum { window.contentMinSize = minimum }
        }
    }
}
