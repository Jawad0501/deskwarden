import XCTest
@testable import Deskwarden

private struct FakeClock: DeskClock {
    func secondsSinceArm() -> Int {
        0
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

private final class FakeAlarm: DeskAlarm {
    private(set) var requestedSeconds: [Int] = []
    private(set) var stopCount = 0

    func start(seconds: Int) {
        requestedSeconds.append(seconds)
    }

    func stop() {
        stopCount += 1
    }
}

private final class FakeCamera: DeskCamera {
    private(set) var readyCount = 0
    private(set) var captureCount = 0
    private(set) var restCount = 0

    func becomeReady() {
        readyCount += 1
    }

    func captureInstant() {
        captureCount += 1
    }

    func rest() {
        restCount += 1
    }
}

final class LockScreenCommandTests: XCTestCase {
    func testArmedLockChordCoversDuringGraceAndDisarmLetsItPass() {
        let clock = FakeClock()
        let overlay = FakeOverlay()
        let power = FakePower()
        let authenticator = FakeAuthenticator()
        let alarm = FakeAlarm()
        let camera = FakeCamera()
        let session = DeskSession(
            clock: clock,
            overlay: overlay,
            power: power,
            authenticator: authenticator,
            alarm: alarm,
            camera: camera
        )

        session.arm()
        XCTAssertEqual(session.mode, Mode.armed)

        let armedCommand = session.receiveLockScreenCommand(
            keyCode: 12,
            control: true,
            command: true,
            option: false,
            shift: false,
            unixProcessID: 0
        )
        XCTAssertTrue(armedCommand.swallow)
        XCTAssertEqual(armedCommand.mode, Mode.locked)
        XCTAssertEqual(session.mode, Mode.locked)
        XCTAssertTrue(overlay.isCovered)
        XCTAssertEqual(alarm.requestedSeconds, [5])
        XCTAssertEqual(camera.captureCount, 1)

        let lockedCommand = session.receiveLockScreenCommand(
            keyCode: 12,
            control: true,
            command: true,
            option: false,
            shift: false,
            unixProcessID: 0
        )
        XCTAssertTrue(lockedCommand.swallow)
        XCTAssertEqual(lockedCommand.mode, Mode.locked)
        XCTAssertEqual(session.mode, Mode.locked)
        XCTAssertEqual(alarm.requestedSeconds, [5])
        XCTAssertEqual(camera.captureCount, 1)

        session.disarm()
        XCTAssertEqual(session.mode, Mode.disarmed)
        XCTAssertFalse(overlay.isCovered)

        let disarmedCommand = session.receiveLockScreenCommand(
            keyCode: 12,
            control: true,
            command: true,
            option: false,
            shift: false,
            unixProcessID: 0
        )
        XCTAssertFalse(disarmedCommand.swallow)
        XCTAssertEqual(disarmedCommand.mode, Mode.disarmed)
        XCTAssertEqual(session.mode, Mode.disarmed)
        XCTAssertFalse(overlay.isCovered)

        session.arm()
        XCTAssertEqual(session.mode, Mode.armed)

        let differentKey = session.receiveLockScreenCommand(
            keyCode: 0,
            control: true,
            command: true,
            option: false,
            shift: false,
            unixProcessID: 0
        )
        XCTAssertFalse(differentKey.swallow)
        XCTAssertEqual(differentKey.mode, Mode.armed)
        XCTAssertEqual(session.mode, Mode.armed)
        XCTAssertFalse(overlay.isCovered)

        let otherProcess = session.receiveLockScreenCommand(
            keyCode: 12,
            control: true,
            command: true,
            option: false,
            shift: false,
            unixProcessID: 42
        )
        XCTAssertFalse(otherProcess.swallow)
        XCTAssertEqual(otherProcess.mode, Mode.armed)
        XCTAssertEqual(session.mode, Mode.armed)
        XCTAssertFalse(overlay.isCovered)

        let missingCommand = session.receiveLockScreenCommand(
            keyCode: 12,
            control: true,
            command: false,
            option: false,
            shift: false,
            unixProcessID: 0
        )
        XCTAssertFalse(missingCommand.swallow)
        XCTAssertEqual(missingCommand.mode, Mode.armed)
        XCTAssertEqual(session.mode, Mode.armed)
        XCTAssertFalse(overlay.isCovered)
    }
}
