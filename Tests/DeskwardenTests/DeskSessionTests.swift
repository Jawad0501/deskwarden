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

final class DeskSessionTests: XCTestCase {
    func testSyntheticKeyStaysOpenThenHardwareKeyCoversUntilUnlock() {
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
        XCTAssertTrue(power.heldNames.contains("PreventUserIdleDisplaySleep"))
        XCTAssertTrue(power.heldNames.contains("PreventUserIdleSystemSleep"))

        session.arm()
        XCTAssertEqual(session.mode, Mode.armed)
        XCTAssertFalse(overlay.isCovered)

        let syntheticDecision = session.receive(eventKind: EventKind.key, unixProcessID: 42)
        XCTAssertEqual(syntheticDecision.mode, Mode.armed)
        XCTAssertEqual(session.mode, Mode.armed)
        XCTAssertFalse(syntheticDecision.swallow)
        XCTAssertFalse(overlay.isCovered)

        let hardwareDecision = session.receive(eventKind: EventKind.key, unixProcessID: 0)
        XCTAssertEqual(hardwareDecision.mode, Mode.locked)
        XCTAssertEqual(session.mode, Mode.locked)
        XCTAssertTrue(hardwareDecision.swallow)
        XCTAssertTrue(overlay.isCovered)

        session.unlock()
        XCTAssertEqual(authenticator.requestedPolicyName, "deviceOwnerAuthentication")
        XCTAssertEqual(session.mode, Mode.disarmed)
        XCTAssertFalse(overlay.isCovered)
        XCTAssertTrue(power.heldNames.contains("PreventUserIdleDisplaySleep"))
        XCTAssertTrue(power.heldNames.contains("PreventUserIdleSystemSleep"))
    }
}
