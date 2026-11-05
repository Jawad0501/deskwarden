import AppKit
import XCTest
@testable import DeskwardenApp

@MainActor
final class ProtectiveBlurAppearanceTests: XCTestCase {
    func testProtectiveBlurContentViewIsAVisualEffectBehindTheWindowWithNoSubview() throws {
        NSApplication.shared.setActivationPolicy(.accessory)
        let overlay = CoverOverlay()
        overlay.showProtectiveBlur()
        defer {
            overlay.hideProtectiveBlur()
        }

        let windows = visibleBlurWindows()
        XCTAssertFalse(windows.isEmpty)
        for window in windows {
            let effect = try XCTUnwrap(window.contentView as? NSVisualEffectView)
            XCTAssertEqual(effect.blendingMode, .behindWindow)
            XCTAssertTrue(effect.subviews.isEmpty)
        }
        withExtendedLifetime(overlay) {}
    }
}

@MainActor
private func visibleBlurWindows() -> [NSWindow] {
    NSApp.windows.filter { window in
        window.isVisible && window.ignoresMouseEvents && window.contentView != nil
    }
}
