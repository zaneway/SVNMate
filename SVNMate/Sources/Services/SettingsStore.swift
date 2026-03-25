import Foundation

final class SettingsStore {
    private enum Keys {
        static let settings = "SVNMate.appSettings"
        static let legacySVNBinaryPath = "SVNMate.svnBinaryPath"
    }

    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func load() -> AppSettings {
        if let data = userDefaults.data(forKey: Keys.settings),
           let settings = try? decoder.decode(AppSettings.self, from: data) {
            return settings
        }

        var settings = AppSettings.defaultValue
        if let legacyPath = userDefaults.string(forKey: Keys.legacySVNBinaryPath)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !legacyPath.isEmpty {
            settings.svnBinaryPathOverride = legacyPath
        }

        return settings
    }

    func save(_ settings: AppSettings) {
        guard let data = try? encoder.encode(settings) else {
            return
        }

        userDefaults.set(data, forKey: Keys.settings)
        userDefaults.removeObject(forKey: Keys.legacySVNBinaryPath)
    }

    func restoreDefaults() -> AppSettings {
        let settings = AppSettings.defaultValue
        save(settings)
        return settings
    }
}
