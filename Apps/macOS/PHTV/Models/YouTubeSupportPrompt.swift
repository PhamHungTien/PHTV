import Foundation

enum PHTVCommunityLinks {
    static let tutorial = URL(string: "https://www.youtube.com/watch?v=VaE4dZncBRs")!
    static let youtube = URL(string: "https://www.youtube.com/@phamhungtien14")!
}

enum YouTubeSupportPromptPolicy {
    static let lastPresentedVersionKey = "PHTV_YouTubeSupportPromptVersion"

    static func shouldPresent(version: String, lastPresentedVersion: String, onboardingCompleted: Bool) -> Bool {
        onboardingCompleted && !version.isEmpty && version != lastPresentedVersion
    }
}
