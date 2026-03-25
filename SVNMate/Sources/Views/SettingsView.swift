import SwiftUI
import AppKit

private enum SettingsField: Hashable {
    case svnBinaryPath
}

struct SettingsView: View {
    @EnvironmentObject private var settingsController: SettingsController
    @Environment(\.appTheme) private var appTheme
    @Environment(\.appLocalizer) private var appLocalizer

    @State private var svnBinaryPathDraft = ""
    @State private var svnBinaryPathError: String?
    @FocusState private var focusedField: SettingsField?

    var body: some View {
        Form {
            generalSection
            timeoutsSection
            appearanceSection
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 640, height: 700)
        .onAppear {
            syncSVNBinaryPathDraft()
        }
        .onChange(of: settingsController.settings.svnBinaryPathOverride) { _ in
            syncSVNBinaryPathDraft()
        }
        .onChange(of: focusedField) { field in
            if field != .svnBinaryPath {
                applySVNBinaryPathDraftIfNeeded()
            }
        }
    }

    private var generalSection: some View {
        Section("settings.general") {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("settings.language")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Picker(
                        "",
                        selection: Binding(
                            get: { settingsController.settings.preferredLanguage },
                            set: { settingsController.updatePreferredLanguage($0) }
                        )
                    ) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(LocalizedStringKey(language.localizationKey))
                                .tag(language)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 220, alignment: .leading)

                    Text("settings.language.help")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack(alignment: .center, spacing: 12) {
                    TextField("settings.svn_binary.placeholder", text: $svnBinaryPathDraft)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .svnBinaryPath)
                        .onSubmit {
                            applySVNBinaryPathDraftIfNeeded()
                        }

                    Button("common.browse") {
                        selectSVNBinaryPath()
                    }

                    Button("settings.reset_auto_detect") {
                        settingsController.resetSVNBinaryPathOverride()
                        svnBinaryPathError = nil
                        syncSVNBinaryPathDraft()
                    }
                }

                Text("settings.svn_binary_help")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let svnBinaryPathError {
                    Text(svnBinaryPathError)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                effectiveBinaryPathView
            }
        }
    }

    private var effectiveBinaryPathView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("settings.effective_svn_binary")
                .font(.caption)
                .foregroundColor(.secondary)

            switch settingsController.effectiveSVNBinaryPathState() {
            case .resolved(let path):
                Text(path)
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
            case .unresolved(let message):
                Text(message)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.red)
                    .textSelection(.enabled)
            }
        }
    }

    private var timeoutsSection: some View {
        Section("settings.timeouts") {
            ForEach(AppTimeoutKey.allCases) { key in
                TimeoutSettingRow(timeoutKey: key)
            }
        }
    }

    private var appearanceSection: some View {
        Section("settings.appearance") {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("settings.accent_color")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    ColorTokenPicker(
                        selection: Binding(
                            get: { settingsController.settings.theme.accentColor },
                            set: { settingsController.updateAccentColor($0) }
                        )
                    )

                    RoundedRectangle(cornerRadius: 8)
                        .fill(appTheme.accentColor.opacity(0.18))
                        .frame(height: 36)
                        .overlay(
                            Text("settings.accent_preview")
                                .font(.caption)
                                .foregroundColor(appTheme.accentColor)
                        )
                }

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Text("settings.status_colors")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    ForEach(FileStatus.allCases, id: \.self) { status in
                        StatusColorRow(status: status)
                    }
                }

                HStack {
                    Spacer()
                    Button("common.restore_defaults") {
                        settingsController.restoreDefaults()
                        svnBinaryPathError = nil
                        syncSVNBinaryPathDraft()
                    }
                }
            }
        }
    }

    private func selectSVNBinaryPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = appLocalizer.string("settings.use_binary")
        panel.message = appLocalizer.string("settings.choose_executable")

        if panel.runModal() == .OK, let url = panel.url {
            svnBinaryPathDraft = url.path
            applySVNBinaryPathDraftIfNeeded()
        }
    }

    private func syncSVNBinaryPathDraft() {
        svnBinaryPathDraft = settingsController.settings.svnBinaryPathOverride ?? ""
    }

    private func applySVNBinaryPathDraftIfNeeded() {
        let currentValue = settingsController.settings.svnBinaryPathOverride ?? ""
        let normalizedDraft = svnBinaryPathDraft.trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalizedDraft != currentValue else {
            svnBinaryPathError = nil
            return
        }

        do {
            try settingsController.updateSVNBinaryPathOverride(normalizedDraft)
            svnBinaryPathError = nil
            syncSVNBinaryPathDraft()
        } catch {
            svnBinaryPathError = error.localizedDescription
        }
    }
}

private struct TimeoutSettingRow: View {
    @EnvironmentObject private var settingsController: SettingsController
    @Environment(\.appLocalizer) private var appLocalizer

    let timeoutKey: AppTimeoutKey

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(timeoutKey.titleKey))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(LocalizedStringKey(timeoutKey.helpTextKey))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                TextField(
                    "settings.timeout.placeholder",
                    value: Binding(
                        get: { settingsController.timeoutValue(for: timeoutKey) },
                        set: { settingsController.updateTimeout($0, for: timeoutKey) }
                    ),
                    format: .number
                )
                .frame(width: 90)
                .multilineTextAlignment(.trailing)

                Text("settings.timeout.seconds_suffix")
                    .foregroundColor(.secondary)

                Stepper(
                    "",
                    value: Binding(
                        get: { settingsController.timeoutValue(for: timeoutKey) },
                        set: { settingsController.updateTimeout($0, for: timeoutKey) }
                    ),
                    in: timeoutKey.range
                )
                .labelsHidden()
            }

            Text(appLocalizer.string("settings.timeout.range", timeoutKey.range.lowerBound, timeoutKey.range.upperBound))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct StatusColorRow: View {
    @EnvironmentObject private var settingsController: SettingsController
    @Environment(\.appTheme) private var appTheme

    let status: FileStatus

    var body: some View {
        HStack {
            HStack(spacing: 10) {
                Circle()
                    .fill(appTheme.color(for: status))
                    .frame(width: 10, height: 10)

                Text(LocalizedStringKey(status.localizationKey))
                    .font(.system(size: 13, weight: .medium))
            }

            Spacer()

            ColorTokenPicker(
                selection: Binding(
                    get: { settingsController.statusColorToken(for: status) },
                    set: { settingsController.updateStatusColor($0, for: status) }
                )
            )
            .frame(width: 180)
        }
    }
}

private struct ColorTokenPicker: View {
    @Binding var selection: AppColorToken

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(AppColorToken.allCases) { token in
                Text(LocalizedStringKey(token.localizationKey))
                    .tag(token)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
    }
}
