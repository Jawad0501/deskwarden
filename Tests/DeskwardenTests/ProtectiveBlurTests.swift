import XCTest
@testable import Deskwarden

private struct FakeClock: DeskClock {
    func secondsSinceArm() -> Int {
        4
    }
}

private final class FakeOverlay: DeskOverlay {
    private(set) var isCovered = false
    private(set) var isBlurred = false

    func cover(title: String, detail: String) {
        isCovered = true
    }

    func uncover() {
        isCovered = false
    }

    func showProtectiveBlur() {
        isBlurred = true
    }

    func hideProtectiveBlur() {
        isBlurred = false
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

private final class FakeChoices: DeskChoices {
    var soundEnabled: Bool
    var photoEnabled: Bool
    var coverTitle: String
    var coverDetail: String
    var protectiveBlurEnabled: Bool

    init(
        soundEnabled: Bool,
        photoEnabled: Bool,
        coverTitle: String,
        coverDetail: String,
        protectiveBlurEnabled: Bool
    ) {
        self.soundEnabled = soundEnabled
        self.photoEnabled = photoEnabled
        self.coverTitle = coverTitle
        self.coverDetail = coverDetail
        self.protectiveBlurEnabled = protectiveBlurEnabled
    }
}

private func makeChoices(protectiveBlurEnabled: Bool) -> FakeChoices {
    FakeChoices(
        soundEnabled: false,
        photoEnabled: false,
        coverTitle: "Office closed.",
        coverDetail: "Wait here.",
        protectiveBlurEnabled: protectiveBlurEnabled
    )
}

private func makeSession(overlay: FakeOverlay, choices: FakeChoices) -> DeskSession {
    DeskSession(
        clock: FakeClock(),
        overlay: overlay,
        power: FakePower(),
        authenticator: FakeAuthenticator(),
        choices: choices
    )
}

final class ProtectiveBlurTests: XCTestCase {
    func testProtectiveBlurFollowsChoiceUntilHardwarePointerReplacesIt() {
        XCTAssertFalse(StandardChoices().protectiveBlurEnabled)

        let clearOverlay = FakeOverlay()
        let clearSession = makeSession(
            overlay: clearOverlay,
            choices: makeChoices(protectiveBlurEnabled: false)
        )
        clearSession.arm()
        XCTAssertEqual(clearSession.mode, Mode.armed)
        XCTAssertFalse(clearOverlay.isBlurred)
        XCTAssertFalse(clearOverlay.isCovered)

        let blurOverlay = FakeOverlay()
        let blurSession = makeSession(
            overlay: blurOverlay,
            choices: makeChoices(protectiveBlurEnabled: true)
        )
        blurSession.arm()
        XCTAssertEqual(blurSession.mode, Mode.armed)
        XCTAssertTrue(blurOverlay.isBlurred)
        XCTAssertFalse(blurOverlay.isCovered)

        let hardwareDecision = blurSession.receive(eventKind: EventKind.mouse, unixProcessID: 0)
        XCTAssertEqual(hardwareDecision.mode, Mode.locked)
        XCTAssertEqual(blurSession.mode, Mode.locked)
        XCTAssertTrue(hardwareDecision.swallow)
        XCTAssertTrue(blurOverlay.isCovered)
        XCTAssertFalse(blurOverlay.isBlurred)

        let disarmOverlay = FakeOverlay()
        let disarmSession = makeSession(
            overlay: disarmOverlay,
            choices: makeChoices(protectiveBlurEnabled: true)
        )
        disarmSession.arm()
        XCTAssertTrue(disarmOverlay.isBlurred)
        disarmSession.disarm()
        XCTAssertFalse(disarmOverlay.isBlurred)
        XCTAssertEqual(disarmSession.mode, Mode.disarmed)
        XCTAssertFalse(disarmOverlay.isCovered)

        let applyOverlay = FakeOverlay()
        let applyChoices = makeChoices(protectiveBlurEnabled: false)
        let applySession = makeSession(overlay: applyOverlay, choices: applyChoices)
        applySession.arm()
        applyChoices.protectiveBlurEnabled = true
        applySession.applyChoices()
        XCTAssertEqual(applySession.mode, Mode.armed)
        XCTAssertTrue(applyOverlay.isBlurred)
        XCTAssertFalse(applyOverlay.isCovered)
        applyChoices.protectiveBlurEnabled = false
        applySession.applyChoices()
        XCTAssertEqual(applySession.mode, Mode.armed)
        XCTAssertFalse(applyOverlay.isBlurred)
        XCTAssertFalse(applyOverlay.isCovered)

        let lockedOverlay = FakeOverlay()
        let lockedChoices = makeChoices(protectiveBlurEnabled: true)
        let lockedSession = makeSession(overlay: lockedOverlay, choices: lockedChoices)
        lockedSession.arm()
        _ = lockedSession.receive(eventKind: EventKind.mouse, unixProcessID: 0)
        XCTAssertEqual(lockedSession.mode, Mode.locked)
        XCTAssertTrue(lockedOverlay.isCovered)
        lockedChoices.protectiveBlurEnabled = false
        lockedSession.applyChoices()
        XCTAssertEqual(lockedSession.mode, Mode.locked)
        XCTAssertTrue(lockedOverlay.isCovered)
        lockedChoices.protectiveBlurEnabled = true
        lockedSession.applyChoices()
        XCTAssertEqual(lockedSession.mode, Mode.locked)
        XCTAssertTrue(lockedOverlay.isCovered)
    }
}
