import SwiftUI

@main
struct SVNMateApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var settingsController = SettingsController.shared
    @StateObject private var localizationController = LocalizationController.shared
    @StateObject private var menuBarController = MenuBarController()
    
    var body: some Scene {
        Window("app.name", id: AppSceneID.main) {
            ContentView()
                .environmentObject(appState)
                .environmentObject(settingsController)
                .environmentObject(localizationController)
                .environmentObject(menuBarController)
                .environment(\.appTheme, settingsController.appTheme)
                .environment(\.locale, localizationController.locale)
                .environment(\.appLocalizer, localizationController.localizer)
                .tint(settingsController.appTheme.accentColor)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("menu.new_checkout") {
                    appState.showCheckoutSheet = true
                }
                .keyboardShortcut("n", modifiers: .command)
                
                Button("menu.open_repository") {
                    appState.openRepository()
                }
                .keyboardShortcut("o", modifiers: .command)
            }
            
            CommandGroup(after: .sidebar) {
                Button("common.refresh") {
                    appState.refresh()
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(settingsController)
                .environmentObject(localizationController)
                .environment(\.appTheme, settingsController.appTheme)
                .environment(\.locale, localizationController.locale)
                .environment(\.appLocalizer, localizationController.localizer)
                .tint(settingsController.appTheme.accentColor)
        }

        MenuBarExtra {
            MenuBarExtraView()
                .environmentObject(appState)
                .environmentObject(localizationController)
                .environmentObject(menuBarController)
                .environment(\.locale, localizationController.locale)
                .environment(\.appLocalizer, localizationController.localizer)
        } label: {
            Image(systemName: menuBarIconSystemName)
        }
        .menuBarExtraStyle(.menu)
    }

    private var menuBarIconSystemName: String {
        if menuBarController.isRefreshing {
            return "arrow.triangle.2.circlepath"
        }

        if let summary = menuBarController.summary, summary.issueCount > 0 {
            return "exclamationmark.triangle.fill"
        }

        if menuBarController.errorMessage != nil {
            return "exclamationmark.triangle"
        }

        if appState.selectedRepository != nil {
            return "shippingbox.fill"
        }

        return "shippingbox"
    }
}
