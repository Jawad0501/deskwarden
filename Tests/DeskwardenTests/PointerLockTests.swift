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

final class PointerLockTests: XCTestCase {
    func testSyntheticPointerStaysOpenThenHardwarePointerCovers() {
        XCTAssertEqual(eventKind(for: .leftMouseDown), EventKind.mouse)
        XCTAssertEqual(eventKind(for: .scrollWheel), EventKind.mouse)
        XCTAssertEqual(eventKind(for: .mouseMoved), EventKind.mouse)

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

        session.arm()

        let syntheticDecision = session.receive(eventKind: EventKind.mouse, unixProcessID: 42)
        XCTAssertEqual(syntheticDecision.mode, Mode.armed)
        XCTAssertEqual(session.mode, Mode.armed)
        XCTAssertFalse(syntheticDecision.swallow)
        XCTAssertFalse(overlay.isCovered)

        let hardwareDecision = session.receive(eventKind: EventKind.mouse, unixProcessID: 0)
        XCTAssertEqual(hardwareDecision.mode, Mode.locked)
        XCTAssertEqual(session.mode, Mode.locked)
        XCTAssertTrue(hardwareDecision.swallow)
        XCTAssertTrue(overlay.isCovered)

        let laterDecision = session.receive(eventKind: EventKind.mouse, unixProcessID: 0)
        XCTAssertEqual(laterDecision.mode, Mode.locked)
        XCTAssertEqual(session.mode, Mode.locked)
        XCTAssertFalse(laterDecision.swallow)
        XCTAssertTrue(overlay.isCovered)
    }
}
