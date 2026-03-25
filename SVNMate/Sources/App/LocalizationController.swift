import SwiftUI
import Combine
import Foundation

struct AppLocalizer {
    let language: AppLanguage
    let locale: Locale

    private let bundle: Bundle

    init(language: AppLanguage) {
        self.language = language
        self.locale = Locale(identifier: language.localeIdentifier)

        if let bundlePath = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
           let localizedBundle = Bundle(path: bundlePath) {
            self.bundle = localizedBundle
        } else {
            self.bundle = Bundle.main
        }
    }

    static func resolveLanguage(preference: AppLanguage) -> AppLanguage {
        switch preference {
        case .system:
            for preferred in Locale.preferredLanguages {
                let normalized = preferred.lowercased()
                if normalized.hasPrefix("zh") {
                    return .zhHans
                }
                if normalized.hasPrefix("en") {
                    return .en
                }
            }
            return .zhHans
        case .zhHans, .en:
            return preference
        }
    }

    static func current(settingsStore: SettingsStore = SettingsStore()) -> AppLocalizer {
        let settings = settingsStore.load()
        let resolvedLanguage = resolveLanguage(preference: settings.preferredLanguage)
        return AppLocalizer(language: resolvedLanguage)
    }

    func string(_ key: String, _ arguments: CVarArg...) -> String {
        let format = NSLocalizedString(key, tableName: nil, bundle: bundle, value: key, comment: "")
        guard !arguments.isEmpty else {
            return format
        }

        return String(format: format, locale: locale, arguments: arguments)
    }

    func uppercased(_ key: String) -> String {
        string(key).uppercased(with: locale)
    }
}

private struct AppLocalizerEnvironmentKey: EnvironmentKey {
    static let defaultValue = AppLocalizer(language: .zhHans)
}

extension EnvironmentValues {
    var appLocalizer: AppLocalizer {
        get { self[AppLocalizerEnvironmentKey.self] }
        set { self[AppLocalizerEnvironmentKey.self] = newValue }
    }
}

@MainActor
final class LocalizationController: ObservableObject {
    static let shared = LocalizationController(settingsController: .shared)

    @Published private(set) var preferredLanguage: AppLanguage
    @Published private(set) var resolvedLanguage: AppLanguage

    private let settingsController: SettingsController
    private var settingsCancellable: AnyCancellable?

    init(settingsController: SettingsController) {
        self.settingsController = settingsController
        let initialPreference = settingsController.settings.preferredLanguage
        self.preferredLanguage = initialPreference
        self.resolvedLanguage = AppLocalizer.resolveLanguage(preference: initialPreference)

        settingsCancellable = settingsController.$settings.sink { [weak self] settings in
            self?.reload(from: settings)
        }
    }

    var locale: Locale {
        Locale(identifier: resolvedLanguage.localeIdentifier)
    }

    var localizer: AppLocalizer {
        AppLocalizer(language: resolvedLanguage)
    }

    func updatePreferredLanguage(_ language: AppLanguage) {
        settingsController.updatePreferredLanguage(language)
    }

    private func reload(from settings: AppSettings) {
        preferredLanguage = settings.preferredLanguage
        resolvedLanguage = AppLocalizer.resolveLanguage(preference: settings.preferredLanguage)
    }
}
