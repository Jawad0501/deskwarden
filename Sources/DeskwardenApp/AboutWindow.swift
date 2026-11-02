import AppKit
import Deskwarden

@MainActor
final class AboutWindow: NSObject {
    private let window: NSWindow

    override init() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 280),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        super.init()
        window.title = "About"
        window.isReleasedWhenClosed = false
        installContent()
    }

    func show() {
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    private func installContent() {
        guard let content = window.contentView else {
            return
        }
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(label("Deskwarden"))
        stack.addArrangedSubview(label(versionLine()))
        stack.addArrangedSubview(label("Deskwarden keeps a Mac awake."))
        stack.addArrangedSubview(label("An armed desk covers every display after a physical touch."))
        stack.addArrangedSubview(label("Copyright 2026 Jawad0501."))
        stack.addArrangedSubview(label("The license is MIT."))
        let check = NSButton(title: "Check for Updates", target: self, action: #selector(checkForUpdates(_:)))
        check.bezelStyle = .rounded
        stack.addArrangedSubview(check)
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20)
        ])
    }

    private func label(_ text: String) -> NSTextField {
        NSTextField(labelWithString: text)
    }

    private func versionLine() -> String {
        guard let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else {
            return "Version unknown"
        }
        return "Version \(version)"
    }

    @objc private func checkForUpdates(_ sender: Any?) {
        switch updateCheckAction() {
        case .openInBrowser(let url):
            NSWorkspace.shared.open(url)
        }
    }
}
