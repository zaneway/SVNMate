import SwiftUI
import AppKit

private struct CheckoutLogEntry: Identifiable {
    let id = UUID()
    let text: String
    let isError: Bool
}

struct CheckoutSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLocalizer) private var appLocalizer

    @State private var repositoryURL = ""
    @State private var localPath = ""
    @State private var isCheckingOut = false
    @State private var errorMessage: String?
    @State private var checkoutLogEntries: [CheckoutLogEntry] = []
    @State private var currentCheckoutMessage = ""
    @State private var checkedOutItemCount = 0
    @State private var checkoutTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("checkout.title")
                    .font(.headline)
                Spacer()
                Button("common.cancel") {
                    dismiss()
                }
                .disabled(isCheckingOut)
            }
            .padding()

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("checkout.repository_url")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    TextField("checkout.repository_url.placeholder", text: $repositoryURL)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isCheckingOut)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("checkout.local_directory")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    HStack {
                        TextField("checkout.local_directory.placeholder", text: $localPath)
                            .textFieldStyle(.roundedBorder)
                            .disabled(isCheckingOut)

                        Button("common.browse") {
                            selectFolder()
                        }
                        .disabled(isCheckingOut)
                    }
                }

                if isCheckingOut || !checkoutLogEntries.isEmpty {
                    progressSection
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .textSelection(.enabled)
                }
            }
            .padding()

            Spacer()

            Divider()

            HStack {
                if isCheckingOut {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(currentCheckoutMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                        Text(appLocalizer.string("checkout.items_reported", checkedOutItemCount))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Spacer()
                }

                Button("checkout.action") {
                    performCheckout()
                }
                .buttonStyle(.borderedProminent)
                .disabled(repositoryURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || localPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCheckingOut)
            }
            .padding()
        }
        .frame(width: 640, height: 480)
        .interactiveDismissDisabled(isCheckingOut)
        .onAppear {
            if currentCheckoutMessage.isEmpty {
                currentCheckoutMessage = appLocalizer.string("checkout.ready")
            }
        }
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("checkout.progress.title")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(appLocalizer.string("checkout.progress.items", checkedOutItemCount))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(currentCheckoutMessage)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(checkoutLogEntries) { entry in
                            Text(entry.text)
                                .font(.system(size: 11, weight: .regular, design: .monospaced))
                                .foregroundColor(entry.isError ? .red : .primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                                .id(entry.id)
                        }
                    }
                    .padding(10)
                }
                .frame(minHeight: 200, maxHeight: 240)
                .background(Color(NSColor.textBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onChange(of: checkoutLogEntries.count) { _ in
                    guard let lastID = checkoutLogEntries.last?.id else {
                        return
                    }
                    proxy.scrollTo(lastID, anchor: .bottom)
                }
            }
        }
    }

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = appLocalizer.string("checkout.open_panel.message")
        panel.prompt = appLocalizer.string("checkout.open_panel.prompt")

        if panel.runModal() == .OK, let url = panel.url {
            localPath = url.path
        }
    }

    private func performCheckout() {
        let trimmedURL = repositoryURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPath = localPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty, !trimmedPath.isEmpty else {
            return
        }

        isCheckingOut = true
        errorMessage = nil
        checkoutLogEntries = []
        checkedOutItemCount = 0
        currentCheckoutMessage = appLocalizer.string("checkout.preparing")

        checkoutTask = Task {
            do {
                let svnService = SVNService()
                _ = try await svnService.checkout(
                    url: trimmedURL,
                    to: trimmedPath,
                    outputHandler: { outputLine in
                        Task { @MainActor in
                            appendCheckoutOutput(outputLine)
                        }
                    }
                )

                await MainActor.run {
                    currentCheckoutMessage = appLocalizer.string("checkout.completed")
                    isCheckingOut = false
                    checkoutTask = nil
                    dismiss()
                    appState.addRepository(at: trimmedPath)
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    currentCheckoutMessage = appLocalizer.string("checkout.failed")
                    isCheckingOut = false
                    checkoutTask = nil
                }
            }
        }
    }

    @MainActor
    private func appendCheckoutOutput(_ outputLine: SVNCommandOutputLine) {
        let trimmedText = outputLine.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return
        }

        checkoutLogEntries.append(
            CheckoutLogEntry(
                text: trimmedText,
                isError: outputLine.stream == .stderr
            )
        )

        if currentCheckoutPath(from: trimmedText) != nil {
            checkedOutItemCount += 1
        }

        currentCheckoutMessage = checkoutStatusMessage(from: trimmedText)
    }

    private func currentCheckoutPath(from line: String) -> String? {
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        let parts = trimmedLine.split(maxSplits: 1, omittingEmptySubsequences: true) { $0.isWhitespace }

        guard parts.count == 2 else {
            return nil
        }

        let action = String(parts[0])
        guard ["A", "U", "D", "C", "G", "E", "R"].contains(action) else {
            return nil
        }

        return String(parts[1])
    }

    private func checkoutStatusMessage(from line: String) -> String {
        if let path = currentCheckoutPath(from: line) {
            return appLocalizer.string("checkout.current_path", path)
        }

        if line.localizedCaseInsensitiveContains("checked out revision") ||
            line.localizedCaseInsensitiveContains("at revision") {
            return appLocalizer.string("checkout.completed_line", line)
        }

        return line
    }
}

// MARK: - Toast

struct ToastView: View {
    let message: String
    let type: ToastType

    enum ToastType {
        case success, error, info

        var color: Color {
            switch self {
            case .success: return .green
            case .error: return .red
            case .info: return .blue
            }
        }

        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "exclamationmark.circle.fill"
            case .info: return "info.circle.fill"
            }
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: type.icon)
                .foregroundColor(type.color)

            Text(message)
                .font(.subheadline)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.windowBackgroundColor))
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        .cornerRadius(8)
        .padding(.top, 20)
    }
}
