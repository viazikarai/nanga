import Foundation
import Observation

@Observable
@MainActor
final class NangaAppModel {
    @ObservationIgnored private let projectStore: ProjectStore
    @ObservationIgnored private var activeProjectRootURL: URL?
    @ObservationIgnored private let fileDiscoveryService: FileDiscoveryService
    @ObservationIgnored private let executionPackageBuilder: ExecutionPackageBuilder
    @ObservationIgnored private let agentRuntimeRegistry: AgentRuntimeRegistry

    var selectedProject: NangaProject
    var persistenceStatus: String
    var agentConnections: [AgentConnection]
    var selectedAgentRuntimeID: String
    var selectedAgentModelID: String
    var isAgentSelectionLocked: Bool
    var liveAgentEvents: [AgentRuntimeEvent]
    var lastRuntimeError: String?

    convenience init() {
        self.init(
            selectedProject: nil,
            projectStore: ProjectStore(),
            fileDiscoveryService: FileDiscoveryService(),
            executionPackageBuilder: ExecutionPackageBuilder(),
            agentRuntimeRegistry: AgentRuntimeRegistry()
        )
    }

    init(
        selectedProject: NangaProject?,
        projectStore: ProjectStore,
        fileDiscoveryService: FileDiscoveryService,
        executionPackageBuilder: ExecutionPackageBuilder,
        agentRuntimeRegistry: AgentRuntimeRegistry
    ) {
        self.projectStore = projectStore
        self.fileDiscoveryService = fileDiscoveryService
        self.executionPackageBuilder = executionPackageBuilder
        self.agentRuntimeRegistry = agentRuntimeRegistry
        self.agentConnections = []
        self.selectedAgentRuntimeID = selectedProject?.selectedAgentRuntimeID ?? agentRuntimeRegistry.runtimes.first?.id ?? ""
        self.selectedAgentModelID = ""
        self.isAgentSelectionLocked = selectedProject?.isAgentSelectionLocked ?? false
        self.liveAgentEvents = []
        self.lastRuntimeError = nil
        self.persistenceStatus = ""

        if let selectedProject {
            self.selectedProject = selectedProject
            self.selectedAgentModelID = selectedProject.selectedAgentModelID
            self.persistenceStatus = "Loaded project from injected state."
            restoreProjectRootAccess()
            persistProject()
            return
        }

        if let persistedProject = try? projectStore.loadProject() {
            self.selectedProject = persistedProject
            self.selectedAgentRuntimeID = persistedProject.selectedAgentRuntimeID
            self.selectedAgentModelID = persistedProject.selectedAgentModelID
            self.isAgentSelectionLocked = persistedProject.isAgentSelectionLocked
            self.persistenceStatus = "Loaded saved iteration state from disk."
            restoreProjectRootAccess()
        } else {
            let sampleProject = NangaProject.sample
            self.selectedProject = sampleProject
            self.selectedAgentRuntimeID = sampleProject.selectedAgentRuntimeID
            self.selectedAgentModelID = sampleProject.selectedAgentModelID
            self.isAgentSelectionLocked = sampleProject.isAgentSelectionLocked
            self.persistenceStatus = "Started with a sample project until a saved project exists."
            persistProject()
        }

        refreshAgentConnections()
    }

    var currentIteration: IterationState {
        get { selectedProject.currentIteration }
        set {
            var iteration = newValue
            iteration.scope.files = iteration.candidateFiles
                .filter(\.isSelected)
                .map(\.path)

            mutateProject { project in
                project.currentIteration = iteration
            }
            persistProject()
        }
    }

    var currentTaskTitle: String {
        get { currentIteration.task.title }
        set {
            mutateCurrentIteration { iteration in
                iteration.task.title = newValue
            }
            handleTaskDraftChange(statusMessage: "Updated current task title.")
        }
    }

    var currentTaskDetail: String {
        get { currentIteration.task.detail }
        set {
            mutateCurrentIteration { iteration in
                iteration.task.detail = newValue
            }
            handleTaskDraftChange(statusMessage: "Updated current task detail.")
        }
    }

    var projectFilePath: String {
        projectStore.projectFileURL.path(percentEncoded: false)
    }

    var projectRootPath: String {
        selectedProject.rootFolder?.path ?? "No folder selected"
    }

    var hasProjectRoot: Bool {
        selectedProject.rootFolder != nil
    }

    var iterationHistory: [IterationRecord] {
        selectedProject.iterationHistory.sorted { $0.savedAt > $1.savedAt }
    }

    var selectedFileCount: Int {
        currentIteration.candidateFiles.filter(\.isSelected).count
    }

    var selectedAgentConnection: AgentConnection? {
        agentConnections.first { $0.runtimeID == selectedAgentRuntimeID }
    }

    var availableAgentModels: [AgentModel] {
        selectedAgentConnection?.models ?? []
    }

    var selectedAgentModel: AgentModel? {
        availableAgentModels.first { $0.id == selectedAgentModelID } ?? availableAgentModels.first
    }

    var canDiscoverCandidateFiles: Bool {
        hasProjectRoot && currentIteration.task.isReadyForExecution
    }

    var canRunIteration: Bool {
        canDiscoverCandidateFiles && selectedFileCount > 0 && isAgentSelectionLocked && (selectedAgentConnection?.canExecute == true)
    }

    var agentFeedText: String {
        if liveAgentEvents.isEmpty {
            return "No agent activity yet."
        }

        return liveAgentEvents.map(\.message).joined(separator: "\n")
    }

    var selectedAgentSessionID: String? {
        activeSessionID(for: selectedAgentRuntimeID)
    }

    var selectedRuntimeName: String {
        selectedAgentConnection?.runtimeName ?? "Agent"
    }

    var selectedRuntimeInstallState: String {
        guard let connection = selectedAgentConnection else {
            return "Unknown"
        }
        return connection.isCLIInstalled ? "Installed" : "Not Installed"
    }

    var selectedRuntimeAuthenticationState: String {
        selectedAgentConnection?.authenticationStatus.label ?? "Unknown"
    }

    var requiresSelectedRuntimeLogin: Bool {
        selectedAgentConnection?.authenticationStatus == .loginRequired
    }

    var selectedRuntimeAttachState: String {
        guard let connection = selectedAgentConnection else {
            return "Unavailable"
        }
        if selectedAgentSessionID != nil {
            return "Attached"
        }
        if connection.canExecute {
            return "Ready to Attach"
        }
        return "Blocked"
    }

    var selectedRuntimeWorkspaceMarkers: [String] {
        selectedAgentConnection?.workspaceMarkers ?? []
    }

    var latestAgentEventMessage: String {
        liveAgentEvents.last?.message ?? "No live runtime events yet."
    }

    var canLaunchCodexLogin: Bool {
        selectedAgentRuntimeID == "codex" && (selectedAgentConnection?.isCLIInstalled == true)
    }

    func saveIterationCheckpoint() {
        guard currentIteration.task.isReadyForExecution else {
            persistenceStatus = "Checkpoint requires a task title and execution detail."
            return
        }

        let record = IterationRecord(
            label: currentIteration.task.title,
            savedAt: .now,
            summary: currentIteration.savedState.summary,
            carriedForwardItems: currentIteration.savedState.carriedForwardItems,
            scopedFiles: Array(currentIteration.scope.files.prefix(5))
        )

        mutateProject { project in
            project.iterationHistory.insert(record, at: 0)
            project.iterationHistory = Array(project.iterationHistory.prefix(20))
        }
        persistProject(statusMessage: "Saved iteration checkpoint to history.")
    }

    func deleteIterationCheckpoint(id: UUID) {
        mutateProject { project in
            project.iterationHistory.removeAll { $0.id == id }
        }
        persistProject(statusMessage: "Deleted iteration checkpoint.")
    }

    func importProjectRoot(from url: URL) {
        stopAccessingCurrentProjectRootIfNeeded()

        let folderReference = ProjectFolderReference.make(from: url)
        mutateProject { project in
            project.rootFolder = folderReference
            project.name = url.lastPathComponent
            project.repositoryName = url.lastPathComponent

            if !project.currentIteration.scope.folders.contains(folderReference.path) {
                project.currentIteration.scope.folders.insert(folderReference.path, at: 0)
            }
        }

        let bookmarkMessage = folderReference.bookmarkData == nil
            ? " Folder path saved without a security-scoped bookmark."
            : ""

        activeProjectRootURL = folderReference.resolvedURL
        _ = activeProjectRootURL?.startAccessingSecurityScopedResource()
        refreshAgentConnections()
        persistProject(statusMessage: "Opened project folder and saved it into project state.\(bookmarkMessage)")
    }

    func selectAgentRuntime(id: String) {
        selectedAgentRuntimeID = id
        syncSelectedAgentModel()
        persistAgentSelection(statusMessage: "Updated selected agent.")
    }

    func lockSelectedAgentRuntime(id: String) async {
        selectedAgentRuntimeID = id
        syncSelectedAgentModel()
        isAgentSelectionLocked = true
        resetLiveAgentEvents()
        clearRuntimeError()
        if selectedProject.agentSession?.runtimeID != id {
            mutateProject { project in
                project.agentSession = nil
            }
        }
        do {
            try await connectSelectedAgentIfNeeded()
            persistAgentSelection(statusMessage: "Locked the project onto the selected agent.")
        } catch {
            setRuntimeError(error.localizedDescription)
            persistAgentSelection(statusMessage: "Failed to attach to the selected agent: \(error.localizedDescription)")
        }
    }

    func unlockAgentSelection() {
        isAgentSelectionLocked = false
        persistAgentSelection(statusMessage: "Unlocked agent selection.")
    }

    func selectAgentModel(id: String) {
        selectedAgentModelID = id
        persistAgentSelection(statusMessage: "Updated selected agent model.")
    }

    func linkSelectedAgentNow() async {
        guard isAgentSelectionLocked else {
            persistenceStatus = "Select and lock an agent before linking."
            return
        }

        guard hasProjectRoot else {
            persistenceStatus = "Select a project folder before linking."
            return
        }

        resetLiveAgentEvents()
        clearRuntimeError()

        do {
            try await connectSelectedAgentIfNeeded(forceReconnect: false)
            if let sessionID = selectedAgentSessionID {
                persistenceStatus = "Nanga linked to \(selectedAgentConnection?.runtimeName ?? "the selected agent") on thread \(sessionID)."
            } else {
                persistenceStatus = "Agent is ready, but no active thread was created."
            }
        } catch {
            setRuntimeError(error.localizedDescription)
            persistenceStatus = "Failed to link to \(selectedAgentConnection?.runtimeName ?? "selected agent"): \(error.localizedDescription)"
        }
    }

    func relinkSelectedAgentNow() async {
        guard isAgentSelectionLocked else {
            persistenceStatus = "Select and lock an agent before re-linking."
            return
        }

        guard hasProjectRoot else {
            persistenceStatus = "Select a project folder before re-linking."
            return
        }

        resetLiveAgentEvents()
        clearRuntimeError()
        mutateProject { project in
            if project.agentSession?.runtimeID == selectedAgentRuntimeID {
                project.agentSession = nil
            }
        }
        refreshAgentConnections()

        do {
            try await connectSelectedAgentIfNeeded(forceReconnect: true)
            if let sessionID = selectedAgentSessionID {
                persistenceStatus = "Nanga re-linked to \(selectedAgentConnection?.runtimeName ?? "the selected agent") on thread \(sessionID)."
            } else {
                persistenceStatus = "Re-link finished without an active thread."
            }
        } catch {
            setRuntimeError(error.localizedDescription)
            persistenceStatus = "Failed to re-link \(selectedAgentConnection?.runtimeName ?? "selected agent"): \(error.localizedDescription)"
        }
    }

    func launchCodexLoginInTerminal() {
        guard canLaunchCodexLogin else {
            persistenceStatus = "Codex CLI is unavailable on this machine."
            return
        }

        clearRuntimeError()

        do {
            let workingRoot = activeProjectRootURL ?? selectedProject.rootFolder?.resolvedURL
            try TerminalCommandLauncher.openCodexDeviceLogin(workingRootURL: workingRoot)
            recordAgentEvent(
                AgentRuntimeEvent(
                    kind: .status,
                    message: "Opened Terminal for Codex login. Complete login there, then press Verify Login."
                )
            )
            persistenceStatus = "Opened Terminal for Codex device login."
        } catch {
            setRuntimeError(error.localizedDescription)
            persistenceStatus = "Failed to open Terminal for Codex login: \(error.localizedDescription)"
        }
    }

    func refreshSelectedAgentConnectionState() {
        refreshAgentConnections()

        if selectedAgentRuntimeID == "codex" {
            switch selectedAgentConnection?.authenticationStatus {
            case .loggedIn:
                persistenceStatus = "Codex login is verified."
            case .loginRequired:
                persistenceStatus = "Codex login is still required."
            default:
                persistenceStatus = "Codex connection state refreshed."
            }
            return
        }

        persistenceStatus = "Refreshed available agent connections."
    }

    func discoverCandidateFiles() {
        guard canDiscoverCandidateFiles else {
            persistenceStatus = "Open a project folder and complete the task before discovering files."
            return
        }

        guard let rootURL = activeProjectRootURL ?? selectedProject.rootFolder?.resolvedURL else {
            persistenceStatus = "Project root could not be resolved."
            return
        }

        do {
            let candidates = try fileDiscoveryService.discoverCandidates(
                in: rootURL,
                task: currentIteration.task,
                previousSelections: currentIteration.scope.files
            )

            mutateCurrentIteration { iteration in
                iteration.candidateFiles = candidates
            }
            refreshSignalFromCurrentState(
                headline: "Scope resolved",
                detail: "Nanga selected the highest-signal files for this task."
            )
            persistProject(statusMessage: "Resolved scope from the project root.")
        } catch {
            persistenceStatus = "Failed to discover files: \(error.localizedDescription)"
        }
    }

    func setCandidateFileSelection(id: UUID, isSelected: Bool) {
        guard let index = currentIteration.candidateFiles.firstIndex(where: { $0.id == id }) else {
            return
        }

        mutateCurrentIteration { iteration in
            iteration.candidateFiles[index].isSelected = isSelected
        }
        refreshSignalFromCurrentState(
            headline: "Scope adjusted",
            detail: "Selected files were updated for the current iteration."
        )
        persistProject(statusMessage: "Updated selected files in scope.")
    }

    func runIteration() async {
        guard canRunIteration else {
            persistenceStatus = "Run requires a project root, a complete task, and at least one selected file."
            return
        }

        guard let rootURL = activeProjectRootURL ?? selectedProject.rootFolder?.resolvedURL else {
            persistenceStatus = "Project root could not be resolved."
            return
        }

        mutateCurrentIteration { iteration in
            iteration.execution = ExecutionSummary(
                status: .running,
                headline: "Running scoped iteration",
                detail: "Compacting task, signal, and scoped files into an execution package."
            )
        }
        resetLiveAgentEvents()
        clearRuntimeError()
        recordAgentEvent(
            AgentRuntimeEvent(
                kind: .status,
                message: "Preparing scoped package for \(selectedRuntimeName)."
            )
        )
        persistProject(statusMessage: "Preparing scoped execution package.")

        do {
            if activeSessionID(for: selectedAgentRuntimeID) == nil {
                recordAgentEvent(
                    AgentRuntimeEvent(
                        kind: .status,
                        message: "Attaching to \(selectedRuntimeName) before execution."
                    )
                )
            } else if let sessionID = selectedAgentSessionID {
                recordAgentEvent(
                    AgentRuntimeEvent(
                        kind: .status,
                        message: "Resuming \(selectedRuntimeName) thread \(sessionID)."
                    )
                )
            }

            try await connectSelectedAgentIfNeeded()
            let carryForwardItems = buildCarryForwardItems()
            let executionPackage = try executionPackageBuilder.build(
                project: selectedProject,
                rootURL: rootURL,
                selectedFiles: selectedProject.currentIteration.scope.files,
                carryForwardItems: carryForwardItems
            )
            guard let runtime = agentRuntimeRegistry.runtime(for: selectedAgentRuntimeID) else {
                persistenceStatus = "Selected agent runtime is not available."
                return
            }
            recordAgentEvent(
                AgentRuntimeEvent(
                    kind: .status,
                    message: "Sending \(executionPackage.fileCount) scoped files to \(runtime.displayName)."
                )
            )

            let result = try await runtime.execute(
                executionPackage,
                sessionID: activeSessionID(for: selectedAgentRuntimeID),
                in: rootURL,
                model: selectedAgentModel,
                eventHandler: makeAgentEventHandler()
            )

            applyExecutionResult(result, package: executionPackage)
            saveIterationCheckpoint()
            persistProject(statusMessage: "Built the scoped execution package and ran it through the active runtime.")
        } catch {
            setRuntimeError(error.localizedDescription)
            mutateCurrentIteration { iteration in
                iteration.execution = ExecutionSummary(
                    status: .failed,
                    headline: "Execution failed",
                    detail: error.localizedDescription
                )
            }
            persistProject(statusMessage: "Failed to run the scoped iteration: \(error.localizedDescription)")
        }
    }

    private func buildCarryForwardItems() -> [String] {
        var items = ["task intent", "selected signal", "scoped files"]

        if hasProjectRoot {
            items.append("project root")
        }

        if let first = currentIteration.scope.files.first {
            items.append(first)
        }

        return Array(NSOrderedSet(array: items)) as? [String] ?? items
    }

    private func refreshSignalFromCurrentState(headline: String, detail: String) {
        var refreshedSignal: [SignalItem] = [
            SignalItem(kind: .taskIntent, title: currentIteration.task.title),
            SignalItem(kind: .decision, title: currentIteration.task.detail)
        ]

        if let root = selectedProject.rootFolder?.path {
            refreshedSignal.append(SignalItem(kind: .constraint, title: "Project root anchored at \(root)"))
        }

        for file in selectedProject.currentIteration.scope.files.prefix(3) {
            refreshedSignal.append(SignalItem(kind: .relevantFile, title: file))
        }

        if let firstUnselected = selectedProject.currentIteration.candidateFiles.first(where: { !$0.isSelected }) {
            refreshedSignal.append(SignalItem(kind: .unfinishedWork, title: "Candidate file left out of scope: \(firstUnselected.path)"))
        }

        mutateCurrentIteration { iteration in
            iteration.signal = refreshedSignal
            iteration.execution = ExecutionSummary(
                status: .refreshed,
                headline: headline,
                detail: detail
            )
        }
    }

    private func applyExecutionResult(_ result: ExecutionResult, package: ExecutionPackage) {
        mutateCurrentIteration { iteration in
            iteration.signal = result.refreshedSignal
            iteration.savedState = SavedIterationState(
                summary: "Saved a compact execution package and refreshed carry-forward state for the next iteration.",
                carriedForwardItems: result.carriedForwardItems
            )
            iteration.execution = ExecutionSummary(
                status: .refreshed,
                headline: result.headline,
                detail: "\(result.detail) Scoped package: \(package.fileCount) files, \(package.signal.count) signal items."
            )
        }
        if let sessionID = result.sessionID {
            persistAgentSession(AgentSession(runtimeID: selectedAgentRuntimeID, threadID: sessionID))
        }
    }

    private func refreshTaskDraftState() {
        let task = currentIteration.task

        mutateCurrentIteration { iteration in
            iteration.candidateFiles = []
            iteration.signal = buildTaskDraftSignal(for: task)
            iteration.execution = ExecutionSummary(
                status: .ready,
                headline: task.isReadyForExecution ? "Task ready for scope resolution" : "Task draft updated",
                detail: task.isReadyForExecution
                    ? "Nanga will resolve the highest-signal scope from the selected project."
                    : "Add both a task title and execution intent to unlock scoped execution."
            )
        }
    }

    private func handleTaskDraftChange(statusMessage: String) {
        refreshTaskDraftState()

        if canDiscoverCandidateFiles {
            discoverCandidateFiles()
        } else {
            persistProject(statusMessage: statusMessage)
        }
    }

    private func buildTaskDraftSignal(for task: TaskDraft) -> [SignalItem] {
        var signal: [SignalItem] = []

        if !task.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            signal.append(SignalItem(kind: .taskIntent, title: task.title))
        }

        if !task.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            signal.append(SignalItem(kind: .decision, title: task.detail))
        }

        if let root = selectedProject.rootFolder?.path {
            signal.append(SignalItem(kind: .constraint, title: "Project root anchored at \(root)"))
        }

        if signal.isEmpty {
            signal.append(SignalItem(kind: .unfinishedWork, title: "Add a task to begin building scoped context."))
        }

        return signal
    }

    private func mutateCurrentIteration(_ update: (inout IterationState) -> Void) {
        var project = selectedProject
        update(&project.currentIteration)
        project.currentIteration.scope.files = project.currentIteration.candidateFiles
            .filter(\.isSelected)
            .map(\.path)
        selectedProject = project
    }

    private func mutateProject(_ update: (inout NangaProject) -> Void) {
        var project = selectedProject
        update(&project)
        selectedProject = project
    }

    private func persistProject(statusMessage: String = "Saved project state to disk.") {
        do {
            try projectStore.saveProject(selectedProject)
            persistenceStatus = statusMessage
        } catch {
            persistenceStatus = "Failed to save project state: \(error.localizedDescription)"
        }
    }

    private func persistAgentSelection(statusMessage: String) {
        mutateProject { project in
            project.selectedAgentRuntimeID = selectedAgentRuntimeID
            project.selectedAgentModelID = selectedAgentModelID
            project.isAgentSelectionLocked = isAgentSelectionLocked
        }
        persistProject(statusMessage: statusMessage)
    }

    private func persistAgentSession(_ session: AgentSession) {
        mutateProject { project in
            project.agentSession = session
        }
        refreshAgentConnections()
        let runtimeName = agentRuntimeRegistry.runtime(for: session.runtimeID)?.displayName ?? session.runtimeID
        persistProject(statusMessage: "Attached Nanga to the active \(runtimeName) thread.")
    }

    private func makeAgentEventHandler() -> @Sendable (AgentRuntimeEvent) -> Void {
        { event in
            Task { @MainActor [weak self] in
                self?.recordAgentEvent(event)
            }
        }
    }

    private func recordAgentEvent(_ event: AgentRuntimeEvent) {
        liveAgentEvents.append(event)
        liveAgentEvents = Array(liveAgentEvents.suffix(24))

        if event.kind == .error {
            setRuntimeError(event.message)
        }

        let headline: String
        let runtimeName = selectedRuntimeName
        switch event.kind {
        case .threadStarted:
            headline = "\(runtimeName) attached"
        case .status:
            headline = "\(runtimeName) running"
        case .message:
            headline = "\(runtimeName) responded"
        case .error:
            headline = "\(runtimeName) signaled an issue"
        }

        mutateCurrentIteration { iteration in
            iteration.execution = ExecutionSummary(
                status: .running,
                headline: headline,
                detail: event.message
            )
        }
    }

    private func resetLiveAgentEvents() {
        liveAgentEvents = []
    }

    private func clearRuntimeError() {
        lastRuntimeError = nil
    }

    private func setRuntimeError(_ message: String) {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        lastRuntimeError = trimmed.isEmpty ? nil : trimmed
    }

    private func restoreProjectRootAccess() {
        guard let rootFolder = selectedProject.rootFolder else { return }

        let resolution = rootFolder.resolveBookmark()
        if let url = resolution.url {
            activeProjectRootURL = url
            _ = url.startAccessingSecurityScopedResource()

            if resolution.didRefreshBookmark {
                let refreshedReference = ProjectFolderReference.make(from: url)
                selectedProject.rootFolder = refreshedReference
                persistProject(statusMessage: "Refreshed saved project folder access.")
            }
        }

        refreshAgentConnections()
    }

    private func stopAccessingCurrentProjectRootIfNeeded() {
        activeProjectRootURL?.stopAccessingSecurityScopedResource()
        activeProjectRootURL = nil
    }

    deinit {
        activeProjectRootURL?.stopAccessingSecurityScopedResource()
    }

    private func refreshAgentConnections() {
        let rootURL = activeProjectRootURL ?? selectedProject.rootFolder?.resolvedURL
        let detectedConnections = agentRuntimeRegistry.detectConnections(at: rootURL)
        agentConnections = detectedConnections.map { connection in
            guard let session = selectedProject.agentSession, session.runtimeID == connection.runtimeID else {
                return connection
            }

            var attachedConnection = connection
            attachedConnection.status = .connected
            attachedConnection.detail = "Attached to active \(connection.runtimeName) thread \(session.threadID). \(connection.detail)"
            return attachedConnection
        }

        if selectedAgentRuntimeID.isEmpty || !agentConnections.contains(where: { $0.runtimeID == selectedAgentRuntimeID }) {
            if let preferred = agentConnections.first(where: { $0.status == .connected })
                ?? agentConnections.first(where: { $0.status == .available })
                ?? agentConnections.first {
                selectedAgentRuntimeID = preferred.runtimeID
            }
        }

        if let selected = selectedAgentConnection, !selected.canExecute {
            isAgentSelectionLocked = false
        }

        syncSelectedAgentModel()
        persistAgentSelection(statusMessage: "Refreshed available agent connections.")
    }

    private func syncSelectedAgentModel() {
        let models = availableAgentModels
        if selectedAgentModelID.isEmpty || !models.contains(where: { $0.id == selectedAgentModelID }) {
            selectedAgentModelID = models.first?.id ?? ""
        }
    }

    private func activeSessionID(for runtimeID: String) -> String? {
        guard selectedProject.agentSession?.runtimeID == runtimeID else {
            return nil
        }

        return selectedProject.agentSession?.threadID
    }

    private func connectSelectedAgentIfNeeded(forceReconnect: Bool = false) async throws {
        guard let rootURL = activeProjectRootURL ?? selectedProject.rootFolder?.resolvedURL else {
            return
        }

        if forceReconnect {
            mutateProject { project in
                if project.agentSession?.runtimeID == selectedAgentRuntimeID {
                    project.agentSession = nil
                }
            }
        }

        guard forceReconnect || activeSessionID(for: selectedAgentRuntimeID) == nil else {
            return
        }

        guard let runtime = agentRuntimeRegistry.runtime(for: selectedAgentRuntimeID) else {
            return
        }

        if let session = try await runtime.connect(
            in: rootURL,
            model: selectedAgentModel,
            eventHandler: makeAgentEventHandler()
        ) {
            persistAgentSession(session)
        }
    }
}

private enum TerminalCommandLauncher {
    static func openCodexDeviceLogin(workingRootURL: URL?) throws {
        let workingPath = (workingRootURL ?? URL(filePath: NSHomeDirectory())).path(percentEncoded: false)
        let shellCommand = "cd \(shellSingleQuoted(workingPath)); codex login --device-auth"
        let script = """
        tell application "Terminal"
            activate
            do script "\(appleScriptEscaped(shellCommand))"
        end tell
        """

        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorText = String(decoding: errorData, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw TerminalCommandError.launchFailed(
                errorText.isEmpty ? "Terminal command exited with status \(process.terminationStatus)." : errorText
            )
        }
    }

    private static func shellSingleQuoted(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escaped)'"
    }

    private static func appleScriptEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}

private enum TerminalCommandError: LocalizedError {
    case launchFailed(String)

    var errorDescription: String? {
        switch self {
        case .launchFailed(let detail):
            detail
        }
    }
}

struct NangaProject: Identifiable, Equatable, Codable {
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case repositoryName
        case rootFolder
        case selectedAgentRuntimeID
        case selectedAgentModelID
        case isAgentSelectionLocked
        case agentSession
        case currentIteration
        case iterationHistory
    }

    let id: UUID
    var name: String
    var repositoryName: String
    var rootFolder: ProjectFolderReference?
    var selectedAgentRuntimeID: String
    var selectedAgentModelID: String
    var isAgentSelectionLocked: Bool
    var agentSession: AgentSession?
    var currentIteration: IterationState
    var iterationHistory: [IterationRecord]

    static let sample = NangaProject(
        id: UUID(),
        name: "Nanga",
        repositoryName: "nanga",
        rootFolder: nil,
        selectedAgentRuntimeID: "codex",
        selectedAgentModelID: "",
        isAgentSelectionLocked: false,
        agentSession: nil,
        currentIteration: IterationState.sample,
        iterationHistory: [
            IterationRecord(
                label: "Define the first Nanga shell",
                savedAt: .now.addingTimeInterval(-3_600),
                summary: "Saved the first product-shaped iteration frame.",
                carriedForwardItems: ["task intent", "signal scaffolding", "scope surfaces"],
                scopedFiles: ["nanga/ContentView.swift", "nanga/NangaAppModel.swift"]
            )
        ]
    )

    init(
        id: UUID,
        name: String,
        repositoryName: String,
        rootFolder: ProjectFolderReference?,
        selectedAgentRuntimeID: String,
        selectedAgentModelID: String,
        isAgentSelectionLocked: Bool,
        agentSession: AgentSession?,
        currentIteration: IterationState,
        iterationHistory: [IterationRecord]
    ) {
        self.id = id
        self.name = name
        self.repositoryName = repositoryName
        self.rootFolder = rootFolder
        self.selectedAgentRuntimeID = selectedAgentRuntimeID
        self.selectedAgentModelID = selectedAgentModelID
        self.isAgentSelectionLocked = isAgentSelectionLocked
        self.agentSession = agentSession
        self.currentIteration = currentIteration
        self.iterationHistory = iterationHistory
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        repositoryName = try container.decode(String.self, forKey: .repositoryName)
        rootFolder = try container.decodeIfPresent(ProjectFolderReference.self, forKey: .rootFolder)
        selectedAgentRuntimeID = try container.decodeIfPresent(String.self, forKey: .selectedAgentRuntimeID) ?? "codex"
        selectedAgentModelID = try container.decodeIfPresent(String.self, forKey: .selectedAgentModelID) ?? ""
        isAgentSelectionLocked = try container.decodeIfPresent(Bool.self, forKey: .isAgentSelectionLocked) ?? false
        agentSession = try container.decodeIfPresent(AgentSession.self, forKey: .agentSession)
        currentIteration = try container.decode(IterationState.self, forKey: .currentIteration)
        iterationHistory = try container.decode([IterationRecord].self, forKey: .iterationHistory)
    }

    func minimizedForPersistence() -> NangaProject {
        var project = self
        project.currentIteration = currentIteration.minimizedForPersistence()
        project.iterationHistory = iterationHistory
            .map { $0.minimizedForPersistence() }
            .prefix(12)
            .map { $0 }
        return project
    }
}

struct IterationState: Equatable, Codable {
    var task: TaskDraft
    var signal: [SignalItem]
    var scope: ScopeSnapshot
    var execution: ExecutionSummary
    var savedState: SavedIterationState
    var candidateFiles: [CandidateFile]

    var carryForwardSummary: String {
        let signalCount = signal.count
        let fileCount = scope.files.count
        return "Saving \(signalCount) signal items and \(fileCount) scoped files for the next iteration."
    }

    static let sample = IterationState(
        task: TaskDraft(
            title: "Build the first iteration shell",
            detail: "Show the current task, selected signal, active scope, execution result, and saved next-iteration state."
        ),
        signal: [
            SignalItem(kind: .taskIntent, title: "Iteration loop is the primary product unit"),
            SignalItem(kind: .relevantFile, title: "Current UI is still the default SwiftUI template"),
            SignalItem(kind: .constraint, title: "The app must feel frictionless for developers"),
            SignalItem(kind: .unfinishedWork, title: "Need a shell organized around iteration state, not generic chat")
        ],
        scope: ScopeSnapshot(
            surfaces: [
                .projectRoot,
                .taskInput,
                .signalPanel,
                .scopePanel,
                .executionResult,
                .savedIterationState
            ],
            folders: [],
            files: [
                "nanga/nangaApp.swift",
                "nanga/ContentView.swift",
                "nanga/NangaAppModel.swift"
            ]
        ),
        execution: ExecutionSummary(
            status: .ready,
            headline: "No agent run yet",
            detail: "The app can already show the working frame before execution."
        ),
        savedState: SavedIterationState(
            summary: "Project remembers the current task frame and the scoped context selected for the next step.",
            carriedForwardItems: [
                "task intent",
                "selected signal",
                "scoped files",
                "active constraints"
            ]
        ),
        candidateFiles: [
            CandidateFile(path: "nanga/ContentView.swift", reason: "The visible shell lives here.", score: 12, isSelected: true),
            CandidateFile(path: "nanga/NangaAppModel.swift", reason: "Iteration state is defined here.", score: 11, isSelected: true)
        ]
    )

    func minimizedForPersistence() -> IterationState {
        IterationState(
            task: task.minimizedForPersistence(),
            signal: Array(signal.prefix(8)).map { $0.minimizedForPersistence() },
            scope: scope.minimizedForPersistence(),
            execution: execution.minimizedForPersistence(),
            savedState: savedState.minimizedForPersistence(),
            candidateFiles: []
        )
    }
}

struct TaskDraft: Equatable, Codable {
    var title: String
    var detail: String

    var isReadyForExecution: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func minimizedForPersistence() -> TaskDraft {
        TaskDraft(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            detail: detail.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

struct SignalItem: Identifiable, Equatable, Codable {
    enum Kind: String, Equatable, Codable {
        case taskIntent = "Task Intent"
        case relevantFile = "Relevant File"
        case constraint = "Constraint"
        case unfinishedWork = "Unfinished Work"
        case changedArtifact = "Changed Artifact"
        case decision = "Decision"
    }

    let id: UUID
    var kind: Kind
    var title: String

    init(id: UUID = UUID(), kind: Kind, title: String) {
        self.id = id
        self.kind = kind
        self.title = title
    }

    func minimizedForPersistence() -> SignalItem {
        SignalItem(
            kind: kind,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

struct CandidateFile: Identifiable, Equatable, Codable {
    let id: UUID
    var path: String
    var reason: String
    var score: Int
    var isSelected: Bool

    init(
        id: UUID = UUID(),
        path: String,
        reason: String,
        score: Int,
        isSelected: Bool
    ) {
        self.id = id
        self.path = path
        self.reason = reason
        self.score = score
        self.isSelected = isSelected
    }
}

struct ScopeSnapshot: Equatable, Codable {
    var surfaces: [ScopeSurface]
    var folders: [String]
    var files: [String]

    func minimizedForPersistence() -> ScopeSnapshot {
        ScopeSnapshot(
            surfaces: surfaces,
            folders: [],
            files: Array(files.prefix(12))
        )
    }
}

enum ScopeSurface: String, CaseIterable, Identifiable, Codable {
    case projectRoot = "Project Root"
    case taskInput = "Task Input"
    case signalPanel = "Signal Panel"
    case scopePanel = "Scope Panel"
    case executionResult = "Execution Result"
    case savedIterationState = "Saved Iteration State"
    case iterationHistory = "Iteration History"

    var id: String { rawValue }
}

struct ExecutionSummary: Equatable, Codable {
    enum Status: String, Equatable, Codable {
        case ready = "Ready"
        case running = "Running"
        case refreshed = "Refreshed"
        case failed = "Failed"
    }

    var status: Status
    var headline: String
    var detail: String

    func minimizedForPersistence() -> ExecutionSummary {
        ExecutionSummary(
            status: status,
            headline: headline,
            detail: detail.isEmpty ? detail : "Stored compact execution status."
        )
    }
}

struct SavedIterationState: Equatable, Codable {
    var summary: String
    var carriedForwardItems: [String]

    func minimizedForPersistence() -> SavedIterationState {
        SavedIterationState(
            summary: summary,
            carriedForwardItems: carriedForwardItems.uniquePrefix(6)
        )
    }
}

struct ProjectFolderReference: Equatable, Codable {
    var path: String
    var bookmarkData: Data?

    var resolvedURL: URL {
        URL(filePath: path)
    }

    static func make(from url: URL) -> ProjectFolderReference {
        let bookmarkData = try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        return ProjectFolderReference(
            path: url.path(percentEncoded: false),
            bookmarkData: bookmarkData
        )
    }

    func resolveBookmark() -> BookmarkResolution {
        guard let bookmarkData else {
            return BookmarkResolution(url: resolvedURL, didRefreshBookmark: false)
        }

        var isStale = false
        let url = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        return BookmarkResolution(url: url ?? resolvedURL, didRefreshBookmark: isStale)
    }
}

struct BookmarkResolution {
    var url: URL?
    var didRefreshBookmark: Bool
}

struct IterationRecord: Identifiable, Equatable, Codable {
    let id: UUID
    var label: String
    var savedAt: Date
    var summary: String
    var carriedForwardItems: [String]
    var scopedFiles: [String]

    init(
        id: UUID = UUID(),
        label: String,
        savedAt: Date,
        summary: String,
        carriedForwardItems: [String],
        scopedFiles: [String]
    ) {
        self.id = id
        self.label = label
        self.savedAt = savedAt
        self.summary = summary
        self.carriedForwardItems = carriedForwardItems
        self.scopedFiles = scopedFiles
    }

    enum CodingKeys: String, CodingKey {
        case id
        case label
        case savedAt
        case summary
        case carriedForwardItems
        case scopedFiles
        case snapshot
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        label = try container.decode(String.self, forKey: .label)
        savedAt = try container.decode(Date.self, forKey: .savedAt)

        if container.contains(.summary) {
            summary = try container.decode(String.self, forKey: .summary)
            carriedForwardItems = try container.decodeIfPresent([String].self, forKey: .carriedForwardItems) ?? []
            scopedFiles = try container.decodeIfPresent([String].self, forKey: .scopedFiles) ?? []
            return
        }

        let snapshot = try container.decode(IterationSnapshot.self, forKey: .snapshot)
        summary = snapshot.savedState.summary
        carriedForwardItems = snapshot.savedState.carriedForwardItems
        scopedFiles = Array(snapshot.scope.files.prefix(5))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(label, forKey: .label)
        try container.encode(savedAt, forKey: .savedAt)
        try container.encode(summary, forKey: .summary)
        try container.encode(carriedForwardItems, forKey: .carriedForwardItems)
        try container.encode(scopedFiles, forKey: .scopedFiles)
    }

    func minimizedForPersistence() -> IterationRecord {
        IterationRecord(
            id: id,
            label: label,
            savedAt: savedAt,
            summary: summary,
            carriedForwardItems: carriedForwardItems.uniquePrefix(6),
            scopedFiles: Array(scopedFiles.prefix(5))
        )
    }
}

struct IterationSnapshot: Equatable, Codable {
    var task: TaskDraft
    var signal: [SignalItem]
    var scope: ScopeSnapshot
    var execution: ExecutionSummary
    var savedState: SavedIterationState
    var candidateFiles: [CandidateFile]
}

private extension Array where Element == String {
    func uniquePrefix(_ maxCount: Int) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for value in self {
            guard !value.isEmpty, !seen.contains(value) else { continue }
            seen.insert(value)
            result.append(value)
            if result.count == maxCount {
                break
            }
        }

        return result
    }
}
