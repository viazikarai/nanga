import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(NangaAppModel.self) private var appModel
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appearanceMode") private var appearanceModeRaw = AppearanceMode.system.rawValue
    @State private var isImportingProjectRoot = false
    @FocusState private var focusedInput: InputField?
    @State private var selectionHeroVisible = false
    @State private var selectionCloudDrift = false
    @State private var selectionBackgroundPulse = false

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

        Group {
            if appModel.isAgentSelectionLocked, let selectedAgent = appModel.selectedAgentConnection {
                lockedWorkspace(agent: selectedAgent, project: project, iteration: iteration)
            } else {
                agentSelectionView
            }
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

    private var agentSelectionView: some View {
        ZStack {
            theme.baseBackground
                .ignoresSafeArea()

            selectionBackgroundGlow

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    appearanceControl
                }
                .padding(.horizontal, 36)
                .padding(.top, 30)

                Spacer()

                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("NANGA")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(theme.cyan)
                            .opacity(selectionHeroVisible ? 1 : 0)
                            .offset(y: selectionHeroVisible ? 0 : 8)
                        Text("Nanga your trusted anchor")
                            .font(.system(size: 38, weight: .black))
                            .foregroundStyle(theme.primaryText)
                            .opacity(selectionHeroVisible ? 1 : 0)
                            .offset(y: selectionHeroVisible ? 0 : 14)
                        Text("Pick one agent. Lock in. Then work inside that agent only.")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(theme.secondaryText)
                            .opacity(selectionHeroVisible ? 1 : 0)
                            .offset(y: selectionHeroVisible ? 0 : 18)
                    }

                    HStack(alignment: .top, spacing: 18) {
                        ForEach(Array(appModel.agentConnections.enumerated()), id: \.element.id) { index, connection in
                            cleanAgentButton(connection: connection)
                                .opacity(selectionHeroVisible ? 1 : 0)
                                .offset(y: selectionHeroVisible ? 0 : 22)
                                .animation(
                                    .spring(response: 0.7, dampingFraction: 0.86)
                                        .delay(0.08 * Double(index + 1)),
                                    value: selectionHeroVisible
                                )
                        }
                    }

                    Text("SELECT YOUR AGENT")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.secondaryText)
                        .opacity(selectionHeroVisible ? 1 : 0)
                        .offset(y: selectionHeroVisible ? 0 : 12)
                }
                .frame(maxWidth: 760, alignment: .leading)
                .padding(36)
                .background(theme.heroPanelBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(theme.heroPanelStroke, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: theme.heroShadow, radius: 28, x: 0, y: 18)
                .padding(.horizontal, 32)
                .scaleEffect(selectionHeroVisible ? 1 : 0.985)
                .opacity(selectionHeroVisible ? 1 : 0.92)

                Spacer()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.82, dampingFraction: 0.88)) {
                selectionHeroVisible = true
            }

            guard !selectionCloudDrift, !selectionBackgroundPulse else { return }
            selectionCloudDrift = true
            selectionBackgroundPulse = true
        }
    }

    private func lockedWorkspace(agent: AgentConnection, project: NangaProject, iteration: IterationState) -> some View {
        VStack(spacing: 0) {
            lockedWorkspaceHeader(agent: agent, project: project)
            Divider()
                .overlay(theme.border)

            mainWorkspace(iteration: iteration)
        }
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

    private func lockedWorkspaceHeader(agent: AgentConnection, project: NangaProject) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(agent.runtimeName.uppercased())
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(theme.cyanGlow)
                        consoleBadge("CONNECTED", tint: theme.cyanGlow)
                    }

                    Text("Nanga your trusted anchor")
                        .font(.system(size: 26, weight: .black))
                        .foregroundStyle(theme.primaryText)

                    Text("Anchor the task. Preserve the signal. Hand off only what matters.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 10) {
                    if !appModel.availableAgentModels.isEmpty {
                        Picker("", selection: Binding(
                            get: { appModel.selectedAgentModelID },
                            set: { appModel.selectAgentModel(id: $0) }
                        )) {
                            ForEach(appModel.availableAgentModels) { model in
                                Text(model.displayName).tag(model.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 156)
                    }

                    Button("Change Agent") {
                        appModel.unlockAgentSelection()
                    }
                    .buttonStyle(ConsoleButtonStyle(tint: theme.gold))
                    .frame(width: 140)
                }
            }

            HStack(spacing: 10) {
                consoleBadge(project.name.uppercased(), tint: theme.gold)
                consoleBadge(agent.runtimeName.uppercased(), tint: theme.cyan)
                consoleBadge(agent.status.label.uppercased(), tint: agent.statusTint(in: theme))
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(theme.sidebarBackground)
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
                    if let selectedAgent = appModel.selectedAgentConnection {
                        consoleBadge("\(selectedAgent.runtimeName.uppercased()) CONNECTED", tint: appModel.isAgentSelectionLocked ? theme.cyanGlow : theme.cyan)
                        consoleBadge(selectedAgent.status.label.uppercased(), tint: selectedAgent.statusTint(in: theme))
                    }
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

    private var appearanceControl: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("APPEARANCE")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(theme.secondaryText)

            Picker("", selection: appearanceModeBinding) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 210)
        }
    }

    private func cleanAgentButton(connection: AgentConnection) -> some View {
        Button {
            appModel.lockSelectedAgentRuntime(id: connection.runtimeID)
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    agentLogo(for: connection)
                    Spacer()
                    Text(connection.status.label.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(connection.statusTint(in: theme))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(connection.runtimeName)
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(theme.primaryText)

                    Text(agentButtonSubtitle(for: connection))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
            .background(theme.agentButtonBackground(connection: connection))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(theme.agentButtonStroke(connection: connection), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: theme.agentButtonShadow(connection: connection), radius: 16, x: 0, y: 10)
        }
        .buttonStyle(.plain)
        .disabled(!connection.canExecute)
        .opacity(connection.canExecute ? 1 : 0.78)
        .offset(y: selectionCloudDrift ? -4 : 4)
        .animation(
            .easeInOut(duration: 3.2).repeatForever(autoreverses: true),
            value: selectionCloudDrift
        )
    }

    private func agentButtonSubtitle(for connection: AgentConnection) -> String {
        switch connection.status {
        case .connected:
            "Ready in this workspace."
        case .available:
            "Installed and ready to attach."
        case .unavailable:
            "Not installed on this machine."
        }
    }

    private func agentLogo(for connection: AgentConnection) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.logoPlateBackground(connection: connection))
                .frame(width: 52, height: 52)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(theme.logoPlateStroke(connection: connection), lineWidth: 1)
                )

            switch connection.runtimeID {
            case "codex":
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(connection.statusTint(in: theme))
            case "claude-code":
                Text("AI")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(connection.statusTint(in: theme))
            case "cursor":
                Image(systemName: "cursorarrow.motionlines")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(connection.statusTint(in: theme))
            default:
                Image(systemName: "cloud.fill")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(connection.statusTint(in: theme))
            }
        }
        .shadow(color: theme.agentButtonShadow(connection: connection), radius: 10, x: 0, y: 4)
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

    private var selectionBackgroundGlow: some View {
        ZStack {
            Circle()
                .fill(theme.cyanGlow.opacity(activeColorScheme == .dark ? 0.14 : 0.10))
                .frame(width: 420, height: 420)
                .blur(radius: 38)
                .offset(x: selectionBackgroundPulse ? -280 : -220, y: selectionBackgroundPulse ? -220 : -170)

            Circle()
                .fill(theme.gold.opacity(activeColorScheme == .dark ? 0.08 : 0.06))
                .frame(width: 320, height: 320)
                .blur(radius: 32)
                .offset(x: selectionBackgroundPulse ? 310 : 250, y: selectionBackgroundPulse ? 200 : 150)
        }
        .ignoresSafeArea()
        .animation(
            .easeInOut(duration: 6.0).repeatForever(autoreverses: true),
            value: selectionBackgroundPulse
        )
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
                agentRuntimeRegistry: AgentRuntimeRegistry()
            )
        )
}

private extension AgentConnection {
    func statusTint(in theme: ConsoleTheme) -> Color {
        switch status {
        case .connected:
            theme.cyan
        case .available:
            theme.gold
        case .unavailable:
            theme.secondaryText
        }
    }
}

private struct ConsoleTheme {
    let isDarkMode: Bool
    let baseBackground: Color
    let sidebarBackground: Color
    let panelBackground: Color
    let raisedBackground: Color
    let inputBackground: Color
    let focusedInputBackground: Color
    let selectionBackground: Color
    let border: Color
    let agentPanelBackground: Color
    let primaryText: Color
    let secondaryText: Color
    let placeholderText: Color
    let cyan: Color
    let cyanGlow: Color
    let cyanMuted: Color
    let gold: Color
    let shadow: Color
    let heroPanelBackground: Color
    let heroPanelStroke: Color
    let heroShadow: Color

    init(colorScheme: ColorScheme) {
        isDarkMode = colorScheme == .dark
        cyan = Color(red: 0.0, green: 0.56, blue: 0.70)
        cyanGlow = Color(red: 0.39, green: 0.90, blue: 1.0)
        cyanMuted = Color(red: 0.12, green: 0.47, blue: 0.58)
        gold = Color(red: 0.71, green: 0.50, blue: 0.16)

        if colorScheme == .dark {
            baseBackground = Color(red: 0.03, green: 0.05, blue: 0.09)
            sidebarBackground = Color(red: 0.04, green: 0.06, blue: 0.10)
            panelBackground = Color(red: 0.05, green: 0.08, blue: 0.13)
            raisedBackground = Color(red: 0.07, green: 0.10, blue: 0.16)
            agentPanelBackground = Color(red: 0.04, green: 0.09, blue: 0.14)
            inputBackground = Color(red: 0.04, green: 0.07, blue: 0.12)
            focusedInputBackground = Color(red: 0.05, green: 0.10, blue: 0.17)
            selectionBackground = Color(red: 0.05, green: 0.14, blue: 0.18)
            border = Color(red: 0.16, green: 0.22, blue: 0.30)
            primaryText = Color(red: 0.86, green: 0.92, blue: 0.97)
            secondaryText = Color(red: 0.54, green: 0.63, blue: 0.72)
            placeholderText = Color(red: 0.36, green: 0.49, blue: 0.60)
            shadow = Color(red: 0.0, green: 0.9, blue: 1.0).opacity(0.08)
            heroPanelBackground = Color(red: 0.05, green: 0.08, blue: 0.13).opacity(0.92)
            heroPanelStroke = cyan.opacity(0.30)
            heroShadow = cyanGlow.opacity(0.10)
        } else {
            baseBackground = Color(red: 0.95, green: 0.97, blue: 0.99)
            sidebarBackground = Color(red: 0.92, green: 0.95, blue: 0.98)
            panelBackground = Color(red: 0.98, green: 0.99, blue: 1.0)
            raisedBackground = Color(red: 0.95, green: 0.97, blue: 0.99)
            agentPanelBackground = Color(red: 0.90, green: 0.96, blue: 0.99)
            inputBackground = Color(red: 0.97, green: 0.98, blue: 1.0)
            focusedInputBackground = Color(red: 0.90, green: 0.96, blue: 0.99)
            selectionBackground = Color(red: 0.85, green: 0.94, blue: 0.97)
            border = Color(red: 0.79, green: 0.85, blue: 0.90)
            primaryText = Color(red: 0.11, green: 0.16, blue: 0.22)
            secondaryText = Color(red: 0.35, green: 0.44, blue: 0.52)
            placeholderText = Color(red: 0.50, green: 0.58, blue: 0.64)
            shadow = Color(red: 0.0, green: 0.22, blue: 0.36).opacity(0.06)
            heroPanelBackground = Color(red: 0.98, green: 0.99, blue: 1.0).opacity(0.96)
            heroPanelStroke = cyan.opacity(0.24)
            heroShadow = Color(red: 0.10, green: 0.36, blue: 0.54).opacity(0.08)
        }
    }

    func cloudGradient(connection: AgentConnection) -> LinearGradient {
        switch connection.status {
        case .connected:
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.15, blue: 0.23),
                    Color(red: 0.04, green: 0.09, blue: 0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .available:
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.10, blue: 0.14),
                    Color(red: 0.07, green: 0.08, blue: 0.13)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .unavailable:
            LinearGradient(
                colors: [raisedBackground, panelBackground],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    func agentButtonBackground(connection: AgentConnection) -> Color {
        switch connection.status {
        case .connected:
            colorSchemeAware(
                dark: Color(red: 0.07, green: 0.12, blue: 0.18),
                light: Color(red: 0.90, green: 0.97, blue: 1.0)
            )
        case .available:
            colorSchemeAware(
                dark: Color(red: 0.09, green: 0.09, blue: 0.13),
                light: Color(red: 0.98, green: 0.97, blue: 0.94)
            )
        case .unavailable:
            raisedBackground
        }
    }

    func agentButtonStroke(connection: AgentConnection) -> Color {
        switch connection.status {
        case .connected:
            cyanGlow.opacity(0.42)
        case .available:
            gold.opacity(0.30)
        case .unavailable:
            border
        }
    }

    func agentButtonShadow(connection: AgentConnection) -> Color {
        switch connection.status {
        case .connected:
            cyanGlow.opacity(0.16)
        case .available:
            gold.opacity(0.08)
        case .unavailable:
            shadow
        }
    }

    func logoPlateBackground(connection: AgentConnection) -> Color {
        switch connection.status {
        case .connected:
            colorSchemeAware(
                dark: Color(red: 0.04, green: 0.12, blue: 0.18),
                light: Color(red: 0.87, green: 0.96, blue: 0.99)
            )
        case .available:
            colorSchemeAware(
                dark: Color(red: 0.11, green: 0.10, blue: 0.14),
                light: Color(red: 0.99, green: 0.97, blue: 0.92)
            )
        case .unavailable:
            raisedBackground
        }
    }

    func logoPlateStroke(connection: AgentConnection) -> Color {
        switch connection.status {
        case .connected:
            cyan.opacity(0.42)
        case .available:
            gold.opacity(0.34)
        case .unavailable:
            border
        }
    }

    func cloudStroke(connection: AgentConnection) -> Color {
        switch connection.status {
        case .connected:
            cyanGlow.opacity(0.55)
        case .available:
            gold.opacity(0.42)
        case .unavailable:
            border
        }
    }

    func cloudShadow(connection: AgentConnection) -> Color {
        switch connection.status {
        case .connected:
            cyanGlow.opacity(0.18)
        case .available:
            gold.opacity(0.10)
        case .unavailable:
            shadow
        }
    }

    private func colorSchemeAware(dark: Color, light: Color) -> Color {
        isDarkMode ? dark : light
    }
}

private struct AgentCloudShape: Shape {
    func path(in rect: CGRect) -> Path {
        let baseY = rect.minY + rect.height * 0.34
        let left = CGRect(x: rect.minX + rect.width * 0.08, y: baseY, width: rect.width * 0.30, height: rect.height * 0.38)
        let center = CGRect(x: rect.minX + rect.width * 0.26, y: rect.minY + rect.height * 0.10, width: rect.width * 0.38, height: rect.height * 0.50)
        let right = CGRect(x: rect.minX + rect.width * 0.52, y: baseY + rect.height * 0.01, width: rect.width * 0.24, height: rect.height * 0.30)
        let base = CGRect(x: rect.minX + rect.width * 0.16, y: rect.minY + rect.height * 0.42, width: rect.width * 0.66, height: rect.height * 0.30)

        var path = Path(ellipseIn: left)
        path.addPath(Path(ellipseIn: center))
        path.addPath(Path(ellipseIn: right))
        path.addRoundedRect(in: base, cornerSize: CGSize(width: rect.height * 0.14, height: rect.height * 0.14))

        return path
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
