import SwiftUI

struct MenuBarExtraView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var menuBarController: MenuBarController
    @Environment(\.appLocalizer) private var appLocalizer
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            summarySection

            Divider()

            Button("menu.show_app") {
                activateMainWindow(using: openWindow)
            }

            Button("menu.new_checkout") {
                activateMainWindow(using: openWindow)
                appState.showCheckoutSheet = true
            }

            Button("menu.open_repository") {
                activateMainWindow(using: openWindow)
                appState.openRepository()
            }

            Button("menu.refresh_summary") {
                menuBarController.refresh(for: appState.selectedRepository)
            }
            .disabled(appState.selectedRepository == nil || menuBarController.isRefreshing)

            Divider()

            Button("menu.settings") {
                openSettingsWindow()
            }

            Divider()

            Button("menu.quit") {
                NSApp.terminate(nil)
            }
        }
        .onAppear {
            menuBarController.refresh(for: appState.selectedRepository)
        }
        .onChange(of: appState.selectedRepository?.path) { _ in
            menuBarController.refresh(for: appState.selectedRepository)
        }
    }

    @ViewBuilder
    private var summarySection: some View {
        if let selectedRepository = appState.selectedRepository {
            Text(selectedRepository.name)
            Text(selectedRepository.path)
            Text(appLocalizer.string("menu.repositories_tracked", appState.repositories.count))

            if menuBarController.isRefreshing {
                Text("menu.refreshing_selected_summary")
            } else if let summary = menuBarController.summary {
                Text(appLocalizer.string("menu.selected_issue_count", summary.issueCount))
            } else if let errorMessage = menuBarController.errorMessage {
                Text(appLocalizer.string("menu.summary_error", errorMessage))
            } else {
                Text("menu.summary_unavailable")
            }
        } else {
            Text("menu.no_repository_selected")
            Text(appLocalizer.string("menu.repositories_tracked", appState.repositories.count))
            Text("menu.select_repository_hint")
        }
    }
}
