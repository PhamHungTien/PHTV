import AppKit
import SwiftUI

/// Enforce a readable minimum at the window boundary, without adding a competing
/// minimum-size proposal to NavigationSplitView during sidebar animation.
struct SettingsWindowMinimumSize: NSViewRepresentable {
    func makeNSView(context: Context) -> MinimumSizeView { MinimumSizeView() }
    func updateNSView(_ nsView: MinimumSizeView, context: Context) { nsView.configureWindow() }

    final class MinimumSizeView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            configureWindow()
        }

        func configureWindow() {
            guard let window else { return }
            let minimum = SettingsLayout.windowMinSize
            if window.contentMinSize != minimum { window.contentMinSize = minimum }
        }
    }
}
