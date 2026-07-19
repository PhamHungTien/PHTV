//
//  PHTVLanguageLockPolicy.swift
//  PHTV
//
//  Enforces the per-app English-only rule at the runtime boundary.
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

enum PHTVLanguageLockPolicy {
    static func resolvedLanguage(
        requestedLanguage: Int32,
        isEnglishLocked: Bool
    ) -> Int32 {
        isEnglishLocked ? 0 : requestedLanguage
    }
}
