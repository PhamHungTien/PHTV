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
        languageBeforeNonLatinInputSource: Int
    ) -> PHTVMenuBarIconPresentation {
        if isUsingNonLatinInputSource {
            let fallbackAssetName = languageBeforeNonLatinInputSource != 0
                ? vietnameseAssetName(useVietnameseIcon: useVietnameseIcon)
                : "menubar_english"
            return .currentInputSource(fallbackAssetName: fallbackAssetName)
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
