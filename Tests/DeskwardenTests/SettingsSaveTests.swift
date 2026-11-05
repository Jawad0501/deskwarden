import AppKit
import XCTest
@testable import DeskwardenApp

@MainActor
final class SettingsSaveTests: XCTestCase {
    func testSaveClickStoresProtectiveBlurAndClosesTheWindow() throws {
        let suiteName = "deskwarden.tests.settings-save"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        NSApplication.shared.setActivationPolicy(.accessory)
        let choices = StoredChoices(defaults: defaults)
        let settings = SettingsWindow(choices: choices, onSave: {})
        settings.show()

        let settingsWindow = try XCTUnwrap(
            NSApp.windows.first { $0.title == "Settings" && $0.isVisible }
        )
        let content = try XCTUnwrap(settingsWindow.contentView)
        let saveButton = try XCTUnwrap(button(titled: "Save", in: content))
        let blurCheckbox = try XCTUnwrap(
            button(titled: "Use protective screen blur", in: content)
        )
        blurCheckbox.state = .on
        saveButton.performClick(nil)

        XCTAssertTrue(choices.protectiveBlurEnabled)
        XCTAssertFalse(settingsWindow.isVisible)
        withExtendedLifetime(settings) {}
    }
}

@MainActor
private func button(titled title: String, in view: NSView) -> NSButton? {
    if let button = view as? NSButton, button.title == title {
        return button
    }
    for subview in view.subviews {
        if let match = button(titled: title, in: subview) {
            return match
        }
    }
    return nil
}
