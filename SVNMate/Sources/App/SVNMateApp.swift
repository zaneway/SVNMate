import SwiftUI

@main
struct SVNMateApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Checkout...") {
                    appState.showCheckoutSheet = true
                }
                .keyboardShortcut("n", modifiers: .command)
                
                Button("Open Repository...") {
                    appState.openRepository()
                }
                .keyboardShortcut("o", modifiers: .command)
            }
            
            CommandGroup(after: .sidebar) {
                Button("Refresh") {
                    appState.refresh()
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}
