import XCTest
@testable import Deskwarden

final class InputDecisionTests: XCTestCase {
    func testKeyFromProcess42StaysArmedThenKeyFromProcess0Locks() {
        let firstDecision = inputDecision(
            mode: Mode.armed,
            secondsSinceArm: 4,
            eventKind: EventKind.key,
            unixProcessID: 42
        )
        XCTAssertEqual(firstDecision.mode, Mode.armed)
        XCTAssertFalse(firstDecision.swallow)

        let secondDecision = inputDecision(
            mode: firstDecision.mode,
            secondsSinceArm: 4,
            eventKind: EventKind.key,
            unixProcessID: 0
        )
        XCTAssertEqual(secondDecision.mode, Mode.locked)
        XCTAssertTrue(secondDecision.swallow)
    }
}
