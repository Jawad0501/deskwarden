import XCTest
@testable import Deskwarden

final class TrackpadSwipeTests: XCTestCase {
    func testTrackpadSwipeCoversAnArmedDesk() {
        XCTAssertEqual(eventTypeRawValue(for: .swipe), 31)
        XCTAssertEqual(eventKind(for: .swipe), EventKind.gesture)

        XCTAssertEqual(eventTypeRawValue(for: .gesture), 29)
        XCTAssertEqual(eventKind(for: .gesture), EventKind.gesture)

        XCTAssertEqual(eventTypeRawValue(for: .beginGesture), 19)
        XCTAssertEqual(eventKind(for: .beginGesture), EventKind.gesture)

        XCTAssertEqual(eventTypeRawValue(for: .endGesture), 20)
        XCTAssertEqual(eventKind(for: .endGesture), EventKind.gesture)

        XCTAssertEqual(hardwareEvent(forEventTypeRawValue: 31), HardwareEvent.swipe)

        let decision = inputDecision(
            mode: Mode.armed,
            secondsSinceArm: 4,
            eventKind: eventKind(for: .swipe),
            unixProcessID: 0
        )
        XCTAssertEqual(decision.mode, Mode.locked)
        XCTAssertTrue(decision.swallow)
    }
}
