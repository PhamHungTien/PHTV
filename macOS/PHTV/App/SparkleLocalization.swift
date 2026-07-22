//
//  SparkleLocalization.swift
//  PHTV
//
//  Vietnamese localization bridge for Sparkle framework.
//  Sparkle 2.x loads strings from its own framework bundle, which has no vi.lproj.
//  This swizzles NSBundle.localizedString so Sparkle picks up our app-bundled vi.lproj/Sparkle.strings.
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation
import ObjectiveC

enum SparkleLocalization {
    private final class SwizzleState: @unchecked Sendable {
        private let lock = NSLock()
        private var didSwizzle = false

        func installIfNeeded(_ install: () -> Bool) {
            lock.lock()
            defer { lock.unlock() }
            guard !didSwizzle else { return }
            didSwizzle = install()
        }
    }

    private static let state = SwizzleState()

    /// Call once at app launch (before any Sparkle UI appears).
    static func install() {
        state.installIfNeeded {
            let cls: AnyClass = Bundle.self
            let originalSel = #selector(Bundle.localizedString(forKey:value:table:))
            let swizzledSel = #selector(Bundle.phtv_localizedString(forKey:value:table:))

            guard let original = class_getInstanceMethod(cls, originalSel),
                  let swizzled = class_getInstanceMethod(cls, swizzledSel)
            else { return false }

            method_exchangeImplementations(original, swizzled)
            return true
        }
    }
}

private extension Bundle {
    /// After swizzle: calling `localizedString(forKey:value:table:)` lands here.
    /// Calling `phtv_localizedString(forKey:value:table:)` calls the **original** implementation.
    @objc dynamic func phtv_localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        // Only intercept Sparkle string lookups from non-main bundles
        if tableName == "Sparkle", self !== Bundle.main {
            // Try main bundle first (where our vi.lproj/Sparkle.strings lives)
            let localized = Bundle.main.phtv_localizedString(forKey: key, value: key, table: tableName)
            if localized != key {
                return localized
            }
        }
        // Fall back to the original implementation on the calling bundle
        return self.phtv_localizedString(forKey: key, value: value, table: tableName)
    }
}
