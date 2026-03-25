import Foundation

final class SVNXMLParser {
    func parseInfo(_ output: String) throws -> SVNInfo {
        let localizer = AppLocalizer.current()
        let document = try xmlDocument(from: output)

        guard let root = document.rootElement(),
              let entry = root.elements(forName: "entry").first else {
            throw SVNError(message: localizer.string("error.svn.parse_info"))
        }

        let url = entry.elements(forName: "url").first?.stringValue ?? ""
        let revision = entry.attribute(forName: "revision")?.stringValue ?? ""
        let commitElement = entry.elements(forName: "commit").first
        let lastCommitRev = commitElement?.attribute(forName: "revision")?.stringValue ?? ""
        let lastCommitAuthor = commitElement?.elements(forName: "author").first?.stringValue
        let lastCommitDate = parseDate(commitElement?.elements(forName: "date").first?.stringValue)

        return SVNInfo(
            url: url,
            revision: revision,
            lastCommitRev: lastCommitRev,
            lastCommitAuthor: lastCommitAuthor,
            lastCommitDate: lastCommitDate
        )
    }

    func parseTreeConflictDetail(_ output: String) throws -> SVNTreeConflictDetail? {
        let document = try xmlDocument(from: output)

        guard let root = document.rootElement(),
              let entry = root.elements(forName: "entry").first,
              let treeConflict = entry.elements(forName: "tree-conflict").first else {
            return nil
        }

        let versions = treeConflict.elements(forName: "version")

        return SVNTreeConflictDetail(
            kind: treeConflict.attribute(forName: "kind")?.stringValue ?? "",
            reason: treeConflict.attribute(forName: "reason")?.stringValue ?? "",
            action: treeConflict.attribute(forName: "action")?.stringValue ?? "",
            operation: treeConflict.attribute(forName: "operation")?.stringValue ?? "",
            victim: treeConflict.attribute(forName: "victim")?.stringValue ?? "",
            sourceLeft: parseTreeConflictVersion(
                versions.first(where: { $0.attribute(forName: "side")?.stringValue == "source-left" })
            ),
            sourceRight: parseTreeConflictVersion(
                versions.first(where: { $0.attribute(forName: "side")?.stringValue == "source-right" })
            )
        )
    }

    func parseStatus(_ output: String, basePath: String) throws -> WorkingCopyStatusIndex {
        let localizer = AppLocalizer.current()
        let document = try xmlDocument(from: output)
        guard let root = document.rootElement() else {
            throw SVNError(message: localizer.string("error.svn.parse_status"))
        }

        var explicitStatuses: [String: FileStatus] = [:]
        var directoryStatuses: [String: FileStatus] = [:]
        var issues: [WorkingCopyIssue] = []
        var seenIssues: Set<String> = []

        for target in root.elements(forName: "target") {
            for entry in target.elements(forName: "entry") {
                guard let rawPath = entry.attribute(forName: "path")?.stringValue else {
                    continue
                }

                let relativePath = normalize(path: rawPath, basePath: basePath)
                guard !relativePath.isEmpty else {
                    continue
                }

                let statusElement = entry.elements(forName: "wc-status").first
                let isTreeConflicted = statusElement?.attribute(forName: "tree-conflicted")?.stringValue == "true"
                let status = isTreeConflicted
                    ? FileStatus.conflict
                    : FileStatus(svnItem: statusElement?.attribute(forName: "item")?.stringValue ?? "normal")
                explicitStatuses[relativePath] = status

                let fullPath = (basePath as NSString).appendingPathComponent(relativePath)
                var isDirectory = ObjCBool(false)
                let existsOnDisk = FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDirectory)

                if existsOnDisk && isDirectory.boolValue {
                    merge(status: status, into: &directoryStatuses, for: relativePath)
                }

                for parentPath in parentPaths(for: relativePath) {
                    merge(status: status, into: &directoryStatuses, for: parentPath)
                }

                if !existsOnDisk {
                    let issue = WorkingCopyIssue(
                        path: relativePath,
                        status: status,
                        existsOnDisk: false
                    )
                    let issueKey = issue.id

                    if !seenIssues.contains(issueKey) {
                        seenIssues.insert(issueKey)
                        issues.append(issue)
                    }
                }
            }
        }

        return WorkingCopyStatusIndex(
            explicitStatuses: explicitStatuses,
            directoryStatuses: directoryStatuses,
            issues: issues.sorted {
                $0.path.localizedCaseInsensitiveCompare($1.path) == .orderedAscending
            }
        )
    }

    private func xmlDocument(from output: String) throws -> XMLDocument {
        let localizer = AppLocalizer.current()
        guard let data = output.data(using: .utf8) else {
            throw SVNError(message: localizer.string("error.svn.utf8"))
        }

        return try XMLDocument(data: data, options: [])
    }

    private func parseDate(_ rawValue: String?) -> Date? {
        guard let rawValue, !rawValue.isEmpty else {
            return nil
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: rawValue) {
            return date
        }

        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: rawValue)
    }

    private func normalize(path: String, basePath: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ""
        }

        if trimmed == "." {
            return ""
        }

        if trimmed.hasPrefix("./") {
            return String(trimmed.dropFirst(2))
        }

        let standardizedPath = (trimmed as NSString).standardizingPath
        let standardizedBase = (basePath as NSString).standardizingPath

        if standardizedPath == standardizedBase {
            return ""
        }

        let prefix = standardizedBase + "/"
        if standardizedPath.hasPrefix(prefix) {
            return String(standardizedPath.dropFirst(prefix.count))
        }

        return trimmed
    }

    private func parentPaths(for path: String) -> [String] {
        let components = path.components(separatedBy: "/")
        guard components.count > 1 else {
            return []
        }

        var parents: [String] = []
        for index in 1..<(components.count) {
            parents.append(components.prefix(index).joined(separator: "/"))
        }

        return parents
    }

    private func merge(status: FileStatus, into dictionary: inout [String: FileStatus], for path: String) {
        guard !path.isEmpty else {
            return
        }

        if let existing = dictionary[path], priority(for: existing) >= priority(for: status) {
            return
        }

        dictionary[path] = status
    }

    private func priority(for status: FileStatus) -> Int {
        switch status {
        case .conflict:
            return 70
        case .missing:
            return 65
        case .modified, .added, .deleted, .replaced:
            return 60
        case .external:
            return 50
        case .unversioned:
            return 40
        case .ignored:
            return 30
        case .normal:
            return 10
        }
    }

    private func parseTreeConflictVersion(_ element: XMLElement?) -> SVNTreeConflictVersion? {
        guard let element else {
            return nil
        }

        return SVNTreeConflictVersion(
            side: element.attribute(forName: "side")?.stringValue ?? "",
            kind: element.attribute(forName: "kind")?.stringValue ?? "",
            pathInRepos: element.attribute(forName: "path-in-repos")?.stringValue ?? "",
            reposURL: element.attribute(forName: "repos-url")?.stringValue ?? "",
            revision: element.attribute(forName: "revision")?.stringValue ?? ""
        )
    }
}
