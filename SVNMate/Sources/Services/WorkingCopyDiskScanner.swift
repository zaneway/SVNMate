import Foundation

struct WorkingCopyDiskEntry {
    let path: String
    let name: String
    let isDirectory: Bool
}

final class WorkingCopyDiskScanner {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func scanDirectory(at repositoryPath: String, relativePath: String? = nil) throws -> [WorkingCopyDiskEntry] {
        let directoryPath = absolutePath(for: relativePath, repositoryPath: repositoryPath)
        let directoryURL = URL(fileURLWithPath: directoryPath)
        let contents = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        )

        return try contents
            .filter { $0.lastPathComponent != ".svn" }
            .map { url in
                let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
                let isDirectory = resourceValues.isDirectory ?? false
                let nodeRelativePath = makeRelativePath(
                    entryName: url.lastPathComponent,
                    parentRelativePath: relativePath
                )

                return WorkingCopyDiskEntry(
                    path: nodeRelativePath,
                    name: url.lastPathComponent,
                    isDirectory: isDirectory
                )
            }
            .sorted(by: sortEntries)
    }

    private func absolutePath(for relativePath: String?, repositoryPath: String) -> String {
        guard let relativePath, !relativePath.isEmpty else {
            return repositoryPath
        }

        return (repositoryPath as NSString).appendingPathComponent(relativePath)
    }

    private func makeRelativePath(entryName: String, parentRelativePath: String?) -> String {
        guard let parentRelativePath, !parentRelativePath.isEmpty else {
            return entryName
        }

        return (parentRelativePath as NSString).appendingPathComponent(entryName)
    }

    private func sortEntries(_ lhs: WorkingCopyDiskEntry, _ rhs: WorkingCopyDiskEntry) -> Bool {
        if lhs.isDirectory != rhs.isDirectory {
            return lhs.isDirectory && !rhs.isDirectory
        }

        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}
