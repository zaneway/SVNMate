import SwiftUI
import AppKit

struct RepositoryDetailView: View {
    let repository: Repository
    @StateObject private var viewModel: RepositoryViewModel
    @State private var selectedFile: FileNode?
    @State private var commitMessage = ""
    @State private var selectedFiles: Set<String> = []
    @State private var pendingSelectionAfterReload: Set<String> = []
    @State private var commitEditorFocusToken = 0
    
    init(repository: Repository) {
        self.repository = repository
        _viewModel = StateObject(wrappedValue: RepositoryViewModel(repository: repository))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            RepositoryToolbar(viewModel: viewModel)
            
            Divider()
            
            // Main Content
            HSplitView {
                // File Tree
                FileTreeView(
                    nodes: viewModel.fileNodes,
                    isLoading: viewModel.isLoading,
                    issueCount: viewModel.issues.count,
                    selectedFile: $selectedFile,
                    selectedFiles: $selectedFiles,
                    isExpanded: { node in
                        viewModel.isExpanded(node)
                    },
                    onSetExpanded: { node, expanded in
                        viewModel.setExpanded(expanded, for: node)
                    }
                )
                .frame(minWidth: 250, idealWidth: 300)
                
                // Detail Panel
                if !selectedNodes.isEmpty {
                    SelectionActionPanel(
                        selectedNodes: selectedNodes,
                        selectedFile: selectedFile,
                        commitMessage: $commitMessage,
                        commitEditorFocusToken: commitEditorFocusToken,
                        diffOutput: viewModel.diffOutput,
                        issues: viewModel.issues,
                        isLoading: viewModel.isLoading,
                        commitBlockedReason: commitBlockedReason,
                        treeConflictDetail: viewModel.treeConflictDetail(for: primaryTreeConflictPath),
                        isLoadingTreeConflictDetail: viewModel.isLoadingTreeConflictDetail(for: primaryTreeConflictPath),
                        onAdd: {
                            let addablePaths = selectedAddablePaths
                            pendingSelectionAfterReload.formUnion(addablePaths)
                            viewModel.add(files: addablePaths) {
                                commitEditorFocusToken += 1
                            }
                        },
                        onCommit: {
                            guard commitBlockedReason == nil else {
                                return
                            }

                            let message = commitMessage.trimmingCharacters(in: .whitespacesAndNewlines)
                        viewModel.commit(message: message, files: commitTargets) {
                                commitMessage = ""
                                selectedFiles.removeAll()
                                pendingSelectionAfterReload.removeAll()
                            }
                        },
                        onClearSelection: {
                            selectedFiles.removeAll()
                        },
                        onShowDiff: {
                            guard let diffTarget else { return }
                            viewModel.showDiff(for: diffTarget)
                        },
                        onResolve: {
                            guard let conflictTarget else { return }
                            viewModel.resolve(file: conflictTarget.path)
                        }
                    )
                } else if let file = selectedFile {
                    FileDetailView(
                        file: file,
                        viewModel: viewModel,
                        issues: viewModel.issues,
                        treeConflictDetail: viewModel.treeConflictDetail(for: primaryTreeConflictPath),
                        isLoadingTreeConflictDetail: viewModel.isLoadingTreeConflictDetail(for: primaryTreeConflictPath),
                        onAdd: {
                            viewModel.add(files: [file.path])
                        },
                        onResolve: {
                            viewModel.resolve(file: file.path)
                        }
                    )
                } else if !viewModel.issues.isEmpty {
                    IssueOverviewView(issues: viewModel.issues)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 48))
                        .foregroundColor(.secondary)
                        Text("Select a file to view details")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .alert("Repository Error", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.clearError() } }
        )) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onAppear {
            viewModel.loadFiles()
            viewModel.loadTreeConflictDetailIfNeeded(for: primaryTreeConflictPath)
        }
        .onChange(of: viewModel.fileNodes) { nodes in
            let flattenedNodes = flatten(nodes)
            let validSelections = Set(flattenedNodes.filter(\.isSelectableForActions).map(\.path))
            let restoredSelections = pendingSelectionAfterReload.intersection(validSelections)
            selectedFiles.formUnion(restoredSelections)
            pendingSelectionAfterReload.subtract(restoredSelections)

            selectedFiles = Set(
                selectedFiles.filter { validSelections.contains($0) || pendingSelectionAfterReload.contains($0) }
            )

            if let selectedFile {
                self.selectedFile = flattenedNodes.first(where: { $0.path == selectedFile.path })
            }
        }
        .onChange(of: primaryTreeConflictPath) { path in
            viewModel.loadTreeConflictDetailIfNeeded(for: path)
        }
    }

    private var allNodesByPath: [String: FileNode] {
        Dictionary(uniqueKeysWithValues: flatten(viewModel.fileNodes).map { ($0.path, $0) })
    }

    private var selectedNodes: [FileNode] {
        selectedFiles.compactMap { allNodesByPath[$0] }
            .sorted { $0.path.localizedCaseInsensitiveCompare($1.path) == .orderedAscending }
    }

    private var selectedAddablePaths: [String] {
        normalized(paths: selectedNodes.filter { $0.status.isAddable }.map(\.path))
    }

    private var selectedCommittablePaths: [String] {
        normalized(paths: selectedNodes.filter { $0.status.isCommittable }.map(\.path))
    }

    private var commitTargets: [String] {
        viewModel.commitTargets(for: selectedCommittablePaths)
    }

    private var commitBlockedPaths: [String] {
        viewModel.commitBlockedPaths(for: selectedCommittablePaths)
    }

    private var commitBlockedReason: String? {
        guard !commitBlockedPaths.isEmpty else {
            return nil
        }

        let preview = commitBlockedPaths.prefix(3).joined(separator: ", ")
        let suffix = commitBlockedPaths.count > 3 ? " ..." : ""
        return "Resolve conflict before commit: \(preview)\(suffix)"
    }

    private var primaryTreeConflictPath: String? {
        if !commitBlockedPaths.isEmpty {
            return commitBlockedPaths.first
        }

        if let selectedFile, selectedFile.status == .conflict {
            return selectedFile.path
        }

        return conflictTarget?.path
    }

    private var diffTarget: FileNode? {
        if let selectedFile,
           selectedFiles.contains(selectedFile.path),
           !selectedFile.isDirectory,
           selectedFile.status != .unversioned {
            return selectedFile
        }

        return selectedNodes.first(where: { !$0.isDirectory && $0.status != .unversioned })
    }

    private var conflictTarget: FileNode? {
        if let selectedFile,
           selectedFiles.contains(selectedFile.path),
           selectedFile.status == .conflict {
            return selectedFile
        }

        return selectedNodes.first(where: { $0.status == .conflict })
    }

    private func flatten(_ nodes: [FileNode]) -> [FileNode] {
        nodes.flatMap { node in
            [node] + flatten(node.children)
        }
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
}

// MARK: - Toolbar

struct RepositoryToolbar: View {
    @ObservedObject var viewModel: RepositoryViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            // Repository Info
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.repository.name)
                    .font(.headline)
                Text(viewModel.repository.url)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 8) {
                Button {
                    viewModel.update()
                } label: {
                    Label("Update", systemImage: "arrow.down.circle")
                }
                .disabled(viewModel.isLoading)
                
                Button {
                    viewModel.cleanup()
                } label: {
                    Label("Cleanup", systemImage: "wand.and.stars")
                }
                .disabled(viewModel.isLoading)

                Button {
                    viewModel.loadFiles()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
            }
            
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - File Tree

struct FileTreeView: View {
    let nodes: [FileNode]
    let isLoading: Bool
    let issueCount: Int
    @Binding var selectedFile: FileNode?
    @Binding var selectedFiles: Set<String>
    let isExpanded: (FileNode) -> Bool
    let onSetExpanded: (FileNode, Bool) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Files")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                if issueCount > 0 {
                    Text("\(issueCount) issues")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                Text("\(countFiles(nodes)) loaded")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            Divider()
            
            if isLoading {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if nodes.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "folder")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                    Text("Repository directory is empty")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(nodes) { node in
                        FileTreeNodeView(
                            node: node,
                            selectedFile: $selectedFile,
                            selectedFiles: $selectedFiles,
                            depth: 0,
                            isExpanded: isExpanded(node),
                            isChildExpanded: isExpanded,
                            onSetExpanded: onSetExpanded
                        )
                    }
                }
                .listStyle(.sidebar)
            }
        }
    }
    
    private func countFiles(_ nodes: [FileNode]) -> Int {
        var count = 0
        for node in nodes {
            count += 1
            count += countFiles(node.children)
        }
        return count
    }
}

struct FileTreeNodeView: View {
    let node: FileNode
    @Binding var selectedFile: FileNode?
    @Binding var selectedFiles: Set<String>
    let depth: Int
    let isExpanded: Bool
    let isChildExpanded: (FileNode) -> Bool
    let onSetExpanded: (FileNode, Bool) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                if node.isDirectory {
                    Button {
                        onSetExpanded(node, !isExpanded)
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 12)
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer()
                        .frame(width: 12)
                }

                if node.isSelectableForActions {
                    Button {
                        toggleSelection()
                    } label: {
                        Image(systemName: selectedFiles.contains(node.path) ? "checkmark.square.fill" : "square")
                            .foregroundColor(selectedFiles.contains(node.path) ? .accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer()
                        .frame(width: 14)
                }
                
                Image(systemName: node.icon)
                    .foregroundColor(iconColor)
                    .font(.system(size: 13))
                
                Text(node.name)
                    .font(.system(size: 13))
                    .lineLimit(1)
                
                Spacer()
                
                if let statusText = node.status.badgeText {
                    Text(statusText)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(statusColor)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(statusColor.opacity(0.15))
                        .cornerRadius(3)
                }
            }
            .padding(.leading, CGFloat(depth) * 16)
            .padding(.vertical, 2)
            .background(node.status == .conflict ? Color.red.opacity(0.08) : Color.clear)
            .cornerRadius(6)
            .contentShape(Rectangle())
            .onTapGesture {
                selectedFile = node
            }
            
            if node.isDirectory && isExpanded {
                ForEach(node.children) { child in
                    FileTreeNodeView(
                        node: child,
                        selectedFile: $selectedFile,
                        selectedFiles: $selectedFiles,
                        depth: depth + 1,
                        isExpanded: isChildExpanded(child),
                        isChildExpanded: isChildExpanded,
                        onSetExpanded: onSetExpanded
                    )
                }
            }
        }
    }

    private func toggleSelection() {
        if selectedFiles.contains(node.path) {
            selectedFiles.remove(node.path)
        } else {
            selectedFiles.insert(node.path)
        }
    }
    
    private var iconColor: Color {
        switch node.status {
        case .modified: return .orange
        case .added: return .green
        case .deleted: return .red
        case .unversioned: return .secondary
        case .conflict: return .red
        case .missing: return .red
        case .replaced: return .orange
        case .external: return .blue
        case .normal: return .primary
        case .ignored: return .gray
        }
    }

    private var statusColor: Color {
        switch node.status {
        case .modified: return .orange
        case .added: return .green
        case .deleted: return .red
        case .unversioned: return .secondary
        case .conflict: return .red
        case .missing: return .red
        case .replaced: return .orange
        case .external: return .blue
        case .normal: return .clear
        case .ignored: return .gray
        }
    }
}

// MARK: - File Detail

struct FileDetailView: View {
    let file: FileNode
    @ObservedObject var viewModel: RepositoryViewModel
    let issues: [WorkingCopyIssue]
    let treeConflictDetail: SVNTreeConflictDetail?
    let isLoadingTreeConflictDetail: Bool
    let onAdd: () -> Void
    let onResolve: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: file.icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading) {
                    Text(file.name)
                        .font(.headline)
                    Text(file.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // File Info
                    InfoRow(label: "Status", value: file.status.displayName)
                    
                    if !file.isDirectory && file.status.isAddable {
                        Button("Add to SVN") {
                            onAdd()
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    if !file.isDirectory {
                        HStack {
                            Button("View Diff") {
                                viewModel.showDiff(for: file)
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    if file.status == .conflict {
                        Button(file.isDirectory ? "Resolve Conflict" : "Resolve") {
                            onResolve()
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    if file.status == .conflict || treeConflictDetail != nil || isLoadingTreeConflictDetail {
                        TreeConflictDetailSection(
                            detail: treeConflictDetail,
                            isLoading: isLoadingTreeConflictDetail
                        )
                    }

                    if !issues.isEmpty {
                        SVNIssuesSection(issues: issues)
                    }
                }
                .padding()
            }
            
            // Diff Output
            if let diff = viewModel.diffOutput, !diff.isEmpty {
                Divider()
                DiffView(content: diff)
            }
        }
    }
}

struct SelectionActionPanel: View {
    let selectedNodes: [FileNode]
    let selectedFile: FileNode?
    @Binding var commitMessage: String
    let commitEditorFocusToken: Int
    let diffOutput: String?
    let issues: [WorkingCopyIssue]
    let isLoading: Bool
    let commitBlockedReason: String?
    let treeConflictDetail: SVNTreeConflictDetail?
    let isLoadingTreeConflictDetail: Bool
    let onAdd: () -> Void
    let onCommit: () -> Void
    let onClearSelection: () -> Void
    let onShowDiff: () -> Void
    let onResolve: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Selection Actions")
                        .font(.headline)
                    Text("\(selectedNodes.count) item(s) selected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Clear Selection") {
                    onClearSelection()
                }
                .disabled(isLoading)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SelectionSummaryView(
                        addableCount: addableNodes.count,
                        committableCount: committableNodes.count,
                        blockedCount: blockedNodes.count
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Commit Message")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        CommitMessageEditor(
                            text: $commitMessage,
                            focusToken: commitEditorFocusToken
                        )
                            .frame(minHeight: 120)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                            )
                    }

                    HStack(spacing: 10) {
                        Button("Add to SVN") {
                            onAdd()
                        }
                        .buttonStyle(.bordered)
                        .disabled(addableNodes.isEmpty || isLoading)

                        Button("Commit Selected") {
                            onCommit()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(
                            committableNodes.isEmpty ||
                            commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                            commitBlockedReason != nil ||
                            isLoading
                        )

                        if canShowDiff {
                            Button("View Diff") {
                                onShowDiff()
                            }
                            .buttonStyle(.bordered)
                            .disabled(isLoading)
                        }

                        if canResolveConflict {
                            Button("Resolve") {
                                onResolve()
                            }
                            .buttonStyle(.bordered)
                            .disabled(isLoading)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Selected Items")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        VStack(spacing: 8) {
                            ForEach(selectedNodes) { node in
                                SelectionItemRow(node: node, isFocused: node.path == selectedFile?.path)
                            }
                        }
                    }

                    if !addableNodes.isEmpty && committableNodes.isEmpty {
                        Text("These items are not versioned yet. Run Add to SVN first, then commit them with the message above.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let commitBlockedReason {
                        Text(commitBlockedReason)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    if commitBlockedReason != nil || treeConflictDetail != nil || isLoadingTreeConflictDetail {
                        TreeConflictDetailSection(
                            detail: treeConflictDetail,
                            isLoading: isLoadingTreeConflictDetail
                        )
                    }

                    if !issues.isEmpty {
                        SVNIssuesSection(issues: issues)
                    }

                    if let diffOutput, !diffOutput.isEmpty {
                        DiffView(content: diffOutput)
                    }
                }
                .padding()
            }
        }
    }

    private var addableNodes: [FileNode] {
        selectedNodes.filter { $0.status.isAddable }
    }

    private var committableNodes: [FileNode] {
        selectedNodes.filter { $0.status.isCommittable }
    }

    private var blockedNodes: [FileNode] {
        selectedNodes.filter { !$0.status.isAddable && !$0.status.isCommittable }
    }

    private var canShowDiff: Bool {
        selectedNodes.contains { !$0.isDirectory && $0.status != .unversioned }
    }

    private var canResolveConflict: Bool {
        selectedNodes.contains { $0.status == .conflict }
    }
}

struct CommitMessageEditor: NSViewRepresentable {
    @Binding var text: String
    let focusToken: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = NSTextView(frame: .zero)
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.backgroundColor = .textBackgroundColor
        textView.textColor = .labelColor
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.textContainerInset = NSSize(width: 8, height: 10)
        textView.minSize = NSSize(width: 0, height: 120)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.string = text
        textView.textContainer?.containerSize = NSSize(
            width: 0,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true

        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.lastFocusToken = focusToken

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else {
            return
        }

        if textView.string != text {
            textView.string = text
        }

        if context.coordinator.lastFocusToken != focusToken {
            context.coordinator.lastFocusToken = focusToken
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
            }
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CommitMessageEditor
        weak var textView: NSTextView?
        var lastFocusToken: Int = 0

        init(_ parent: CommitMessageEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }

            parent.text = textView.string
        }
    }
}

struct SelectionSummaryView: View {
    let addableCount: Int
    let committableCount: Int
    let blockedCount: Int

    var body: some View {
        HStack(spacing: 12) {
            SummaryBadge(title: "Addable", count: addableCount, color: .blue)
            SummaryBadge(title: "Committable", count: committableCount, color: .green)
            SummaryBadge(title: "Other", count: blockedCount, color: .secondary)
        }
    }
}

struct SummaryBadge: View {
    let title: String
    let count: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text("\(count)")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.08))
        .cornerRadius(10)
    }
}

struct SelectionItemRow: View {
    let node: FileNode
    let isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: node.icon)
                .foregroundColor(iconColor)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(node.name)
                    .font(.system(size: 13, weight: isFocused ? .semibold : .regular))
                Text(node.path)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(node.status.displayName.uppercased())
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(iconColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(iconColor.opacity(0.15))
                .cornerRadius(4)
        }
        .padding(10)
        .background(isFocused ? Color.accentColor.opacity(0.08) : Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private var iconColor: Color {
        switch node.status {
        case .modified, .replaced:
            return .orange
        case .added:
            return .green
        case .deleted, .conflict, .missing:
            return .red
        case .unversioned:
            return .blue
        case .external:
            return .indigo
        case .ignored, .normal:
            return .secondary
        }
    }
}

struct TreeConflictDetailSection: View {
    let detail: SVNTreeConflictDetail?
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tree Conflict")
                .font(.subheadline)
                .fontWeight(.medium)

            if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading conflict detail...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if let detail {
                Text(detail.summary)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.red)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.08))
                    .cornerRadius(8)

                InfoRow(label: "Victim", value: detail.victim)
                InfoRow(label: "Reason", value: detail.reason)
                InfoRow(label: "Action", value: detail.action)
                InfoRow(label: "Operation", value: detail.operation)

                if let sourceLeft = detail.sourceLeft {
                    TreeConflictVersionBlock(version: sourceLeft)
                }

                if let sourceRight = detail.sourceRight {
                    TreeConflictVersionBlock(version: sourceRight)
                }
            } else {
                Text("Conflict detail unavailable.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct TreeConflictVersionBlock: View {
    let version: SVNTreeConflictVersion

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(version.displaySide)
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                InfoRow(label: "Kind", value: version.kind)
                InfoRow(label: "Revision", value: version.revision)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Path In Repos")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(version.pathInRepos)
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Repository URL")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(version.reposURL)
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }
}

struct IssueOverviewView: View {
    let issues: [WorkingCopyIssue]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SVN Issues")
                        .font(.headline)
                    Text("\(issues.count) issue(s) need attention")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding()

            Divider()

            ScrollView {
                SVNIssuesSection(issues: issues)
                    .padding()
            }
        }
    }
}

struct SVNIssuesSection: View {
    let issues: [WorkingCopyIssue]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SVN Issues")
                .font(.subheadline)
                .fontWeight(.medium)

            VStack(spacing: 8) {
                ForEach(issues) { issue in
                    SVNIssueRow(issue: issue)
                }
            }
        }
    }
}

struct SVNIssueRow: View {
    let issue: WorkingCopyIssue

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: issueIcon)
                .foregroundColor(.orange)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(issue.path)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                Text(issueDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(issue.status.displayName.uppercased())
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.orange)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.orange.opacity(0.15))
                .cornerRadius(4)
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private var issueDescription: String {
        if issue.existsOnDisk {
            return "SVN reported an issue for this path."
        }

        return "The path is tracked by SVN but is missing from disk."
    }

    private var issueIcon: String {
        switch issue.status {
        case .missing, .deleted:
            return "exclamationmark.triangle.fill"
        case .conflict:
            return "exclamationmark.octagon.fill"
        default:
            return "exclamationmark.circle.fill"
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(.subheadline, design: .monospaced))
        }
    }
}

struct DiffView: View {
    let content: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Diff")
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal)
                .padding(.top, 8)
            
            ScrollView {
                Text(content)
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(Color(NSColor.textBackgroundColor))
        }
        .frame(maxHeight: 300)
    }
}
