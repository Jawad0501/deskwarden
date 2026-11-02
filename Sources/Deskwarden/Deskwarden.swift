public enum Mode: Equatable {
    case disarmed
    case armed
    case locked
}

public enum EventKind: Equatable {
    case key
    case mouse
    case gesture
    case dockSwipe
}

public enum HardwareEvent: CaseIterable, Equatable {
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
    case beginGesture
    case endGesture
    case gesture
    case swipe
    case dockControl
}

public func eventKind(for event: HardwareEvent) -> EventKind {
    switch event {
    case .keyDown, .keyUp, .flagsChanged:
        return .key
    case .beginGesture, .endGesture, .gesture, .swipe:
        return .gesture
    case .dockControl:
        return .dockSwipe
    case .mouseMoved, .leftMouseDown, .leftMouseUp, .leftMouseDragged, .rightMouseDown, .rightMouseUp,
        .rightMouseDragged, .otherMouseDown, .otherMouseUp, .otherMouseDragged, .scrollWheel:
        return .mouse
    }
}

public func eventTypeRawValue(for event: HardwareEvent) -> UInt32 {
    switch event {
    case .keyDown:
        return 10
    case .keyUp:
        return 11
    case .flagsChanged:
        return 12
    case .mouseMoved:
        return 5
    case .leftMouseDown:
        return 1
    case .leftMouseUp:
        return 2
    case .leftMouseDragged:
        return 6
    case .rightMouseDown:
        return 3
    case .rightMouseUp:
        return 4
    case .rightMouseDragged:
        return 7
    case .otherMouseDown:
        return 25
    case .otherMouseUp:
        return 26
    case .otherMouseDragged:
        return 27
    case .scrollWheel:
        return 22
    case .beginGesture:
        return 19
    case .endGesture:
        return 20
    case .gesture:
        return 29
    case .swipe:
        return 31
    case .dockControl:
        return 30
    }
}

public func hardwareEvent(forEventTypeRawValue raw: UInt32) -> HardwareEvent? {
    for event in HardwareEvent.allCases {
        if eventTypeRawValue(for: event) == raw {
            return event
        }
    }
    return nil
}

public func hardwareEvent(callbackRawValue: UInt32, routedRawValue: UInt32) -> HardwareEvent? {
    if routedRawValue != 0, let routed = hardwareEvent(forEventTypeRawValue: routedRawValue) {
        return routed
    }
    return hardwareEvent(forEventTypeRawValue: callbackRawValue)
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
    case (.armed, .key), (.armed, .mouse), (.armed, .gesture), (.armed, .dockSwipe):
        if graceIsOpen || unixProcessID != 0 {
            return InputDecision(mode: mode, swallow: false)
        }
        return InputDecision(mode: .locked, swallow: true)
    case (.locked, .gesture):
        return InputDecision(mode: mode, swallow: unixProcessID == 0)
    case (.locked, .dockSwipe):
        return InputDecision(mode: .locked, swallow: true)
    case (.disarmed, .key), (.disarmed, .mouse), (.disarmed, .gesture), (.disarmed, .dockSwipe), (.locked, .key),
        (.locked, .mouse):
        return InputDecision(mode: mode, swallow: false)
    }
}
