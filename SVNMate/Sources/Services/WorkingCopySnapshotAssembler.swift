import Foundation

final class WorkingCopySnapshotAssembler {
    func makeNodes(
        from entries: [WorkingCopyDiskEntry],
        statusIndex: WorkingCopyStatusIndex,
        childrenLoaded: Bool
    ) -> [FileNode] {
        entries.map { entry in
            FileNode(
                path: entry.path,
                name: entry.name,
                isDirectory: entry.isDirectory,
                status: statusIndex.status(for: entry.path, isDirectory: entry.isDirectory),
                children: [],
                childrenLoaded: !entry.isDirectory || childrenLoaded
            )
        }
    }
}
