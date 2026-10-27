import Deskwarden
import Foundation

final class StoredChoices: DeskChoices {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var soundEnabled: Bool {
        get { storedBool(forKey: Key.soundEnabled) }
        set { defaults.set(newValue, forKey: Key.soundEnabled) }
    }

    var photoEnabled: Bool {
        get { storedBool(forKey: Key.photoEnabled) }
        set { defaults.set(newValue, forKey: Key.photoEnabled) }
    }

    var coverTitle: String {
        get { defaults.string(forKey: Key.coverTitle) ?? StandardChoices.defaultCoverTitle }
        set { defaults.set(newValue, forKey: Key.coverTitle) }
    }

    var coverDetail: String {
        get { defaults.string(forKey: Key.coverDetail) ?? StandardChoices.defaultCoverDetail }
        set { defaults.set(newValue, forKey: Key.coverDetail) }
    }

    private func storedBool(forKey key: String) -> Bool {
        guard defaults.object(forKey: key) != nil else {
            return true
        }
        return defaults.bool(forKey: key)
    }

    private enum Key {
        static let soundEnabled = "deskwarden.soundEnabled"
        static let photoEnabled = "deskwarden.photoEnabled"
        static let coverTitle = "deskwarden.coverTitle"
        static let coverDetail = "deskwarden.coverDetail"
    }
}
