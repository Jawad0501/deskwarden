import Foundation
import LocalAuthentication
import Deskwarden

final class OwnerAuthenticator: DeskAuthenticator {
    private let overlay: CoverOverlay
    var onSessionChange: (@MainActor () -> Void)?
    private(set) var requestedPolicyName: String?

    init(overlay: CoverOverlay) {
        self.overlay = overlay
    }

    func authenticate(policyName: String, complete: @escaping (Bool) -> Void) {
        requestedPolicyName = policyName
        overlay.lowerForAuthentication()
        let context = LAContext()
        let box = CompletionBox(complete)
        let overlay = self.overlay
        let onSessionChange = self.onSessionChange
        context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: "Unlock your Mac"
        ) { success, _ in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    if !success {
                        overlay.restoreScreenSaverLevel()
                    }
                    box.call(success)
                    onSessionChange?()
                }
            }
        }
    }
}

private final class CompletionBox: @unchecked Sendable {
    private let complete: (Bool) -> Void

    init(_ complete: @escaping (Bool) -> Void) {
        self.complete = complete
    }

    func call(_ success: Bool) {
        complete(success)
    }
}
