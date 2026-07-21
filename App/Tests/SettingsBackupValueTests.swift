import Foundation
import XCTest
@testable import PHTV

final class SettingsBackupValueTests: XCTestCase {
    func testSupportedDefaultsValuesRoundTripWithoutUncheckedSendableStorage() throws {
        let values = [
            AnyCodableValue(NSNumber(value: 42)),
            AnyCodableValue(NSNumber(value: 1.5)),
            AnyCodableValue(NSNumber(value: true)),
            AnyCodableValue("PHTV"),
        ]

        let data = try JSONEncoder().encode(values)
        let decoded = try JSONDecoder().decode([AnyCodableValue].self, from: data)

        XCTAssertEqual(decoded[0].value as? Int, 42)
        XCTAssertEqual(decoded[1].value as? Double, 1.5)
        XCTAssertEqual(decoded[2].value as? Bool, true)
        XCTAssertEqual(decoded[3].value as? String, "PHTV")
    }
}
