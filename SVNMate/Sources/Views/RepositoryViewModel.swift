import SwiftUI

@MainActor
final class RepositoryViewModel: ObservableObject {
    private enum RefreshPolicy {
        static let expandStatusRefreshDebounce: TimeInterval = 1.5
    }

    @Published var repository: Repository
    @Published var fileNodes: [FileNode] = []
    @Published var issues: [WorkingCopyIssue] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var diffOutput: String?
    @Published var logOutput: String?
    @Published private(set) var expandedDirectories: Set<String> = []
    @Published private(set) var treeConflictDetails: [String: SVNTreeConflictDetail] = [:]
    @Published private(set) var loadingTreeConflictPaths: Set<String> = []
    
    private let svnService = SVNService()
    private let fileManager = FileManager.default
    private var statusIndex = WorkingCopyStatusIndex.empty
    private var pendingExpandedDirectories: Set<String> = []
    private var lastStatusRefreshAt: Date?
    private var snapshotRefreshTask: Task<WorkingCopySnapshot, Error>?
    
    init(repository: Repository) {
        self.repository = repository
    }
    
    func loadFiles() {
        isLoading = true
        diffOutput = nil
        
        Task {
            do {
                let snapshot = try await svnService.workingCopySnapshot(at: repository.path)
                try apply(snapshot: snapshot)
                isLoading = false
            } catch {
                clearSnapshotState()
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    func update(revision: String? = nil) {
        isLoading = true
        
        Task {
            do {
                _ = try await svnService.update(at: repository.path, revision: revision)
                isLoading = false
                loadFiles()
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    func commit(message: String, files: [String] = []) {
        commit(message: message, files: files, onSuccess: nil)
    }

    func commit(message: String, files: [String] = [], onSuccess: (() -> Void)? = nil) {
        isLoading = true
        
        Task {
            do {
                let latestSnapshot = try await svnService.workingCopySnapshot(at: repository.path)
                try apply(snapshot: latestSnapshot)
                let preflightPaths = files.isEmpty
                    ? Array(latestSnapshot.statusIndex.explicitStatuses.keys)
                    : files
                let blockedPaths = blockedPaths(
                    for: preflightPaths,
                    using: latestSnapshot.statusIndex
                )

                if !blockedPaths.isEmpty {
                    errorMessage = "Resolve conflict before commit: \(blockedPaths.joined(separator: ", "))"
                    isLoading = false
                    return
                }

                _ = try await svnService.commit(at: repository.path, message: message, files: files)
                onSuccess?()
                isLoading = false
                loadFiles()
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    func add(files: [String], onSuccess: (() -> Void)? = nil) {
        isLoading = true
        let directoriesToExpand = ancestorDirectories(for: files)
        pendingExpandedDirectories.formUnion(directoriesToExpand)

        Task {
            do {
                _ = try await svnService.add(at: repository.path, files: files)
                onSuccess?()
                isLoading = false
                loadFiles()
            } catch {
                pendingExpandedDirectories.subtract(directoriesToExpand)
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    func cleanup() {
        isLoading = true
        
        Task {
            do {
                _ = try await svnService.cleanup(at: repository.path)
                isLoading = false
                loadFiles()
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    func showDiff(for file: FileNode) {
        Task {
            do {
                let output = try await svnService.diff(at: repository.path, file: file.path)
                diffOutput = output
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    func resolve(file: String) {
        Task {
            do {
                _ = try await svnService.resolve(at: repository.path, file: file)
                loadFiles()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    func showLog(limit: Int = 10) {
        Task {
            do {
                let output = try await svnService.log(at: repository.path, limit: limit)
                logOutput = output
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func clearError() {
        errorMessage = nil
    }

    func loadTreeConflictDetailIfNeeded(for path: String?) {
        guard let path, !path.isEmpty else {
            return
        }

        if treeConflictDetails[path] != nil || loadingTreeConflictPaths.contains(path) {
            return
        }

        loadingTreeConflictPaths.insert(path)

        Task {
            do {
                let detail = try await svnService.treeConflictDetail(at: repository.path, path: path)
                if let detail {
                    treeConflictDetails[path] = detail
                }
                loadingTreeConflictPaths.remove(path)
            } catch {
                loadingTreeConflictPaths.remove(path)
                errorMessage = error.localizedDescription
            }
        }
    }

    func treeConflictDetail(for path: String?) -> SVNTreeConflictDetail? {
        guard let path else {
            return nil
        }

        return treeConflictDetails[path]
    }

    func isLoadingTreeConflictDetail(for path: String?) -> Bool {
        guard let path else {
            return false
        }

        return loadingTreeConflictPaths.contains(path)
    }

    func commitTargets(for selectedPaths: [String]) -> [String] {
        var targets = Set(selectedPaths)

        for path in selectedPaths {
            for ancestor in ancestorDirectories(for: [path]) {
                if statusIndex.explicitStatuses[ancestor] == .added {
                    targets.insert(ancestor)
                }
            }
        }

        return normalized(paths: Array(targets))
    }

    func commitBlockedPaths(for selectedPaths: [String]) -> [String] {
        blockedPaths(for: selectedPaths, using: statusIndex)
    }

    func isExpanded(_ node: FileNode) -> Bool {
        expandedDirectories.contains(node.path)
    }

    func setExpanded(_ expanded: Bool, for node: FileNode) {
        guard node.isDirectory else {
            return
        }

        if expanded {
            expandedDirectories.insert(node.path)
            Task {
                await expandDirectory(at: node.path)
            }
        } else {
            expandedDirectories.remove(node.path)
        }
    }

    private func restoreExpandedDirectories() throws {
        let requestedPaths = expandedDirectories.sorted { lhs, rhs in
            depth(of: lhs) < depth(of: rhs)
        }

        var validPaths: Set<String> = []

        for path in requestedPaths {
            if try loadChildrenIfNeeded(for: path, forceReload: true) {
                validPaths.insert(path)
            }
        }

        expandedDirectories = validPaths
    }

    @discardableResult
    private func loadChildrenIfNeeded(for path: String, forceReload: Bool = false) throws -> Bool {
        guard let node = node(at: path), node.isDirectory else {
            return false
        }

        if node.childrenLoaded && !forceReload {
            return true
        }

        let children = try svnService.loadDirectory(
            at: repository.path,
            relativePath: path,
            statusIndex: statusIndex
        )
        fileNodes = replacingChildren(in: fileNodes, targetPath: path, children: children)
        return true
    }

    private func node(at path: String) -> FileNode? {
        flatten(fileNodes).first { $0.path == path }
    }

    private func flatten(_ nodes: [FileNode]) -> [FileNode] {
        nodes.flatMap { node in
            [node] + flatten(node.children)
        }
    }

    private func replacingChildren(
        in nodes: [FileNode],
        targetPath: String,
        children: [FileNode]
    ) -> [FileNode] {
        nodes.map { node in
            if node.path == targetPath {
                var updatedNode = node
                updatedNode.children = children
                updatedNode.childrenLoaded = true
                return updatedNode
            }

            guard node.isDirectory, !node.children.isEmpty else {
                return node
            }

            var updatedNode = node
            updatedNode.children = replacingChildren(
                in: node.children,
                targetPath: targetPath,
                children: children
            )
            return updatedNode
        }
    }

    private func depth(of path: String) -> Int {
        path.split(separator: "/").count
    }

    private func apply(snapshot: WorkingCopySnapshot) throws {
        statusIndex = snapshot.statusIndex
        issues = snapshot.issues
        treeConflictDetails.removeAll()
        loadingTreeConflictPaths.removeAll()
        expandedDirectories.formUnion(pendingExpandedDirectories)
        pendingExpandedDirectories.removeAll()
        fileNodes = snapshot.rootNodes
        try restoreExpandedDirectories()
        lastStatusRefreshAt = Date()
    }

    private func clearSnapshotState() {
        statusIndex = .empty
        fileNodes = []
        issues = []
        treeConflictDetails.removeAll()
        loadingTreeConflictPaths.removeAll()
        lastStatusRefreshAt = nil
        snapshotRefreshTask = nil
    }

    private func ancestorDirectories(for paths: [String]) -> Set<String> {
        var ancestors: Set<String> = []

        for path in paths {
            var current = parentPath(of: path)

            while let currentPath = current {
                ancestors.insert(currentPath)
                current = parentPath(of: currentPath)
            }
        }

        return ancestors
    }

    private func parentPath(of path: String) -> String? {
        let components = path.split(separator: "/")
        guard components.count > 1 else {
            return nil
        }

        return components.dropLast().joined(separator: "/")
    }

    private func normalized(paths: [String]) -> [String] {
        let sortedPaths = Array(Set(paths)).sorted()
        var result: [String] = []

        for path in sortedPaths {
            let hasAncestor = result.contains { existing in
                path == existing || path.hasPrefix(existing + "/")
            }

            if !hasAncestor {
                result.append(path)
            }
        }

        return result
    }

    private func blockedPaths(
        for selectedPaths: [String],
        using statusIndex: WorkingCopyStatusIndex
    ) -> [String] {
        var blockedPaths: Set<String> = []

        for path in selectedPaths {
            if statusIndex.explicitStatuses[path] == .conflict {
                blockedPaths.insert(path)
            }

            for ancestor in ancestorDirectories(for: [path]) {
                if statusIndex.status(for: ancestor, isDirectory: true) == .conflict {
                    blockedPaths.insert(ancestor)
                }
            }
        }

        return blockedPaths.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    private func expandDirectory(at path: String) async {
        do {
            try await refreshStatusIfNeededForExpand(path: path)
            _ = try loadChildrenIfNeeded(for: path, forceReload: true)
        } catch {
            clearSnapshotState()
            errorMessage = error.localizedDescription
        }
    }

    private func refreshStatusIfNeededForExpand(path: String) async throws {
        guard shouldRefreshStatusOnExpand(for: path) else {
            return
        }

        if let snapshotRefreshTask {
            let snapshot = try await snapshotRefreshTask.value
            try apply(snapshot: snapshot)
            return
        }

        let task = Task {
            try await svnService.workingCopySnapshot(at: repository.path)
        }
        snapshotRefreshTask = task

        do {
            let snapshot = try await task.value
            try apply(snapshot: snapshot)
            snapshotRefreshTask = nil
        } catch {
            snapshotRefreshTask = nil
            throw error
        }
    }

    private func shouldRefreshStatusOnExpand(for path: String, now: Date = Date()) -> Bool {
        guard let lastStatusRefreshAt else {
            return true
        }

        if directoryChangedSinceLastStatusRefresh(path: path, lastStatusRefreshAt: lastStatusRefreshAt) {
            return true
        }

        return now.timeIntervalSince(lastStatusRefreshAt) >= RefreshPolicy.expandStatusRefreshDebounce
    }

    private func directoryChangedSinceLastStatusRefresh(path: String, lastStatusRefreshAt: Date) -> Bool {
        let absolutePath = (repository.path as NSString).appendingPathComponent(path)

        guard let attributes = try? fileManager.attributesOfItem(atPath: absolutePath),
              let modifiedAt = attributes[.modificationDate] as? Date else {
            return true
        }

        return modifiedAt >= lastStatusRefreshAt
    }
}
