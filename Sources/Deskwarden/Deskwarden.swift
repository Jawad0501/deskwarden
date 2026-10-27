public enum Mode: Equatable {
    case disarmed
    case armed
    case locked
}

public enum EventKind: Equatable {
    case key
    case mouse
}

public enum HardwareEvent: CaseIterable {
    case keyDown
    case keyUp
    case flagsChanged
    case mouseMoved
    case leftMouseDown
    case leftMouseUp
    case leftMouseDragged
    case rightMouseDown
    case rightMouseUp
    case rightMouseDragged
    case otherMouseDown
    case otherMouseUp
    case otherMouseDragged
    case scrollWheel
}

public func eventKind(for event: HardwareEvent) -> EventKind {
    switch event {
    case .keyDown, .keyUp, .flagsChanged:
        return .key
    case .mouseMoved, .leftMouseDown, .leftMouseUp, .leftMouseDragged, .rightMouseDown, .rightMouseUp,
        .rightMouseDragged, .otherMouseDown, .otherMouseUp, .otherMouseDragged, .scrollWheel:
        return .mouse
    }
}

public struct InputDecision {
    public let mode: Mode
    public let swallow: Bool
}

func inputDecision(
    mode: Mode,
    secondsSinceArm: Int,
    eventKind: EventKind,
    unixProcessID: Int
) -> InputDecision {
    let graceLimit = 3
    let graceIsOpen = secondsSinceArm < graceLimit
    switch (mode, eventKind) {
    case (.armed, .key), (.armed, .mouse):
        if graceIsOpen || unixProcessID != 0 {
            return InputDecision(mode: mode, swallow: false)
        }
        return InputDecision(mode: .locked, swallow: true)
    case (.disarmed, .key), (.disarmed, .mouse), (.locked, .key), (.locked, .mouse):
        return InputDecision(mode: mode, swallow: false)
    }
}
