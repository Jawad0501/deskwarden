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

final class AlarmPhotoTests: XCTestCase {
    func testHardwareTouchStartsAlarmAndInstantPhoto() {
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

        XCTAssertEqual(camera.readyCount, 0)
        XCTAssertEqual(camera.captureCount, 0)

        session.arm()
        XCTAssertEqual(session.mode, Mode.armed)
        XCTAssertEqual(camera.readyCount, 1)
        XCTAssertEqual(camera.captureCount, 0)
        XCTAssertEqual(alarm.requestedSeconds, [])

        let syntheticDecision = session.receive(eventKind: EventKind.key, unixProcessID: 42)
        XCTAssertEqual(syntheticDecision.mode, Mode.armed)
        XCTAssertEqual(session.mode, Mode.armed)
        XCTAssertFalse(syntheticDecision.swallow)
        XCTAssertFalse(overlay.isCovered)
        XCTAssertEqual(camera.captureCount, 0)
        XCTAssertEqual(alarm.requestedSeconds, [])

        let hardwareDecision = session.receive(eventKind: EventKind.key, unixProcessID: 0)
        XCTAssertEqual(hardwareDecision.mode, Mode.locked)
        XCTAssertEqual(session.mode, Mode.locked)
        XCTAssertTrue(hardwareDecision.swallow)
        XCTAssertTrue(overlay.isCovered)
        XCTAssertEqual(alarm.requestedSeconds, [5])
        XCTAssertEqual(camera.captureCount, 1)

        let laterDecision = session.receive(eventKind: EventKind.mouse, unixProcessID: 0)
        XCTAssertEqual(laterDecision.mode, Mode.locked)
        XCTAssertEqual(session.mode, Mode.locked)
        XCTAssertFalse(laterDecision.swallow)
        XCTAssertTrue(overlay.isCovered)
        XCTAssertEqual(alarm.requestedSeconds, [5])
        XCTAssertEqual(camera.captureCount, 1)

        session.unlock()
        XCTAssertEqual(alarm.stopCount, 1)
        XCTAssertEqual(camera.restCount, 1)
    }
}
