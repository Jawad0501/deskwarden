import XCTest
@testable import Deskwarden

private struct FakeClock: DeskClock {
    func secondsSinceArm() -> Int {
        4
    }
}

private final class FakeOverlay: DeskOverlay {
    private(set) var isCovered = false
    private(set) var shownTitle = ""
    private(set) var shownDetail = ""

    func cover(title: String, detail: String) {
        isCovered = true
        shownTitle = title
        shownDetail = detail
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

private final class FakeChoices: DeskChoices {
    var soundEnabled: Bool
    var photoEnabled: Bool
    var coverTitle: String
    var coverDetail: String

    init(soundEnabled: Bool, photoEnabled: Bool, coverTitle: String, coverDetail: String) {
        self.soundEnabled = soundEnabled
        self.photoEnabled = photoEnabled
        self.coverTitle = coverTitle
        self.coverDetail = coverDetail
    }
}

final class OwnerChoicesTests: XCTestCase {
    func testOwnerCanTurnOffAlarmPhotoAndSetCoverText() {
        let clock = FakeClock()
        let overlay = FakeOverlay()
        let power = FakePower()
        let authenticator = FakeAuthenticator()
        let alarm = FakeAlarm()
        let camera = FakeCamera()
        let choices = FakeChoices(
            soundEnabled: true,
            photoEnabled: true,
            coverTitle: "Office closed.",
            coverDetail: "Wait here."
        )
        XCTAssertTrue(choices.soundEnabled)
        XCTAssertTrue(choices.photoEnabled)
        XCTAssertEqual(choices.coverTitle, "Office closed.")
        XCTAssertEqual(choices.coverDetail, "Wait here.")

        let session = DeskSession(
            clock: clock,
            overlay: overlay,
            power: power,
            authenticator: authenticator,
            alarm: alarm,
            camera: camera,
            choices: choices
        )

        session.arm()
        XCTAssertEqual(camera.readyCount, 1)
        XCTAssertEqual(camera.captureCount, 0)

        choices.soundEnabled = false
        choices.photoEnabled = false
        session.applyChoices()
        XCTAssertEqual(camera.restCount, 1)

        let decision = session.receive(eventKind: EventKind.key, unixProcessID: 0)
        XCTAssertEqual(decision.mode, Mode.locked)
        XCTAssertEqual(session.mode, Mode.locked)
        XCTAssertTrue(decision.swallow)
        XCTAssertTrue(overlay.isCovered)
        XCTAssertEqual(alarm.requestedSeconds, [])
        XCTAssertEqual(camera.captureCount, 0)
        XCTAssertEqual(overlay.shownTitle, "Office closed.")
        XCTAssertEqual(overlay.shownDetail, "Wait here.")
    }
}
