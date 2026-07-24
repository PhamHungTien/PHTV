//
//  PHTVUninstallerTests.swift
//  PHTV
//
//  Created by Phạm Hùng Tiến on 2026.
//  Copyright © 2026 Phạm Hùng Tiến. All rights reserved.
//

import XCTest
@testable import PHTV

final class PHTVUninstallerTests: XCTestCase {
    func testUninstallPlanCoversMainPHTVDataLocations() {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        let temporaryDirectory = fileManager.temporaryDirectory
        let paths = Set(PHTVUninstaller.makePlan(fileManager: fileManager).cleanupURLs.map(\.path))

        XCTAssertTrue(paths.contains(libraryPath(home, "Application Support", "PHTV")))
        XCTAssertTrue(paths.contains(libraryPath(home, "Logs", "PHTV")))
        XCTAssertTrue(paths.contains(libraryPath(home, "Preferences", "com.phamhungtien.phtv.plist")))
        XCTAssertTrue(paths.contains(libraryPath(home, "Caches", "com.phamhungtien.phtv")))
        XCTAssertTrue(paths.contains(temporaryDirectory.appendingPathComponent("PHTPMedia", isDirectory: true).standardizedFileURL.path))
    }

    func testUninstallPlanKeepsCleanupTargetsScopedToUserDataOrTemporaryData() {
        let fileManager = FileManager.default
        let homeLibraryPath = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .standardizedFileURL
            .path
        let temporaryDirectoryPath = fileManager.temporaryDirectory.standardizedFileURL.path

        let cleanupURLs = PHTVUninstaller.makePlan(fileManager: fileManager).cleanupURLs

        XCTAssertFalse(cleanupURLs.isEmpty)
        for url in cleanupURLs {
            let path = url.standardizedFileURL.path
            XCTAssertTrue(
                path.hasPrefix(homeLibraryPath + "/") || path.hasPrefix(temporaryDirectoryPath),
                "Unexpected uninstall cleanup path: \(path)"
            )
            XCTAssertNotEqual(path, homeLibraryPath)
            XCTAssertNotEqual(path, temporaryDirectoryPath)
        }
    }

    private func libraryPath(_ home: URL, _ components: String...) -> String {
        var url = home.appendingPathComponent("Library", isDirectory: true)
        for component in components {
            url.appendPathComponent(component)
        }
        return url.standardizedFileURL.path
    }
}
