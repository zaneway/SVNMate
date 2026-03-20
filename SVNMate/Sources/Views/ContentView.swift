import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
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
        .alert("Error", isPresented: .init(
            get: { appState.errorMessage != nil },
            set: { if !$0 { appState.clearMessages() } }
        )) {
            Button("OK") { appState.clearMessages() }
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
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Repositories")
                    .font(.headline)
                Spacer()
                Menu {
                    Button("New Checkout...") {
                        appState.showCheckoutSheet = true
                    }
                    Button("Open Repository...") {
                        appState.openRepository()
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
                    Text("No repositories")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button("Add Repository") {
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
                                Button("Remove") {
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
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "folder.fill")
                .foregroundColor(.blue)
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
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "shippingbox")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("Welcome to SVNMate")
                .font(.largeTitle)
                .fontWeight(.semibold)
            
            Text("A native macOS SVN client")
                .font(.title3)
                .foregroundColor(.secondary)
            
            HStack(spacing: 16) {
                Button {
                    appState.showCheckoutSheet = true
                } label: {
                    Label("New Checkout", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.borderedProminent)
                
                Button {
                    appState.openRepository()
                } label: {
                    Label("Open Repository", systemImage: "folder")
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
