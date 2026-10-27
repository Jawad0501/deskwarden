import Foundation

public struct SetupNotice {
    public let settingsURL: URL
    public let message: String
    public let buttonTitle: String
}

public func setupNotice(accessibilityTrusted: Bool) -> SetupNotice? {
    if accessibilityTrusted {
        return nil
    }
    let address =
        "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility"
    guard let settingsURL = URL(string: address) else {
        preconditionFailure("The settings address is not a URL.")
    }
    return SetupNotice(
        settingsURL: settingsURL,
        message: "Deskwarden needs Accessibility and Input Monitoring. Open Privacy and Security and turn both on.",
        buttonTitle: "Open System Settings"
    )
}
