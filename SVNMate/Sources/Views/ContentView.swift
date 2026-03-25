import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var menuBarController: MenuBarController
    
    var body: some View {
        NavigationSplitView {
            SidebarView()
                .frame(minWidth: 250)
        } detail: {
            if let repo = appState.selectedRepository {
                RepositoryDetailView(repository: repo)
            } else {
                WelcomeView()
            }
        }
        .sheet(isPresented: $appState.showCheckoutSheet) {
            CheckoutSheet()
        }
        .alert("alert.error.title", isPresented: .init(
            get: { appState.errorMessage != nil },
            set: { if !$0 { appState.clearMessages() } }
        )) {
            Button("common.ok") { appState.clearMessages() }
        } message: {
            Text(appState.errorMessage ?? "")
        }
        .overlay {
            if let success = appState.successMessage {
                ToastView(message: success, type: .success)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: appState.successMessage)
        .onAppear {
            menuBarController.refresh(for: appState.selectedRepository)
        }
        .onChange(of: appState.selectedRepository?.path) { _ in
            menuBarController.refresh(for: appState.selectedRepository)
        }
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("sidebar.repositories")
                    .font(.headline)
                Spacer()
                Menu {
                    Button("menu.new_checkout") {
                        appState.showCheckoutSheet = true
                    }
                    Button("menu.open_repository") {
                        appState.openRepository()
                    }
                    Button {
                        openSettingsWindow()
                    } label: {
                        Label("menu.settings", systemImage: "gearshape")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                }
                .menuStyle(.borderlessButton)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
            
            // Repository List
            if appState.repositories.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("sidebar.no_repositories")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button("sidebar.add_repository") {
                        appState.openRepository()
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $appState.selectedRepository) {
                    ForEach(appState.repositories) { repo in
                        RepositoryRow(repository: repo)
                            .tag(repo)
                            .contextMenu {
                                Button("common.remove") {
                                    appState.removeRepository(repo)
                                }
                            }
                    }
                }
                .listStyle(.sidebar)
            }
        }
    }
}

struct RepositoryRow: View {
    let repository: Repository
    @Environment(\.appTheme) private var appTheme
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "folder.fill")
                .foregroundColor(appTheme.accentColor)
                .font(.system(size: 16))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(repository.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                
                Text(repository.path)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Welcome View

struct WelcomeView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.appTheme) private var appTheme
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "shippingbox")
                .font(.system(size: 64))
                .foregroundColor(appTheme.accentColor)
            
            Text("welcome.title")
                .font(.largeTitle)
                .fontWeight(.semibold)
            
            Text("welcome.subtitle")
                .font(.title3)
                .foregroundColor(.secondary)
            
            HStack(spacing: 16) {
                Button {
                    appState.showCheckoutSheet = true
                } label: {
                    Label("welcome.new_checkout", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.borderedProminent)
                
                Button {
                    appState.openRepository()
                } label: {
                    Label("welcome.open_repository", systemImage: "folder")
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
