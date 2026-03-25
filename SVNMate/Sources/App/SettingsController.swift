import SwiftUI
import Foundation

enum SettingsValidationError: LocalizedError {
    case invalidSVNBinaryPath(String)

    var errorDescription: String? {
        switch self {
        case .invalidSVNBinaryPath(let message):
            return message
        }
    }
}

enum EffectiveSVNBinaryPathState {
    case resolved(String)
    case unresolved(String)
}

@MainActor
final class SettingsController: ObservableObject {
    static let shared = SettingsController()

    @Published private(set) var settings: AppSettings

    private let store: SettingsStore
    private let fileManager: FileManager

    init(
        store: SettingsStore = SettingsStore(),
        fileManager: FileManager = .default
    ) {
        self.store = store
        self.fileManager = fileManager
        self.settings = store.load()
    }

    var appTheme: AppTheme {
        settings.theme.appTheme
    }

    func timeoutValue(for key: AppTimeoutKey) -> Int {
        settings.timeouts.value(for: key)
    }

    func updateTimeout(_ value: Int, for key: AppTimeoutKey) {
        let clampedValue = min(max(value, key.range.lowerBound), key.range.upperBound)
        var updatedSettings = settings
        updatedSettings.timeouts.setValue(clampedValue, for: key)
        persist(updatedSettings)
    }

    func statusColorToken(for status: FileStatus) -> AppColorToken {
        settings.theme.statusColors.token(for: status)
    }

    func updateStatusColor(_ token: AppColorToken, for status: FileStatus) {
        var updatedSettings = settings
        updatedSettings.theme.statusColors.setToken(token, for: status)
        persist(updatedSettings)
    }

    func updateAccentColor(_ token: AppColorToken) {
        var updatedSettings = settings
        updatedSettings.theme.accentColor = token
        persist(updatedSettings)
    }

    func updatePreferredLanguage(_ language: AppLanguage) {
        var updatedSettings = settings
        updatedSettings.preferredLanguage = language
        persist(updatedSettings)
    }

    func updateSVNBinaryPathOverride(_ path: String?) throws {
        let trimmedPath = path?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmedPath.isEmpty {
            resetSVNBinaryPathOverride()
            return
        }

        try validateSVNBinaryPath(trimmedPath)

        var updatedSettings = settings
        updatedSettings.svnBinaryPathOverride = trimmedPath
        persist(updatedSettings)
    }

    func resetSVNBinaryPathOverride() {
        var updatedSettings = settings
        updatedSettings.svnBinaryPathOverride = nil
        persist(updatedSettings)
    }

    func restoreDefaults() {
        settings = store.restoreDefaults()
    }

    func effectiveSVNBinaryPathState() -> EffectiveSVNBinaryPathState {
        do {
            let path = try SVNBinaryResolver(settingsStore: store).resolve().path
            return .resolved(path)
        } catch {
            return .unresolved(error.localizedDescription)
        }
    }

    private func validateSVNBinaryPath(_ path: String) throws {
        let localizer = AppLocalizer.current()
        let expandedPath = (path as NSString).expandingTildeInPath
        var isDirectory = ObjCBool(false)

        guard fileManager.fileExists(atPath: expandedPath, isDirectory: &isDirectory) else {
            throw SettingsValidationError.invalidSVNBinaryPath(
                localizer.string("settings.validation.path_not_exist")
            )
        }

        guard !isDirectory.boolValue else {
            throw SettingsValidationError.invalidSVNBinaryPath(
                localizer.string("settings.validation.path_directory")
            )
        }

        guard fileManager.isExecutableFile(atPath: expandedPath) else {
            throw SettingsValidationError.invalidSVNBinaryPath(
                localizer.string("settings.validation.path_not_executable")
            )
        }
    }

    private func persist(_ updatedSettings: AppSettings) {
        settings = updatedSettings
        store.save(updatedSettings)
    }
}
