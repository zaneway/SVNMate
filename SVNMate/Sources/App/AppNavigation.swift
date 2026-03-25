import SwiftUI
import AppKit

enum AppSceneID {
    static let main = "main"
}

func openSettingsWindow() {
    NSApp.activate(ignoringOtherApps: true)
    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
}

func activateMainWindow(using openWindow: OpenWindowAction) {
    openWindow(id: AppSceneID.main)
    NSApp.activate(ignoringOtherApps: true)
}
