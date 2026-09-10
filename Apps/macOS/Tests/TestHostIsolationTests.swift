import XCTest
@testable import PHTV

final class TestHostIsolationTests: XCTestCase {
    func testHostNeverUsesUserAppPreferencesIdentity() {
        XCTAssertEqual(Bundle.main.bundleIdentifier, PHTVTestHostEnvironment.bundleIdentifier)
        XCTAssertNotEqual(Bundle.main.bundleIdentifier, "com.phamhungtien.phtv.debug")
        XCTAssertNotEqual(Bundle.main.bundleIdentifier, "com.phamhungtien.phtv")
    }

    func testStorageLivesUnderTestHome() throws {
        let path = try XCTUnwrap(ProcessInfo.processInfo.environment["CFFIXED_USER_HOME"])
        let home = URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
        XCTAssertEqual(home.lastPathComponent, "PHTVTestHome")
        XCTAssertEqual(FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL, home)
        let appSupport = try XCTUnwrap(
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        )
        XCTAssertTrue(appSupport.path.hasPrefix(home.path + "/"))
    }
}
