import AppKit
import Deskwarden

@MainActor
final class CoverOverlay: NSObject, DeskOverlay {
    private var windows: [NSWindow] = []
    private var blurWindows: [NSWindow] = []
    private var covered = false
    private var blurred = false
    var onUnlock: (@MainActor () -> Void)?

    nonisolated var isCovered: Bool {
        MainActor.assumeIsolated {
            covered
        }
    }

    nonisolated var isBlurred: Bool {
        MainActor.assumeIsolated {
            blurred
        }
    }

    nonisolated func cover(title: String, detail: String) {
        MainActor.assumeIsolated {
            removeBlur()
            showCover(title: title, detail: detail)
        }
    }

    nonisolated func uncover() {
        MainActor.assumeIsolated {
            removeBlur()
            removeCover()
        }
    }

    nonisolated func showProtectiveBlur() {
        MainActor.assumeIsolated {
            showBlur()
        }
    }

    nonisolated func hideProtectiveBlur() {
        MainActor.assumeIsolated {
            removeBlur()
        }
    }

    nonisolated func lowerForAuthentication() {
        MainActor.assumeIsolated {
            lowerWindows()
        }
    }

    nonisolated func restoreScreenSaverLevel() {
        MainActor.assumeIsolated {
            raiseWindows()
        }
    }

    private func showCover(title: String, detail: String) {
        removeWindows()
        let screens = NSScreen.screens
        for (index, screen) in screens.enumerated() {
            let window = makeWindow(on: screen, showsUnlock: index == 0, title: title, detail: detail)
            windows.append(window)
            if index == 0 {
                window.makeKeyAndOrderFront(nil)
            } else {
                window.orderFrontRegardless()
            }
        }
        NSApp.presentationOptions = [
            .hideDock,
            .hideMenuBar,
            .disableProcessSwitching,
            .disableForceQuit,
            .disableHideApplication,
            .disableSessionTermination
        ]
        covered = true
    }

    private func removeCover() {
        removeWindows()
        NSApp.presentationOptions = []
        covered = false
    }

    private func lowerWindows() {
        for window in windows {
            window.level = NSWindow.Level(rawValue: NSWindow.Level.modalPanel.rawValue - 1)
            window.isOpaque = true
            window.alphaValue = 1
            window.orderFrontRegardless()
        }
    }

    private func raiseWindows() {
        for window in windows {
            window.level = .screenSaver
            window.isOpaque = true
            window.orderFrontRegardless()
        }
    }

    private func showBlur() {
        if covered {
            return
        }
        removeBlur()
        for screen in NSScreen.screens {
            let window = makeBlurWindow(on: screen)
            blurWindows.append(window)
            window.orderFrontRegardless()
        }
        blurred = true
    }

    private func removeBlur() {
        for window in blurWindows {
            window.orderOut(nil)
            window.close()
        }
        blurWindows.removeAll()
        blurred = false
    }

    private func removeWindows() {
        for window in windows {
            window.orderOut(nil)
            window.close()
        }
        windows.removeAll()
    }

    private func makeBlurWindow(on screen: NSScreen) -> NSWindow {
        let window = BlurWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.popUpMenuWindow)))
        window.isOpaque = false
        window.hasShadow = false
        window.isMovable = false
        window.hidesOnDeactivate = false
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        window.sharingType = .none
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.setFrame(screen.frame, display: true)
        let bounds = NSRect(origin: .zero, size: screen.frame.size)
        let effect = NSVisualEffectView(frame: bounds)
        effect.autoresizingMask = [.width, .height]
        effect.blendingMode = .behindWindow
        effect.material = .hudWindow
        effect.state = .active
        effect.appearance = NSAppearance(named: .darkAqua)
        window.contentView = effect
        return window
    }

    private func makeWindow(on screen: NSScreen, showsUnlock: Bool, title: String, detail: String) -> NSWindow {
        let window = CoverWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.level = .screenSaver
        window.isOpaque = true
        window.hasShadow = false
        window.isMovable = false
        window.hidesOnDeactivate = false
        window.ignoresMouseEvents = false
        window.isReleasedWhenClosed = false
        window.backgroundColor = coverColor
        window.sharingType = .none
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.setFrame(screen.frame, display: true)
        installContent(in: window, showsUnlock: showsUnlock, title: title, detail: detail)
        return window
    }

    private func installContent(in window: NSWindow, showsUnlock: Bool, title: String, detail: String) {
        guard let content = window.contentView else {
            return
        }
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(label(title, size: 32))
        stack.addArrangedSubview(label(detail, size: 18))
        if showsUnlock {
            let button = NSButton(
                title: "I am the owner. Unlock.",
                target: self,
                action: #selector(ownerUnlock(_:))
            )
            button.bezelStyle = .rounded
            button.controlSize = .large
            stack.addArrangedSubview(button)
        }
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: content.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -24)
        ])
    }

    private func label(_ text: String, size: CGFloat) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.alignment = .center
        field.textColor = .white
        field.font = .systemFont(ofSize: size)
        field.backgroundColor = .clear
        field.drawsBackground = false
        return field
    }

    @objc private func ownerUnlock(_ sender: Any?) {
        onUnlock?()
    }
}

private let coverColor = NSColor(srgbRed: 0.05, green: 0.05, blue: 0.05, alpha: 1)

@MainActor
private final class CoverWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
private final class BlurWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
