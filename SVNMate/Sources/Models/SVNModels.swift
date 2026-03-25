import Foundation

struct Repository: Identifiable, Codable, Hashable {
    var path: String
    var url: String
    var name: String
    var lastUpdate: Date?

    var id: String { path }
}

struct SVNInfo {
    let url: String
    let revision: String
    let lastCommitRev: String
    let lastCommitAuthor: String?
    let lastCommitDate: Date?
}

struct SVNTreeConflictVersion: Hashable {
    let side: String
    let kind: String
    let pathInRepos: String
    let reposURL: String
    let revision: String

    var displaySideKey: String {
        switch side {
        case "source-left":
            return "tree_conflict.side.source_left"
        case "source-right":
            return "tree_conflict.side.source_right"
        default:
            return side
        }
    }

    func localizedDisplaySide(using localizer: AppLocalizer) -> String {
        if displaySideKey == side {
            return side
        }
        return localizer.string(displaySideKey)
    }
}

struct SVNTreeConflictDetail: Hashable {
    let kind: String
    let reason: String
    let action: String
    let operation: String
    let victim: String
    let sourceLeft: SVNTreeConflictVersion?
    let sourceRight: SVNTreeConflictVersion?

    func localizedSummary(using localizer: AppLocalizer) -> String {
        let localKind = localizedKind(using: localizer)
        let incomingKind = localizer.string(localizationKey(forKind: sourceRight?.kind ?? kind))
        return localizer.string(
            "tree_conflict.summary",
            localKind,
            localizedReason(using: localizer),
            localizedAction(using: localizer),
            incomingKind,
            localizedOperation(using: localizer)
        )
    }

    func localizedKind(using localizer: AppLocalizer) -> String {
        localizer.string(localizationKey(forKind: kind))
    }

    func localizedReason(using localizer: AppLocalizer) -> String {
        localizer.string(localizationKey(forReason: reason))
    }

    func localizedAction(using localizer: AppLocalizer) -> String {
        localizer.string(localizationKey(forAction: action))
    }

    func localizedOperation(using localizer: AppLocalizer) -> String {
        localizer.string(localizationKey(forOperation: operation))
    }

    private func localizationKey(forKind kind: String) -> String {
        switch kind.lowercased() {
        case "dir":
            return "tree_conflict.kind.dir"
        case "file":
            return "tree_conflict.kind.file"
        default:
            return kind.lowercased()
        }
    }

    private func localizationKey(forReason reason: String) -> String {
        switch reason.lowercased() {
        case "edit":
            return "tree_conflict.reason.edit"
        case "delete":
            return "tree_conflict.reason.delete"
        case "missing":
            return "tree_conflict.reason.missing"
        case "obstruct":
            return "tree_conflict.reason.obstruct"
        default:
            return reason.lowercased()
        }
    }

    private func localizationKey(forAction action: String) -> String {
        switch action.lowercased() {
        case "add":
            return "tree_conflict.action.add"
        case "delete":
            return "tree_conflict.action.delete"
        case "edit":
            return "tree_conflict.action.edit"
        case "replace":
            return "tree_conflict.action.replace"
        default:
            return action.lowercased()
        }
    }

    private func localizationKey(forOperation operation: String) -> String {
        switch operation.lowercased() {
        case "update":
            return "tree_conflict.operation.update"
        case "switch":
            return "tree_conflict.operation.switch"
        case "merge":
            return "tree_conflict.operation.merge"
        default:
            return operation.lowercased()
        }
    }
}

struct WorkingCopyIssue: Identifiable, Hashable {
    let path: String
    let status: FileStatus
    let existsOnDisk: Bool

    var id: String { "\(status.rawValue):\(path)" }
}

struct WorkingCopyStatusIndex {
    let explicitStatuses: [String: FileStatus]
    let directoryStatuses: [String: FileStatus]
    let issues: [WorkingCopyIssue]

    static let empty = WorkingCopyStatusIndex(
        explicitStatuses: [:],
        directoryStatuses: [:],
        issues: []
    )

    func status(for path: String, isDirectory: Bool) -> FileStatus {
        if isDirectory {
            if let directoryStatus = directoryStatuses[path] {
                return directoryStatus
            }

            if let explicitStatus = explicitStatuses[path] {
                return explicitStatus
            }

            return .normal
        }

        return explicitStatuses[path] ?? .normal
    }
}

struct WorkingCopySnapshot {
    let rootNodes: [FileNode]
    let issues: [WorkingCopyIssue]
    let statusIndex: WorkingCopyStatusIndex
}

enum FileStatus: String, Codable, CaseIterable {
    case normal
    case modified
    case added
    case deleted
    case unversioned
    case conflict
    case ignored
    case missing
    case replaced
    case external

    init(svnItem: String) {
        switch svnItem.lowercased() {
        case "modified":
            self = .modified
        case "added":
            self = .added
        case "deleted":
            self = .deleted
        case "unversioned":
            self = .unversioned
        case "conflicted":
            self = .conflict
        case "ignored":
            self = .ignored
        case "missing":
            self = .missing
        case "replaced":
            self = .replaced
        case "external":
            self = .external
        default:
            self = .normal
        }
    }

    var symbol: String {
        switch self {
        case .normal:
            return " "
        case .modified:
            return "M"
        case .added:
            return "A"
        case .deleted:
            return "D"
        case .unversioned:
            return "?"
        case .conflict:
            return "C"
        case .ignored:
            return "I"
        case .missing:
            return "!"
        case .replaced:
            return "R"
        case .external:
            return "X"
        }
    }

    var displayName: String {
        switch self {
        case .normal:
            return "Normal"
        case .modified:
            return "Modified"
        case .added:
            return "Added"
        case .deleted:
            return "Deleted"
        case .unversioned:
            return "Unversioned"
        case .conflict:
            return "Conflict"
        case .ignored:
            return "Ignored"
        case .missing:
            return "Missing"
        case .replaced:
            return "Replaced"
        case .external:
            return "External"
        }
    }

    var localizationKey: String {
        switch self {
        case .normal:
            return "status.normal"
        case .modified:
            return "status.modified"
        case .added:
            return "status.added"
        case .deleted:
            return "status.deleted"
        case .unversioned:
            return "status.unversioned"
        case .conflict:
            return "status.conflict"
        case .ignored:
            return "status.ignored"
        case .missing:
            return "status.missing"
        case .replaced:
            return "status.replaced"
        case .external:
            return "status.external"
        }
    }

    var badgeText: String? {
        self == .normal ? nil : displayName.uppercased()
    }

    func localizedDisplayName(using localizer: AppLocalizer) -> String {
        localizer.string(localizationKey)
    }

    func localizedBadgeText(using localizer: AppLocalizer) -> String? {
        self == .normal ? nil : localizer.uppercased(localizationKey)
    }

    var isCommittable: Bool {
        switch self {
        case .modified, .added, .deleted, .replaced:
            return true
        case .normal, .unversioned, .conflict, .ignored, .missing, .external:
            return false
        }
    }

    var isAddable: Bool {
        self == .unversioned
    }
}

struct FileNode: Identifiable, Hashable {
    let path: String
    let name: String
    let isDirectory: Bool
    let status: FileStatus
    var children: [FileNode]
    var childrenLoaded: Bool

    var id: String { path }

    var icon: String {
        if isDirectory {
            return status == .unversioned ? "folder" : "folder.fill"
        }

        switch status {
        case .modified:
            return "doc.badge.gearshape"
        case .added:
            return "plus.circle.fill"
        case .deleted:
            return "minus.circle.fill"
        case .unversioned:
            return "questionmark.circle"
        case .conflict:
            return "exclamationmark.triangle.fill"
        case .ignored:
            return "eye.slash"
        case .missing:
            return "xmark.circle"
        case .replaced:
            return "arrow.triangle.2.circlepath"
        case .external:
            return "arrow.up.right.square"
        case .normal:
            return "doc"
        }
    }

    var isSelectableForActions: Bool {
        !isDirectory && (status.isAddable || status.isCommittable)
    }
}

struct SVNError: LocalizedError {
    let message: String
    let command: String?
    let output: String?

    init(message: String, command: String? = nil, output: String? = nil) {
        self.message = message
        self.command = command
        self.output = output
    }

    var errorDescription: String? {
        let localizer = AppLocalizer.current()
        var parts = [message]

        if let command, !command.isEmpty {
            parts.append(localizer.string("error.command_prefix", command))
        }

        if let output, !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(output.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return parts.joined(separator: "\n")
    }
}
