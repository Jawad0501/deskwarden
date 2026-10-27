import XCTest
@testable import Deskwarden

final class SetupNoticeTests: XCTestCase {
    func testUntrustedMacAsksToOpenPrivacySettings() throws {
        let notice = try XCTUnwrap(setupNotice(accessibilityTrusted: false))
        XCTAssertEqual(
            notice.settingsURL.absoluteString,
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility"
        )
        XCTAssertTrue(notice.message.contains("Accessibility"))
        XCTAssertTrue(notice.message.contains("Input Monitoring"))
        XCTAssertEqual(notice.buttonTitle, "Open System Settings")

        XCTAssertNil(setupNotice(accessibilityTrusted: true))
    }
}
