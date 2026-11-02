import Foundation

public enum UpdateCheckAction: Equatable {
    case openInBrowser(URL)
}

public func updateCheckAction() -> UpdateCheckAction {
    guard let releasePage = URL(string: "https://github.com/Jawad0501/deskwarden/releases") else {
        preconditionFailure("The release page is not a URL.")
    }
    return .openInBrowser(releasePage)
}
