import Foundation

final class SVNBinaryResolver {
    private let fileManager: FileManager
    private let processInfo: ProcessInfo
    private let userDefaults: UserDefaults

    init(
        fileManager: FileManager = .default,
        processInfo: ProcessInfo = .processInfo,
        userDefaults: UserDefaults = .standard
    ) {
        self.fileManager = fileManager
        self.processInfo = processInfo
        self.userDefaults = userDefaults
    }

    func resolve() throws -> URL {
        for candidate in candidates() {
            let expanded = (candidate as NSString).expandingTildeInPath
            if fileManager.isExecutableFile(atPath: expanded) {
                return URL(fileURLWithPath: expanded)
            }
        }

        throw SVNError(
            message: "Unable to find the svn executable.",
            output: "Checked SVN_BINARY_PATH, SVNMate.svnBinaryPath, /usr/bin/svn, /opt/homebrew/bin/svn, and /usr/local/bin/svn."
        )
    }

    private func candidates() -> [String] {
        var paths: [String] = []

        if let override = processInfo.environment["SVN_BINARY_PATH"], !override.isEmpty {
            paths.append(override)
        }

        if let storedPath = userDefaults.string(forKey: "SVNMate.svnBinaryPath"), !storedPath.isEmpty {
            paths.append(storedPath)
        }

        paths.append(contentsOf: [
            "/usr/bin/svn",
            "/opt/homebrew/bin/svn",
            "/usr/local/bin/svn"
        ])

        var uniquePaths: [String] = []
        for path in paths where !uniquePaths.contains(path) {
            uniquePaths.append(path)
        }

        return uniquePaths
    }
}
