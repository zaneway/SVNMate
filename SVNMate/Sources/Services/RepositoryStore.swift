import Foundation

final class RepositoryStore {
    private let userDefaultsKey = "SVNMate.repositories"

    func loadRepositories() -> [Repository] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let repositories = try? JSONDecoder().decode([Repository].self, from: data) else {
            return []
        }

        return repositories.filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    func saveRepositories(_ repositories: [Repository]) {
        guard let data = try? JSONEncoder().encode(repositories) else {
            return
        }

        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }
}
