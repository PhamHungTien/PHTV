//
//  AppModels.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import Foundation

// MARK: - Excluded App Model

struct ExcludedApp: Codable, Identifiable, Hashable {
    var id: String { bundleIdentifier }
    let bundleIdentifier: String
    let name: String
    let path: String

    init(bundleIdentifier: String, name: String, path: String) {
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.path = path
    }

    init?(from url: URL) {
        guard let bundle = Bundle(url: url),
            let bundleId = bundle.bundleIdentifier,
            let name = bundle.infoDictionary?["CFBundleName"] as? String ?? bundle.infoDictionary?[
                "CFBundleDisplayName"] as? String
        else { return nil }

        self.bundleIdentifier = bundleId
        self.name = name
        self.path = url.path
    }
}

// MARK: - Send Key Step By Step App Model

struct SendKeyStepByStepApp: Codable, Identifiable, Hashable {
    var id: String { bundleIdentifier }
    let bundleIdentifier: String
    let name: String
    let path: String

    init(bundleIdentifier: String, name: String, path: String) {
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.path = path
    }

    init?(from url: URL) {
        guard let bundle = Bundle(url: url),
            let bundleId = bundle.bundleIdentifier,
            let name = bundle.infoDictionary?["CFBundleName"] as? String ?? bundle.infoDictionary?[
                "CFBundleDisplayName"] as? String
        else { return nil }

        self.bundleIdentifier = bundleId
        self.name = name
        self.path = url.path
    }
}
