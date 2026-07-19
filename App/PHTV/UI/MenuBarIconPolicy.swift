//
//  MenuBarIconPolicy.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

enum PHTVMenuBarIconPolicy {
    static func assetName(
        isVietnameseEnabled: Bool,
        useVietnameseIcon: Bool,
        isUsingNonLatinInputSource: Bool,
        languageBeforeNonLatinInputSource: Int
    ) -> String {
        let isVietnameseTemporarilySuspended =
            isUsingNonLatinInputSource && languageBeforeNonLatinInputSource != 0

        guard isVietnameseEnabled || isVietnameseTemporarilySuspended else {
            return "menubar_english"
        }
        return useVietnameseIcon ? "menubar_vietnamese" : "menubar_icon"
    }
}
