import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(NangaAppModel.self) private var appModel
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appearanceMode") private var appearanceModeRaw = AppearanceMode.system.rawValue
    @State private var isImportingProjectRoot = false
    @FocusState private var focusedInput: InputField?

    private let sidebarWidth: CGFloat = 280
    private let panelSpacing: CGFloat = 16

    private enum InputField {
        case title
        case detail
    }

    private enum AppearanceMode: String, CaseIterable, Identifiable {
        case system
        case light
        case dark

        var id: String { rawValue }

        var title: String {
            switch self {
            case .system: "System"
            case .light: "Light"
            case .dark: "Dark"
            }
        }

        var preferredColorScheme: ColorScheme? {
            switch self {
            case .system: nil
            case .light: .light
            case .dark: .dark
            }
        }
    }

    var body: some View {
        let project = appModel.selectedProject
        let iteration = appModel.currentIteration

        HStack(spacing: 0) {
            sidebar(project: project, iteration: iteration)
                .frame(width: sidebarWidth)

            Divider()
                .overlay(theme.border)

            mainWorkspace(iteration: iteration)
        }
        .background(theme.baseBackground)
        .preferredColorScheme(appearanceMode.preferredColorScheme)
        .fileImporter(
            isPresented: $isImportingProjectRoot,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false,
            onCompletion: handleProjectImport
        )
    }

    private func sidebar(project: NangaProject, iteration: IterationState) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("NANGA")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(theme.cyan)
                    Text("Agent workflow console")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(theme.primaryText)
                    Text("Iteration-first workspace for scoped execution.")
                        .font(.system(size: 13))
                        .foregroundStyle(theme.secondaryText)
                }

                sidebarSection("Projects") {
                    VStack(alignment: .leading, spacing: 10) {
                        sidebarValue(label: "Active", value: project.name)
                        sidebarValue(label: "Repository", value: project.repositoryName)
                        sidebarValue(label: "Root", value: appModel.projectRootPath)

                        Button(appModel.hasProjectRoot ? "Change Folder" : "Open Folder") {
                            isImportingProjectRoot = true
                        }
                        .buttonStyle(ConsoleButtonStyle(tint: theme.cyan))
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Appearance".uppercased())
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(theme.gold)

                    Picker("", selection: appearanceModeBinding) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                sidebarSection("Current Task") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(iteration.task.title.isEmpty ? "No active task title" : iteration.task.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(theme.primaryText)
                            .lineLimit(2)

                        Text(iteration.task.detail.isEmpty ? "No execution detail yet." : iteration.task.detail)
                            .font(.system(size: 12))
                            .foregroundStyle(theme.secondaryText)
                            .lineLimit(4)

                        HStack(spacing: 8) {
                            consoleBadge(iteration.task.isReadyForExecution ? "READY" : "INPUT", tint: iteration.task.isReadyForExecution ? theme.cyan : theme.gold)
                            consoleBadge("\(appModel.selectedFileCount) FILES", tint: theme.cyanMuted)
                        }
                    }
                }

                sidebarSection("Iteration History") {
                    VStack(alignment: .leading, spacing: 10) {
                        if project.iterationHistory.isEmpty {
                            Text("No saved iterations yet.")
                                .font(.system(size: 12))
                                .foregroundStyle(theme.secondaryText)
                        } else {
                            ForEach(project.iterationHistory.prefix(6)) { record in
                                HStack(alignment: .top, spacing: 8) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(record.label)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(theme.primaryText)
                                            .lineLimit(1)
                                        Text(record.savedAt, format: .dateTime.month().day().hour().minute())
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(theme.secondaryText)
                                    }

                                    Spacer(minLength: 8)

                                    Button {
                                        appModel.deleteIterationCheckpoint(id: record.id)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 11, weight: .semibold))
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(theme.secondaryText)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(theme.panelBackground)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.border, lineWidth: 1))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(theme.sidebarBackground)
    }

    private func mainWorkspace(iteration: IterationState) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: panelSpacing) {
                topCommandSurface(iteration: iteration)

                HStack(alignment: .top, spacing: panelSpacing) {
                    signalPanel(signal: iteration.signal)
                    scopePanel(iteration: iteration)
                }

                outputPanel(iteration: iteration)
            }
            .padding(20)
        }
        .background(theme.baseBackground)
    }

    private func topCommandSurface(iteration: IterationState) -> some View {
        consolePanel(title: "Task Input", symbol: "terminal") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 12) {
                        glowingInputShell(title: "Task", isFocused: focusedInput == .title) {
                            TextField(
                                "",
                                text: Binding(
                                    get: { appModel.currentTaskTitle },
                                    set: { appModel.currentTaskTitle = $0 }
                                ),
                                prompt: Text("State the current task").foregroundStyle(theme.placeholderText)
                            )
                            .textFieldStyle(.plain)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(theme.primaryText)
                            .focused($focusedInput, equals: .title)
                        }

                        glowingInputShell(title: "Execution Intent", isFocused: focusedInput == .detail) {
                            ZStack(alignment: .topLeading) {
                                if appModel.currentTaskDetail.isEmpty {
                                    Text("Describe the exact outcome for this iteration")
                                        .font(.system(size: 13))
                                        .foregroundStyle(theme.placeholderText)
                                        .padding(.top, 2)
                                        .allowsHitTesting(false)
                                }

                                TextEditor(text: Binding(
                                    get: { appModel.currentTaskDetail },
                                    set: { appModel.currentTaskDetail = $0 }
                                ))
                                .scrollContentBackground(.hidden)
                                .font(.system(size: 13))
                                .foregroundColor(theme.primaryText)
                                .frame(minHeight: 110)
                                .focused($focusedInput, equals: .detail)
                            }
                        }
                    }

                    VStack(alignment: .trailing, spacing: 10) {
                        Button("Open Folder") {
                            isImportingProjectRoot = true
                        }
                        .buttonStyle(ConsoleButtonStyle(tint: theme.gold))

                        Button("Discover") {
                            appModel.discoverCandidateFiles()
                        }
                        .buttonStyle(ConsoleButtonStyle(tint: theme.cyanMuted))
                        .disabled(!appModel.canDiscoverCandidateFiles)

                        Button("Run") {
                            Task {
                                await appModel.runIteration()
                            }
                        }
                        .buttonStyle(ConsoleButtonStyle(tint: theme.cyan))
                        .disabled(!appModel.canRunIteration)
                    }
                    .frame(width: 132)
                }

                HStack(spacing: 10) {
                    consoleBadge(appModel.hasProjectRoot ? "PROJECT ONLINE" : "PROJECT REQUIRED", tint: appModel.hasProjectRoot ? theme.cyan : theme.gold)
                    consoleBadge(iteration.task.isReadyForExecution ? "TASK READY" : "TASK INCOMPLETE", tint: iteration.task.isReadyForExecution ? theme.cyan : theme.gold)
                    consoleBadge("\(iteration.candidateFiles.count) CANDIDATES", tint: theme.cyanMuted)
                    consoleBadge("\(appModel.selectedFileCount) IN SCOPE", tint: theme.cyanMuted)
                }
            }
        }
    }

    private func signalPanel(signal: [SignalItem]) -> some View {
        consolePanel(title: "Signal", symbol: "scope") {
            VStack(alignment: .leading, spacing: 10) {
                if signal.isEmpty {
                    consoleEmpty("Signal will appear after discovery and refresh.")
                } else {
                    ForEach(signal) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.kind.rawValue.uppercased())
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(theme.cyan)
                            Text(item.title)
                                .font(.system(size: 13))
                                .foregroundStyle(theme.primaryText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(theme.raisedBackground)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.border, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func scopePanel(iteration: IterationState) -> some View {
        consolePanel(title: "Execution Scope", symbol: "square.stack.3d.up") {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("Project Root")
                    scopeRow(appModel.projectRootPath, symbol: "folder")
                }

                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("Candidate Files")
                    if iteration.candidateFiles.isEmpty {
                        consoleEmpty("Discover files to populate scope.")
                    } else {
                        ForEach(iteration.candidateFiles) { candidate in
                            Toggle(isOn: Binding(
                                get: { candidate.isSelected },
                                set: { appModel.setCandidateFileSelection(id: candidate.id, isSelected: $0) }
                            )) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(candidate.path)
                                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                                            .foregroundStyle(theme.primaryText)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                        Spacer()
                                        Text("S\(candidate.score)")
                                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(candidate.isSelected ? theme.cyan : theme.secondaryText)
                                    }
                                    Text(candidate.reason)
                                        .font(.system(size: 12))
                                        .foregroundStyle(theme.secondaryText)
                                        .lineLimit(2)
                                }
                            }
                            .toggleStyle(.checkbox)
                            .padding(12)
                            .background(candidate.isSelected ? theme.selectionBackground : theme.raisedBackground)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(candidate.isSelected ? theme.cyan.opacity(0.65) : theme.border, lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func outputPanel(iteration: IterationState) -> some View {
        consolePanel(title: "Output", symbol: "waveform.path.ecg") {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    outputBlock(
                        title: "Execution",
                        body: iteration.execution.headline,
                        detail: iteration.execution.detail,
                        tint: theme.cyan
                    )
                    outputBlock(
                        title: "Persistence",
                        body: appModel.persistenceStatus,
                        detail: appModel.projectFilePath,
                        tint: theme.gold
                    )
                }

                HStack(alignment: .top, spacing: 16) {
                    outputBlock(
                        title: "Selected Scope",
                        body: iteration.scope.files.isEmpty ? "No files selected" : iteration.scope.files.joined(separator: "\n"),
                        detail: iteration.carryForwardSummary,
                        tint: theme.cyanMuted,
                        monospaced: true
                    )
                    outputBlock(
                        title: "Next Iteration",
                        body: iteration.savedState.summary,
                        detail: iteration.savedState.carriedForwardItems.joined(separator: " • "),
                        tint: theme.gold
                    )
                }
            }
        }
    }

    private func consolePanel<Content: View>(title: String, symbol: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.cyan)
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.primaryText)
                Spacer()
            }
            content()
        }
        .padding(18)
        .background(theme.panelBackground)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(theme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: theme.shadow, radius: 14, x: 0, y: 6)
    }

    private func sidebarSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(theme.gold)
            content()
        }
    }

    private func sidebarValue(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(theme.secondaryText)
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(theme.primaryText)
                .lineLimit(2)
        }
    }

    private func outputBlock(title: String, body: String, detail: String, tint: Color, monospaced: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(tint)
            Text(body)
                .font(monospaced ? .system(size: 12, design: .monospaced) : .system(size: 13, weight: .medium))
                .foregroundStyle(theme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(detail)
                .font(.system(size: 12))
                .foregroundStyle(theme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(theme.raisedBackground)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func consoleEmpty(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(theme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(theme.raisedBackground)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func scopeRow(_ value: String, symbol: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 12))
                .foregroundStyle(theme.gold)
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(theme.primaryText)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(theme.raisedBackground)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(theme.gold)
    }

    private func consoleBadge(_ title: String, tint: Color) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.12))
            .overlay(RoundedRectangle(cornerRadius: 999).stroke(tint.opacity(0.35), lineWidth: 1))
            .clipShape(Capsule())
    }

    private func handleProjectImport(_ result: Result<[URL], any Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            appModel.importProjectRoot(from: url)
        case .failure(let error):
            appModel.persistenceStatus = "Failed to open project folder: \(error.localizedDescription)"
        }
    }

    private var theme: ConsoleTheme {
        ConsoleTheme(colorScheme: activeColorScheme)
    }

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRaw) ?? .system
    }

    private var appearanceModeBinding: Binding<AppearanceMode> {
        Binding(
            get: { appearanceMode },
            set: { appearanceModeRaw = $0.rawValue }
        )
    }

    private var activeColorScheme: ColorScheme {
        appearanceMode.preferredColorScheme ?? colorScheme
    }

    private func glowingInputShell<Content: View>(title: String, isFocused: Bool, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(theme.cyan)

            content()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(isFocused ? theme.focusedInputBackground : theme.inputBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isFocused ? theme.cyan.opacity(0.9) : theme.cyan.opacity(0.45), lineWidth: 1)
                )
                .shadow(color: theme.cyan.opacity(isFocused ? 0.28 : 0.16), radius: isFocused ? 16 : 10, x: 0, y: 0)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

}

#Preview {
    ContentView()
        .frame(width: 1440, height: 920)
        .environment(
            NangaAppModel(
                selectedProject: nil,
                projectStore: ProjectStore(
                    baseDirectoryURL: URL.temporaryDirectory.appending(path: "NangaPreview", directoryHint: .isDirectory)
                ),
                fileDiscoveryService: FileDiscoveryService(),
                executionPackageBuilder: ExecutionPackageBuilder(),
                agentRuntime: MockAgentRuntime()
            )
        )
}

private struct ConsoleTheme {
    let baseBackground: Color
    let sidebarBackground: Color
    let panelBackground: Color
    let raisedBackground: Color
    let inputBackground: Color
    let focusedInputBackground: Color
    let selectionBackground: Color
    let border: Color
    let primaryText: Color
    let secondaryText: Color
    let placeholderText: Color
    let cyan: Color
    let cyanMuted: Color
    let gold: Color
    let shadow: Color

    init(colorScheme: ColorScheme) {
        cyan = Color(red: 0.0, green: 0.56, blue: 0.70)
        cyanMuted = Color(red: 0.12, green: 0.47, blue: 0.58)
        gold = Color(red: 0.71, green: 0.50, blue: 0.16)

        if colorScheme == .dark {
            baseBackground = Color(red: 0.03, green: 0.05, blue: 0.09)
            sidebarBackground = Color(red: 0.04, green: 0.06, blue: 0.10)
            panelBackground = Color(red: 0.05, green: 0.08, blue: 0.13)
            raisedBackground = Color(red: 0.07, green: 0.10, blue: 0.16)
            inputBackground = Color(red: 0.04, green: 0.07, blue: 0.12)
            focusedInputBackground = Color(red: 0.05, green: 0.10, blue: 0.17)
            selectionBackground = Color(red: 0.05, green: 0.14, blue: 0.18)
            border = Color(red: 0.16, green: 0.22, blue: 0.30)
            primaryText = Color(red: 0.86, green: 0.92, blue: 0.97)
            secondaryText = Color(red: 0.54, green: 0.63, blue: 0.72)
            placeholderText = Color(red: 0.36, green: 0.49, blue: 0.60)
            shadow = Color(red: 0.0, green: 0.9, blue: 1.0).opacity(0.08)
        } else {
            baseBackground = Color(red: 0.95, green: 0.97, blue: 0.99)
            sidebarBackground = Color(red: 0.92, green: 0.95, blue: 0.98)
            panelBackground = Color(red: 0.98, green: 0.99, blue: 1.0)
            raisedBackground = Color(red: 0.95, green: 0.97, blue: 0.99)
            inputBackground = Color(red: 0.97, green: 0.98, blue: 1.0)
            focusedInputBackground = Color(red: 0.90, green: 0.96, blue: 0.99)
            selectionBackground = Color(red: 0.85, green: 0.94, blue: 0.97)
            border = Color(red: 0.79, green: 0.85, blue: 0.90)
            primaryText = Color(red: 0.11, green: 0.16, blue: 0.22)
            secondaryText = Color(red: 0.35, green: 0.44, blue: 0.52)
            placeholderText = Color(red: 0.50, green: 0.58, blue: 0.64)
            shadow = Color(red: 0.0, green: 0.22, blue: 0.36).opacity(0.06)
        }
    }
}

private struct ConsoleButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(tint.opacity(configuration.isPressed ? 0.22 : 0.14))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(tint.opacity(0.45), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: tint.opacity(configuration.isPressed ? 0.0 : 0.14), radius: 8, x: 0, y: 0)
    }
}
