import AppKit
import Deskwarden

@MainActor
final class SettingsWindow: NSObject {
    private let choices: StoredChoices
    private let onSave: () -> Void
    private let window: NSWindow
    private let alarmCheckbox: NSButton
    private let photoCheckbox: NSButton
    private let titleField: NSTextField
    private let detailField: NSTextField

    init(choices: StoredChoices, onSave: @escaping () -> Void) {
        self.choices = choices
        self.onSave = onSave
        alarmCheckbox = NSButton(checkboxWithTitle: "Play the alarm", target: nil, action: nil)
        photoCheckbox = NSButton(checkboxWithTitle: "Take a photo", target: nil, action: nil)
        titleField = NSTextField(string: "")
        detailField = NSTextField(string: "")
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 260),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        super.init()
        titleField.placeholderString = StandardChoices.defaultCoverTitle
        detailField.placeholderString = StandardChoices.defaultCoverDetail
        window.title = "Settings"
        window.isReleasedWhenClosed = false
        installContent()
    }

    func show() {
        alarmCheckbox.state = choices.soundEnabled ? .on : .off
        photoCheckbox.state = choices.photoEnabled ? .on : .off
        titleField.stringValue = choices.coverTitle
        detailField.stringValue = choices.coverDetail
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
        stack.addArrangedSubview(alarmCheckbox)
        stack.addArrangedSubview(photoCheckbox)
        stack.addArrangedSubview(label("First line"))
        stack.addArrangedSubview(titleField)
        stack.addArrangedSubview(label("Second line"))
        stack.addArrangedSubview(detailField)
        let save = NSButton(title: "Save", target: self, action: #selector(save(_:)))
        save.bezelStyle = .rounded
        save.keyEquivalent = "\r"
        stack.addArrangedSubview(save)
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            titleField.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
            detailField.trailingAnchor.constraint(equalTo: stack.trailingAnchor)
        ])
    }

    private func label(_ text: String) -> NSTextField {
        NSTextField(labelWithString: text)
    }

    @objc private func save(_ sender: Any?) {
        choices.soundEnabled = alarmCheckbox.state == .on
        choices.photoEnabled = photoCheckbox.state == .on
        choices.coverTitle = titleField.stringValue
        choices.coverDetail = detailField.stringValue
        onSave()
    }
}
