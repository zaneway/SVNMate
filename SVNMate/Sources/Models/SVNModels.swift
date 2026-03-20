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

    var displaySide: String {
        switch side {
        case "source-left":
            return "Source Left"
        case "source-right":
            return "Source Right"
        default:
            return side
        }
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

    var summary: String {
        let localKind = display(kind: kind)
        let incomingKind = display(kind: sourceRight?.kind ?? kind)
        return "local \(localKind) \(display(reason: reason)), incoming \(display(action: action)) with \(incomingKind) upon \(display(operation: operation))"
    }

    private func display(kind: String) -> String {
        switch kind.lowercased() {
        case "dir":
            return "dir"
        case "file":
            return "file"
        default:
            return kind.lowercased()
        }
    }

    private func display(reason: String) -> String {
        switch reason.lowercased() {
        case "edit":
            return "edit"
        case "delete":
            return "delete"
        case "missing":
            return "missing"
        case "obstruct":
            return "obstruct"
        default:
            return reason.lowercased()
        }
    }

    private func display(action: String) -> String {
        switch action.lowercased() {
        case "add":
            return "add"
        case "delete":
            return "delete"
        case "edit":
            return "edit"
        case "replace":
            return "replace"
        default:
            return action.lowercased()
        }
    }

    private func display(operation: String) -> String {
        switch operation.lowercased() {
        case "update":
            return "update"
        case "switch":
            return "switch"
        case "merge":
            return "merge"
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

    var badgeText: String? {
        self == .normal ? nil : displayName.uppercased()
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
        var parts = [message]

        if let command, !command.isEmpty {
            parts.append("Command: \(command)")
        }

        if let output, !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(output.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return parts.joined(separator: "\n")
    }
}
