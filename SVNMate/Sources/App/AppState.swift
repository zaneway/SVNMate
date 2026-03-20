import SwiftUI
import AppKit

// MARK: - App State

@MainActor
final class AppState: ObservableObject {
    private enum UIConstants {
        static let successMessageDurationNanoseconds: UInt64 = 2_500_000_000
    }

    @Published var repositories: [Repository] = []
    @Published var selectedRepository: Repository?
    @Published var showCheckoutSheet = false
    @Published var showOpenPanel = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    private let repositoryStore = RepositoryStore()
    private let svnService = SVNService()
    private var successMessageTask: Task<Void, Never>?
    
    init() {
        repositories = repositoryStore.loadRepositories()
    }
    
    func openRepository() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a SVN repository folder"
        panel.prompt = "Open"
        
        if panel.runModal() == .OK, let url = panel.url {
            addRepository(at: url.path)
        }
    }
    
    func addRepository(at path: String) {
        isLoading = true
        
        Task {
            do {
                let info = try await svnService.info(at: path)
                let repo = Repository(
                    path: path,
                    url: info.url,
                    name: URL(string: info.url)?.lastPathComponent ?? "Unknown"
                )

                if let existingIndex = repositories.firstIndex(where: { $0.path == path }) {
                    repositories[existingIndex] = repo
                } else {
                    repositories.append(repo)
                }

                repositoryStore.saveRepositories(repositories)
                selectedRepository = repo
                isLoading = false
                showSuccessMessage("Repository added successfully")
            } catch {
                errorMessage = "Failed to add repository: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    func removeRepository(_ repo: Repository) {
        repositories.removeAll { $0.id == repo.id }
        repositoryStore.saveRepositories(repositories)
        if selectedRepository?.id == repo.id {
            selectedRepository = nil
        }
    }
    
    func refresh() {
        if let repo = selectedRepository {
            selectedRepository = repo
        }
    }
    
    func clearMessages() {
        successMessageTask?.cancel()
        errorMessage = nil
        successMessage = nil
    }

    private func showSuccessMessage(_ message: String) {
        successMessageTask?.cancel()
        successMessage = message

        successMessageTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UIConstants.successMessageDurationNanoseconds)

            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                guard self?.successMessage == message else {
                    return
                }

                withAnimation(.easeInOut(duration: 0.2)) {
                    self?.successMessage = nil
                }
            }
        }
    }
}
