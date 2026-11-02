import XCTest
@testable import Deskwarden

final class UpdateCheckTests: XCTestCase {
    func testCheckForUpdatesOpensTheReleasePage() {
        let releasePage = URL(string: "https://github.com/Jawad0501/deskwarden/releases")!
        XCTAssertEqual(
            updateCheckAction(),
            UpdateCheckAction.openInBrowser(releasePage)
        )
    }
}
