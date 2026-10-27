import Deskwarden

final class ArmClock: DeskClock {
    private var armedAt: ContinuousClock.Instant?

    func start() {
        armedAt = ContinuousClock.now
    }

    func secondsSinceArm() -> Int {
        guard let armedAt else {
            return 0
        }
        let elapsed = ContinuousClock.now - armedAt
        return Int(elapsed.components.seconds)
    }
}
