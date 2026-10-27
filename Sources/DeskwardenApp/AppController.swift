import AppKit
@preconcurrency import ApplicationServices
import CoreGraphics
import Deskwarden

@main
@MainActor
final class AppController: NSObject, NSApplicationDelegate {
    private let clock = ArmClock()
    private let overlay = CoverOverlay()
    private let power = PowerHold()
    private let alarm = ToneAlarm()
    private let camera = InstantCamera()
    private let choices: StoredChoices
    private let authenticator: OwnerAuthenticator
    private let session: DeskSession
    private var settingsWindow: SettingsWindow?
    private var statusItem: NSStatusItem?
    private var eventTap: CFMachPort?
    private var eventTapSource: CFRunLoopSource?

    override init() {
        let authenticator = OwnerAuthenticator(overlay: overlay)
        let choices = StoredChoices()
        session = DeskSession(
            clock: clock,
            overlay: overlay,
            power: power,
            authenticator: authenticator,
            alarm: alarm,
            camera: camera,
            choices: choices
        )
        self.authenticator = authenticator
        self.choices = choices
        super.init()
        overlay.onUnlock = { [weak self] in
            self?.session.unlock()
        }
        authenticator.onSessionChange = { [weak self] in
            self?.showMode()
        }
    }

    static func main() {
        let app = NSApplication.shared
        let controller = AppController()
        app.setActivationPolicy(.accessory)
        app.delegate = controller
        withExtendedLifetime(controller) {
            app.run()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        promptForAccessibility()
        showSetupNotice()
        installStatusItem()
        armDesk()
        installEventTap()
    }

    private func armDesk() {
        clock.start()
        session.arm()
        showMode()
    }

    @objc private func armFromMenu(_ sender: Any?) {
        armDesk()
    }

    @objc private func disarmFromMenu(_ sender: Any?) {
        session.disarm()
        showMode()
    }

    @objc private func showCaptures(_ sender: Any?) {
        guard let directory = capturesDirectoryURL() else {
            return
        }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        NSWorkspace.shared.open(directory)
    }

    @objc private func showSettings(_ sender: Any?) {
        if settingsWindow == nil {
            settingsWindow = SettingsWindow(choices: choices) { [weak self] in
                self?.session.applyChoices()
            }
        }
        settingsWindow?.show()
    }

    @objc private func quit(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        menu.addItem(menuItem("Arm", #selector(armFromMenu(_:))))
        menu.addItem(menuItem("Disarm", #selector(disarmFromMenu(_:))))
        menu.addItem(menuItem("Show captures", #selector(showCaptures(_:))))
        menu.addItem(menuItem("Settings", #selector(showSettings(_:))))
        menu.addItem(menuItem("Quit", #selector(quit(_:))))
        item.menu = menu
        statusItem = item
        showMode()
    }

    private func menuItem(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func showMode() {
        let title: String
        switch session.mode {
        case .disarmed:
            title = "Disarmed"
        case .armed:
            title = "Armed"
        case .locked:
            title = "Locked"
        }
        statusItem?.button?.title = title
    }

    private func promptForAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    private func showSetupNotice() {
        if AXIsProcessTrusted() == false {
            guard let notice = setupNotice(accessibilityTrusted: false) else {
                return
            }
            let alert = NSAlert()
            alert.messageText = notice.message
            alert.addButton(withTitle: notice.buttonTitle)
            alert.addButton(withTitle: "Later")
            NSApp.activate()
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(notice.settingsURL)
            }
        }
    }

    private func installEventTap() {
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: hardwareEventMask(),
            callback: eventTapCallback,
            userInfo: userInfo
        ) else {
            NSLog("The event tap failed. Accessibility and Input Monitoring are required.")
            return
        }
        self.eventTap = eventTap
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0) else {
            return
        }
        eventTapSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    fileprivate func enableEventTap() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: true)
        }
    }

    fileprivate func receive(
        event: HardwareEvent,
        keyboardCommand: KeyboardCommand?,
        unixProcessID: Int
    ) -> Bool {
        if let keyboardCommand {
            let commandDecision = session.receiveLockScreenCommand(
                keyCode: keyboardCommand.keyCode,
                control: keyboardCommand.control,
                command: keyboardCommand.command,
                option: keyboardCommand.option,
                shift: keyboardCommand.shift,
                unixProcessID: unixProcessID
            )
            if commandDecision.swallow {
                showMode()
                return true
            }
        }
        let decision = session.receive(eventKind: eventKind(for: event), unixProcessID: unixProcessID)
        showMode()
        return decision.swallow
    }
}

private func hardwareEventMask() -> CGEventMask {
    var mask: CGEventMask = 0
    for event in HardwareEvent.allCases {
        let type = cgEventType(for: event)
        mask |= CGEventMask(1) << CGEventMask(type.rawValue)
    }
    return mask
}

private func cgEventType(for event: HardwareEvent) -> CGEventType {
    switch event {
    case .keyDown:
        return .keyDown
    case .keyUp:
        return .keyUp
    case .flagsChanged:
        return .flagsChanged
    case .mouseMoved:
        return .mouseMoved
    case .leftMouseDown:
        return .leftMouseDown
    case .leftMouseUp:
        return .leftMouseUp
    case .leftMouseDragged:
        return .leftMouseDragged
    case .rightMouseDown:
        return .rightMouseDown
    case .rightMouseUp:
        return .rightMouseUp
    case .rightMouseDragged:
        return .rightMouseDragged
    case .otherMouseDown:
        return .otherMouseDown
    case .otherMouseUp:
        return .otherMouseUp
    case .otherMouseDragged:
        return .otherMouseDragged
    case .scrollWheel:
        return .scrollWheel
    }
}

private func hardwareEvent(for type: CGEventType) -> HardwareEvent? {
    switch type {
    case .keyDown:
        return .keyDown
    case .keyUp:
        return .keyUp
    case .flagsChanged:
        return .flagsChanged
    case .mouseMoved:
        return .mouseMoved
    case .leftMouseDown:
        return .leftMouseDown
    case .leftMouseUp:
        return .leftMouseUp
    case .leftMouseDragged:
        return .leftMouseDragged
    case .rightMouseDown:
        return .rightMouseDown
    case .rightMouseUp:
        return .rightMouseUp
    case .rightMouseDragged:
        return .rightMouseDragged
    case .otherMouseDown:
        return .otherMouseDown
    case .otherMouseUp:
        return .otherMouseUp
    case .otherMouseDragged:
        return .otherMouseDragged
    case .scrollWheel:
        return .scrollWheel
    case .null, .tabletPointer, .tabletProximity, .tapDisabledByTimeout, .tapDisabledByUserInput:
        return nil
    @unknown default:
        return nil
    }
}

private struct KeyboardCommand: Sendable {
    let keyCode: Int64
    let control: Bool
    let command: Bool
    let option: Bool
    let shift: Bool
}

private func keyboardCommand(for type: CGEventType, cgEvent: CGEvent) -> KeyboardCommand? {
    switch type {
    case .keyDown, .keyUp:
        let flags = cgEvent.flags
        return KeyboardCommand(
            keyCode: cgEvent.getIntegerValueField(.keyboardEventKeycode),
            control: flags.contains(.maskControl),
            command: flags.contains(.maskCommand),
            option: flags.contains(.maskAlternate),
            shift: flags.contains(.maskShift)
        )
    case .flagsChanged, .mouseMoved, .leftMouseDown, .leftMouseUp, .leftMouseDragged, .rightMouseDown,
        .rightMouseUp, .rightMouseDragged, .otherMouseDown, .otherMouseUp, .otherMouseDragged, .scrollWheel, .null,
        .tabletPointer, .tabletProximity, .tapDisabledByTimeout, .tapDisabledByUserInput:
        return nil
    @unknown default:
        return nil
    }
}

private func eventTapCallback(
    _ proxy: CGEventTapProxy,
    _ type: CGEventType,
    _ event: CGEvent,
    _ userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }
    let bits = Int(bitPattern: userInfo)
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        MainActor.assumeIsolated {
            controller(at: bits)?.enableEventTap()
        }
        return Unmanaged.passUnretained(event)
    }
    guard let inputEvent = hardwareEvent(for: type) else {
        return Unmanaged.passUnretained(event)
    }
    let unixProcessID = Int(event.getIntegerValueField(.eventSourceUnixProcessID))
    let keyboardCommand = keyboardCommand(for: type, cgEvent: event)
    let swallow = MainActor.assumeIsolated { () -> Bool in
        controller(at: bits)?.receive(
            event: inputEvent,
            keyboardCommand: keyboardCommand,
            unixProcessID: unixProcessID
        ) ?? false
    }
    if swallow {
        return nil
    }
    return Unmanaged.passUnretained(event)
}

@MainActor
private func controller(at bits: Int) -> AppController? {
    guard let pointer = UnsafeMutableRawPointer(bitPattern: bits) else {
        return nil
    }
    return Unmanaged<AppController>.fromOpaque(pointer).takeUnretainedValue()
}
