import SwiftUI
import Foundation

struct MenuBarRepositorySummary {
    let repositoryName: String
    let repositoryPath: String
    let issueCount: Int
}

@MainActor
final class MenuBarController: ObservableObject {
    @Published private(set) var summary: MenuBarRepositorySummary?
    @Published private(set) var isRefreshing = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var selectedRepositoryPath: String?

    private let svnService = SVNService()
    private var refreshTask: Task<Void, Never>?

    var iconSystemName: String {
        if isRefreshing {
            return "arrow.triangle.2.circlepath"
        }

        if let summary, summary.issueCount > 0 {
            return "exclamationmark.triangle.fill"
        }

        if errorMessage != nil {
            return "exclamationmark.triangle"
        }

        if selectedRepositoryPath != nil {
            return "shippingbox.fill"
        }

        return "shippingbox"
    }

    func refresh(for repository: Repository?) {
        refreshTask?.cancel()
        selectedRepositoryPath = repository?.path
        errorMessage = nil

        guard let repository else {
            summary = nil
            isRefreshing = false
            return
        }

        isRefreshing = true
        let requestedPath = repository.path
        let requestedName = repository.name

        refreshTask = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                let snapshot = try await svnService.workingCopySnapshot(at: requestedPath)

                guard !Task.isCancelled else {
                    return
                }

                await MainActor.run {
                    guard self.selectedRepositoryPath == requestedPath else {
                        return
                    }

                    self.summary = MenuBarRepositorySummary(
                        repositoryName: requestedName,
                        repositoryPath: requestedPath,
                        issueCount: snapshot.issues.count
                    )
                    self.errorMessage = nil
                    self.isRefreshing = false
                    self.refreshTask = nil
                }
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                await MainActor.run {
                    guard self.selectedRepositoryPath == requestedPath else {
                        return
                    }

                    self.summary = nil
                    self.errorMessage = error.localizedDescription
                    self.isRefreshing = false
                    self.refreshTask = nil
                }
            }
        }
    }
}
