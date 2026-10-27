import IOKit.pwr_mgt
import Deskwarden

final class PowerHold: DeskPower {
    private(set) var heldNames: [String] = []
    private var keptAssertionIDs: [IOPMAssertionID] = []

    func hold(_ name: String) {
        var assertionID = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(
            name as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Deskwarden agents running" as CFString,
            &assertionID
        )
        if result == kIOReturnSuccess {
            keptAssertionIDs.append(assertionID)
        }
        heldNames.append(name)
    }
}
