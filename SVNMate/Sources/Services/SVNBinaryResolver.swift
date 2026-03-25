import Foundation

final class SVNBinaryResolver {
    private let fileManager: FileManager
    private let processInfo: ProcessInfo
    private let settingsStore: SettingsStore

    init(
        fileManager: FileManager = .default,
        processInfo: ProcessInfo = .processInfo,
        settingsStore: SettingsStore = SettingsStore()
    ) {
        self.fileManager = fileManager
        self.processInfo = processInfo
        self.settingsStore = settingsStore
    }

    func resolve() throws -> URL {
        let localizer = AppLocalizer.current(settingsStore: settingsStore)
        if let environmentOverride = normalizedOverride(processInfo.environment["SVN_BINARY_PATH"]) {
            return try resolveConfiguredPath(environmentOverride, source: "SVN_BINARY_PATH", localizer: localizer)
        }

        if let settingsOverride = normalizedOverride(settingsStore.load().svnBinaryPathOverride) {
            return try resolveConfiguredPath(settingsOverride, source: "Settings", localizer: localizer)
        }

        for candidate in autoDetectPaths() {
            let expanded = (candidate as NSString).expandingTildeInPath
            if fileManager.isExecutableFile(atPath: expanded) {
                return URL(fileURLWithPath: expanded)
            }
        }

        throw SVNError(
            message: localizer.string("error.svn.binary_not_found"),
            output: localizer.string("error.svn.checked_paths")
        )
    }

    private func autoDetectPaths() -> [String] {
        let paths = [
            "/usr/bin/svn",
            "/opt/homebrew/bin/svn",
            "/usr/local/bin/svn"
        ]

        var uniquePaths: [String] = []
        for path in paths where !uniquePaths.contains(path) {
            uniquePaths.append(path)
        }

        return uniquePaths
    }

    private func normalizedOverride(_ path: String?) -> String? {
        guard let path = path?.trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty else {
            return nil
        }

        return path
    }

    private func resolveConfiguredPath(_ path: String, source: String, localizer: AppLocalizer) throws -> URL {
        let expandedPath = (path as NSString).expandingTildeInPath
        var isDirectory = ObjCBool(false)

        guard fileManager.fileExists(atPath: expandedPath, isDirectory: &isDirectory) else {
            throw SVNError(
                message: localizer.string("error.svn.binary_invalid"),
                output: localizer.string("error.svn.path_missing", source, expandedPath)
            )
        }

        guard !isDirectory.boolValue else {
            throw SVNError(
                message: localizer.string("error.svn.binary_invalid"),
                output: localizer.string("error.svn.path_directory", source, expandedPath)
            )
        }

        guard fileManager.isExecutableFile(atPath: expandedPath) else {
            throw SVNError(
                message: localizer.string("error.svn.binary_invalid"),
                output: localizer.string("error.svn.path_not_executable", source, expandedPath)
            )
        }

        return URL(fileURLWithPath: expandedPath)
    }
}
