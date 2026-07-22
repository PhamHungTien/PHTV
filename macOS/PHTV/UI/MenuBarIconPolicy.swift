//
//  MenuBarIconPolicy.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

enum PHTVMenuBarIconPresentation: Equatable {
    case bundledAsset(String)
    case currentInputSource(fallbackAssetName: String)
}

enum PHTVMenuBarIconPolicy {
    static func presentation(
        isVietnameseEnabled: Bool,
        useVietnameseIcon: Bool,
        isUsingNonLatinInputSource: Bool,
        isEnglishLocked: Bool = false
    ) -> PHTVMenuBarIconPresentation {
        if isEnglishLocked {
            return .bundledAsset("menubar_english")
        }

        if isUsingNonLatinInputSource {
            return .currentInputSource(fallbackAssetName: "menubar_english")
        }

        guard isVietnameseEnabled else {
            return .bundledAsset("menubar_english")
        }
        return .bundledAsset(vietnameseAssetName(useVietnameseIcon: useVietnameseIcon))
    }

    private static func vietnameseAssetName(useVietnameseIcon: Bool) -> String {
        useVietnameseIcon ? "menubar_vietnamese" : "menubar_icon"
    }
}
