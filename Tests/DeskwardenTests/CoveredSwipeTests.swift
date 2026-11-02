import XCTest
@testable import Deskwarden

private struct FakeClock: DeskClock {
    func secondsSinceArm() -> Int {
        4
    }
}

private final class FakeOverlay: DeskOverlay {
    private(set) var isCovered = false

    func cover(title: String, detail: String) {
        isCovered = true
    }

    func uncover() {
        isCovered = false
    }
}

private final class FakePower: DeskPower {
    private(set) var heldNames: [String] = []

    func hold(_ name: String) {
        heldNames.append(name)
    }
}

private final class FakeAuthenticator: DeskAuthenticator {
    private(set) var requestedPolicyName: String?

    func authenticate(policyName: String, complete: @escaping (Bool) -> Void) {
        requestedPolicyName = policyName
        complete(true)
    }
}

final class CoveredSwipeTests: XCTestCase {
    func testCoveredDeskSwallowsASwipeAndPassesAClick() {
        let clock = FakeClock()
        let overlay = FakeOverlay()
        let power = FakePower()
        let authenticator = FakeAuthenticator()
        let session = DeskSession(
            clock: clock,
            overlay: overlay,
            power: power,
            authenticator: authenticator
        )

        XCTAssertEqual(session.mode, Mode.disarmed)
        XCTAssertFalse(overlay.isCovered)

        session.arm()

        let firstSwipe = session.receive(eventKind: eventKind(for: .swipe), unixProcessID: 0)
        XCTAssertEqual(firstSwipe.mode, Mode.locked)
        XCTAssertEqual(session.mode, Mode.locked)
        XCTAssertTrue(firstSwipe.swallow)
        XCTAssertTrue(overlay.isCovered)

        let secondSwipe = session.receive(eventKind: eventKind(for: .swipe), unixProcessID: 0)
        XCTAssertEqual(secondSwipe.mode, Mode.locked)
        XCTAssertEqual(session.mode, Mode.locked)
        XCTAssertTrue(secondSwipe.swallow)
        XCTAssertTrue(overlay.isCovered)

        let click = session.receive(eventKind: eventKind(for: .leftMouseDown), unixProcessID: 0)
        XCTAssertEqual(click.mode, Mode.locked)
        XCTAssertEqual(session.mode, Mode.locked)
        XCTAssertFalse(click.swallow)
        XCTAssertTrue(overlay.isCovered)

        let beginGesture = session.receive(eventKind: eventKind(for: .beginGesture), unixProcessID: 0)
        XCTAssertEqual(beginGesture.mode, Mode.locked)
        XCTAssertEqual(session.mode, Mode.locked)
        XCTAssertTrue(beginGesture.swallow)

        let gesture = session.receive(eventKind: eventKind(for: .gesture), unixProcessID: 0)
        XCTAssertEqual(gesture.mode, Mode.locked)
        XCTAssertEqual(session.mode, Mode.locked)
        XCTAssertTrue(gesture.swallow)

        let endGesture = session.receive(eventKind: eventKind(for: .endGesture), unixProcessID: 0)
        XCTAssertEqual(endGesture.mode, Mode.locked)
        XCTAssertEqual(session.mode, Mode.locked)
        XCTAssertTrue(endGesture.swallow)

        let remoteSwipe = session.receive(eventKind: eventKind(for: .swipe), unixProcessID: 42)
        XCTAssertEqual(remoteSwipe.mode, Mode.locked)
        XCTAssertEqual(session.mode, Mode.locked)
        XCTAssertFalse(remoteSwipe.swallow)
    }

    func testWindowSwipeStaysSwallowedWhileCovered() {
        XCTAssertEqual(eventTypeRawValue(for: .dockControl), 30)
        XCTAssertEqual(eventKind(for: .dockControl), EventKind.dockSwipe)
        XCTAssertEqual(hardwareEvent(forEventTypeRawValue: 30), HardwareEvent.dockControl)
        XCTAssertEqual(
            hardwareEvent(callbackRawValue: 29, routedRawValue: 30),
            HardwareEvent.dockControl
        )

        let clock = FakeClock()
        let overlay = FakeOverlay()
        let session = DeskSession(
            clock: clock,
            overlay: overlay,
            power: FakePower(),
            authenticator: FakeAuthenticator()
        )
        session.arm()

        let first = session.receive(eventKind: eventKind(for: .dockControl), unixProcessID: 0)
        XCTAssertEqual(first.mode, Mode.locked)
        XCTAssertTrue(first.swallow)
        XCTAssertTrue(overlay.isCovered)

        let later = session.receive(eventKind: eventKind(for: .dockControl), unixProcessID: 0)
        XCTAssertEqual(later.mode, Mode.locked)
        XCTAssertTrue(later.swallow)

        let systemSwipe = session.receive(eventKind: eventKind(for: .dockControl), unixProcessID: 42)
        XCTAssertEqual(systemSwipe.mode, Mode.locked)
        XCTAssertTrue(systemSwipe.swallow)

        let click = session.receive(eventKind: eventKind(for: .leftMouseDown), unixProcessID: 0)
        XCTAssertEqual(click.mode, Mode.locked)
        XCTAssertFalse(click.swallow)
    }
}
