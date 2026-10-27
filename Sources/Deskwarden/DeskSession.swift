public protocol DeskClock {
    func secondsSinceArm() -> Int
}

public protocol DeskOverlay: AnyObject {
    func cover(title: String, detail: String)
    func uncover()
    var isCovered: Bool { get }
}

public protocol DeskChoices: AnyObject {
    var soundEnabled: Bool { get set }
    var photoEnabled: Bool { get set }
    var coverTitle: String { get set }
    var coverDetail: String { get set }
}

public protocol DeskPower: AnyObject {
    func hold(_ name: String)
    var heldNames: [String] { get }
}

public protocol DeskAuthenticator: AnyObject {
    func authenticate(policyName: String, complete: @escaping (Bool) -> Void)
    var requestedPolicyName: String? { get }
}

public protocol DeskAlarm: AnyObject {
    func start(seconds: Int)
    func stop()
    var requestedSeconds: [Int] { get }
    var stopCount: Int { get }
}

public protocol DeskCamera: AnyObject {
    func becomeReady()
    func captureInstant()
    func rest()
    var readyCount: Int { get }
    var captureCount: Int { get }
    var restCount: Int { get }
}

public final class NoOpAlarm: DeskAlarm {
    public private(set) var requestedSeconds: [Int] = []
    public private(set) var stopCount = 0

    public init() {}

    public func start(seconds: Int) {}

    public func stop() {}
}

public final class NoOpCamera: DeskCamera {
    public private(set) var readyCount = 0
    public private(set) var captureCount = 0
    public private(set) var restCount = 0

    public init() {}

    public func becomeReady() {}

    public func captureInstant() {}

    public func rest() {}
}

public final class StandardChoices: DeskChoices {
    public static let defaultCoverTitle = "The authorized person is out."
    public static let defaultCoverDetail = "Please wait."

    public var soundEnabled: Bool
    public var photoEnabled: Bool
    public var coverTitle: String
    public var coverDetail: String

    public init() {
        soundEnabled = true
        photoEnabled = true
        coverTitle = StandardChoices.defaultCoverTitle
        coverDetail = StandardChoices.defaultCoverDetail
    }
}

public final class DeskSession {
    public private(set) var mode: Mode
    private let clock: any DeskClock
    private let overlay: any DeskOverlay
    private let power: any DeskPower
    private let authenticator: any DeskAuthenticator
    private let alarm: any DeskAlarm
    private let camera: any DeskCamera
    private let choices: any DeskChoices

    public init(
        clock: any DeskClock,
        overlay: any DeskOverlay,
        power: any DeskPower,
        authenticator: any DeskAuthenticator,
        alarm: any DeskAlarm = NoOpAlarm(),
        camera: any DeskCamera = NoOpCamera(),
        choices: any DeskChoices = StandardChoices()
    ) {
        self.clock = clock
        self.overlay = overlay
        self.power = power
        self.authenticator = authenticator
        self.alarm = alarm
        self.camera = camera
        self.choices = choices
        self.mode = .disarmed
        power.hold("PreventUserIdleDisplaySleep")
        power.hold("PreventUserIdleSystemSleep")
    }

    public func arm() {
        mode = .armed
        if choices.photoEnabled {
            camera.becomeReady()
        }
    }

    public func applyChoices() {
        if !choices.photoEnabled {
            camera.rest()
        }
        if !choices.soundEnabled {
            alarm.stop()
        }
        if choices.photoEnabled && mode == .armed {
            camera.becomeReady()
        }
    }

    public func disarm() {
        mode = .disarmed
        alarm.stop()
        camera.rest()
        overlay.uncover()
    }

    public func receive(eventKind: EventKind, unixProcessID: Int) -> InputDecision {
        let decision = inputDecision(
            mode: mode,
            secondsSinceArm: clock.secondsSinceArm(),
            eventKind: eventKind,
            unixProcessID: unixProcessID
        )
        let wasLocked = mode == .locked
        mode = decision.mode
        if mode == .locked && !wasLocked {
            overlay.cover(
                title: shownLine(choices.coverTitle, fallback: StandardChoices.defaultCoverTitle),
                detail: shownLine(choices.coverDetail, fallback: StandardChoices.defaultCoverDetail)
            )
            if choices.soundEnabled {
                alarm.start(seconds: 5)
            }
            if choices.photoEnabled {
                camera.captureInstant()
            }
        }
        return decision
    }

    public func unlock() {
        authenticator.authenticate(policyName: "deviceOwnerAuthentication") { success in
            guard success else {
                return
            }
            self.mode = .disarmed
            self.alarm.stop()
            self.camera.rest()
            self.overlay.uncover()
        }
    }

    private func shownLine(_ line: String, fallback: String) -> String {
        if line.allSatisfy({ $0.isWhitespace }) {
            return fallback
        }
        return line
    }
}
