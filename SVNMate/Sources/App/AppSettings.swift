import SwiftUI
import AppKit

enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case system
    case zhHans = "zh-Hans"
    case en = "en"

    var id: String { rawValue }

    var localeIdentifier: String {
        switch self {
        case .system:
            return AppLocalizer.resolveLanguage(preference: .system).localeIdentifier
        case .zhHans:
            return "zh-Hans"
        case .en:
            return "en"
        }
    }

    var localizationKey: String {
        switch self {
        case .system:
            return "settings.language.system"
        case .zhHans:
            return "settings.language.zh_hans"
        case .en:
            return "settings.language.en"
        }
    }
}

enum AppColorToken: String, Codable, CaseIterable, Identifiable {
    case blue
    case green
    case orange
    case red
    case yellow
    case teal
    case indigo
    case purple
    case pink
    case brown
    case gray
    case primary
    case secondary

    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .blue: return "color.blue"
        case .green: return "color.green"
        case .orange: return "color.orange"
        case .red: return "color.red"
        case .yellow: return "color.yellow"
        case .teal: return "color.teal"
        case .indigo: return "color.indigo"
        case .purple: return "color.purple"
        case .pink: return "color.pink"
        case .brown: return "color.brown"
        case .gray: return "color.gray"
        case .primary: return "color.primary"
        case .secondary: return "color.secondary"
        }
    }

    var color: Color {
        switch self {
        case .blue:
            return Color(nsColor: .systemBlue)
        case .green:
            return Color(nsColor: .systemGreen)
        case .orange:
            return Color(nsColor: .systemOrange)
        case .red:
            return Color(nsColor: .systemRed)
        case .yellow:
            return Color(nsColor: .systemYellow)
        case .teal:
            return Color(nsColor: .systemTeal)
        case .indigo:
            return Color(nsColor: .systemIndigo)
        case .purple:
            return Color(nsColor: .systemPurple)
        case .pink:
            return Color(nsColor: .systemPink)
        case .brown:
            return Color(nsColor: .systemBrown)
        case .gray:
            return Color(nsColor: .systemGray)
        case .primary:
            return Color.primary
        case .secondary:
            return Color.secondary
        }
    }
}

enum AppTimeoutKey: String, CaseIterable, Identifiable {
    case defaultOperation
    case networkOperation
    case checkoutOperation
    case logOperation

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .defaultOperation:
            return "settings.timeout.default.title"
        case .networkOperation:
            return "settings.timeout.network.title"
        case .checkoutOperation:
            return "settings.timeout.checkout.title"
        case .logOperation:
            return "settings.timeout.log.title"
        }
    }

    var helpTextKey: String {
        switch self {
        case .defaultOperation:
            return "settings.timeout.default.help"
        case .networkOperation:
            return "settings.timeout.network.help"
        case .checkoutOperation:
            return "settings.timeout.checkout.help"
        case .logOperation:
            return "settings.timeout.log.help"
        }
    }

    var range: ClosedRange<Int> {
        switch self {
        case .defaultOperation:
            return 5...600
        case .networkOperation:
            return 30...3600
        case .checkoutOperation:
            return 60...7200
        case .logOperation:
            return 10...1800
        }
    }
}

struct OperationTimeoutSettings: Codable, Equatable {
    var defaultOperationSeconds: Int
    var networkOperationSeconds: Int
    var checkoutOperationSeconds: Int
    var logOperationSeconds: Int

    static let defaultValue = OperationTimeoutSettings(
        defaultOperationSeconds: 30,
        networkOperationSeconds: 300,
        checkoutOperationSeconds: 1_800,
        logOperationSeconds: 120
    )

    func value(for key: AppTimeoutKey) -> Int {
        switch key {
        case .defaultOperation:
            return defaultOperationSeconds
        case .networkOperation:
            return networkOperationSeconds
        case .checkoutOperation:
            return checkoutOperationSeconds
        case .logOperation:
            return logOperationSeconds
        }
    }

    mutating func setValue(_ value: Int, for key: AppTimeoutKey) {
        switch key {
        case .defaultOperation:
            defaultOperationSeconds = value
        case .networkOperation:
            networkOperationSeconds = value
        case .checkoutOperation:
            checkoutOperationSeconds = value
        case .logOperation:
            logOperationSeconds = value
        }
    }
}

struct StatusColorSettings: Codable, Equatable {
    var normal: AppColorToken
    var modified: AppColorToken
    var added: AppColorToken
    var deleted: AppColorToken
    var unversioned: AppColorToken
    var conflict: AppColorToken
    var ignored: AppColorToken
    var missing: AppColorToken
    var replaced: AppColorToken
    var external: AppColorToken

    static let defaultValue = StatusColorSettings(
        normal: .primary,
        modified: .orange,
        added: .green,
        deleted: .red,
        unversioned: .secondary,
        conflict: .red,
        ignored: .gray,
        missing: .orange,
        replaced: .purple,
        external: .teal
    )

    func token(for status: FileStatus) -> AppColorToken {
        switch status {
        case .normal:
            return normal
        case .modified:
            return modified
        case .added:
            return added
        case .deleted:
            return deleted
        case .unversioned:
            return unversioned
        case .conflict:
            return conflict
        case .ignored:
            return ignored
        case .missing:
            return missing
        case .replaced:
            return replaced
        case .external:
            return external
        }
    }

    mutating func setToken(_ token: AppColorToken, for status: FileStatus) {
        switch status {
        case .normal:
            normal = token
        case .modified:
            modified = token
        case .added:
            added = token
        case .deleted:
            deleted = token
        case .unversioned:
            unversioned = token
        case .conflict:
            conflict = token
        case .ignored:
            ignored = token
        case .missing:
            missing = token
        case .replaced:
            replaced = token
        case .external:
            external = token
        }
    }
}

struct AppThemeSettings: Codable, Equatable {
    var accentColor: AppColorToken
    var statusColors: StatusColorSettings

    static let defaultValue = AppThemeSettings(
        accentColor: .blue,
        statusColors: .defaultValue
    )

    var appTheme: AppTheme {
        AppTheme(
            accentColor: accentColor.color,
            statusColors: statusColors
        )
    }
}

struct AppSettings: Codable, Equatable {
    var svnBinaryPathOverride: String?
    var preferredLanguage: AppLanguage
    var timeouts: OperationTimeoutSettings
    var theme: AppThemeSettings

    static let defaultValue = AppSettings(
        svnBinaryPathOverride: nil,
        preferredLanguage: .system,
        timeouts: .defaultValue,
        theme: .defaultValue
    )

    private enum CodingKeys: String, CodingKey {
        case svnBinaryPathOverride
        case preferredLanguage
        case timeouts
        case theme
    }

    init(
        svnBinaryPathOverride: String?,
        preferredLanguage: AppLanguage,
        timeouts: OperationTimeoutSettings,
        theme: AppThemeSettings
    ) {
        self.svnBinaryPathOverride = svnBinaryPathOverride
        self.preferredLanguage = preferredLanguage
        self.timeouts = timeouts
        self.theme = theme
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        svnBinaryPathOverride = try container.decodeIfPresent(String.self, forKey: .svnBinaryPathOverride)
        preferredLanguage = try container.decodeIfPresent(AppLanguage.self, forKey: .preferredLanguage) ?? .system
        timeouts = try container.decodeIfPresent(OperationTimeoutSettings.self, forKey: .timeouts) ?? .defaultValue
        theme = try container.decodeIfPresent(AppThemeSettings.self, forKey: .theme) ?? .defaultValue
    }
}

struct AppTheme {
    let accentColor: Color
    let statusColors: StatusColorSettings

    func color(for status: FileStatus) -> Color {
        statusColors.token(for: status).color
    }

    var issueColor: Color {
        color(for: .missing)
    }

    var conflictColor: Color {
        color(for: .conflict)
    }
}

private struct AppThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue = AppSettings.defaultValue.theme.appTheme
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeEnvironmentKey.self] }
        set { self[AppThemeEnvironmentKey.self] = newValue }
    }
}
