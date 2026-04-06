import SwiftUI

struct ContentView: View {
    @Environment(NangaAppModel.self) private var appModel

    var body: some View {
        let project = appModel.selectedProject
        let iteration = appModel.currentIteration

        NavigationSplitView {
            projectSidebar(project: project)
        } detail: {
            mainCanvas(iteration: iteration)
        }
        .navigationSplitViewStyle(.balanced)
    }

    private func projectSidebar(project: NangaProject) -> some View {
        List {
            Section("Project") {
                LabeledContent("Name", value: project.name)
                LabeledContent("Repository", value: project.repositoryName)
            }

            Section("Iteration Loop") {
                Label("Current Task", systemImage: "text.bubble")
                Label("Selected Signal", systemImage: "dot.scope")
                Label("Active Scope", systemImage: "square.stack.3d.up")
                Label("Execution Result", systemImage: "bolt.horizontal")
                Label("Saved State", systemImage: "tray.full")
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Nanga")
    }

    private func mainCanvas(iteration: IterationState) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hero(iteration: iteration)

                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 320), spacing: 16, alignment: .top)
                ], alignment: .leading, spacing: 16) {
                    taskPanel(task: iteration.task)
                    signalPanel(signal: iteration.signal)
                    scopePanel(scope: iteration.scope)
                    executionPanel(execution: iteration.execution)
                    savedStatePanel(savedState: iteration.savedState, carryForwardSummary: iteration.carryForwardSummary)
                }
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func hero(iteration: IterationState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Iteration Shell")
                .font(.system(size: 30, weight: .semibold, design: .rounded))
            Text("Nanga is organized around the live working frame: task, signal, scope, result, and saved next-iteration state.")
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                statusBadge(title: iteration.execution.status.rawValue, tint: .blue)
                statusBadge(title: "\(iteration.signal.count) Signal Items", tint: .green)
                statusBadge(title: "\(iteration.scope.files.count) Files In Scope", tint: .orange)
                statusBadge(
                    title: iteration.task.isReadyForExecution ? "Task Ready" : "Task Needs Input",
                    tint: iteration.task.isReadyForExecution ? .mint : .red
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.93, green: 0.96, blue: 1.0),
                            Color(red: 0.96, green: 0.93, blue: 0.90)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    private func taskPanel(task: TaskDraft) -> some View {
        panel(title: "Current Task", systemImage: "text.bubble") {
            VStack(alignment: .leading, spacing: 8) {
                Text("This is the first editable iteration surface. The task should define the frame the rest of Nanga carries forward.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField(
                    "What is the current task?",
                    text: Binding(
                        get: { appModel.currentTaskTitle },
                        set: { appModel.currentTaskTitle = $0 }
                    ),
                    prompt: Text("Describe the current task")
                )
                .textFieldStyle(.roundedBorder)

                TextField(
                    "What should happen in this iteration?",
                    text: Binding(
                        get: { appModel.currentTaskDetail },
                        set: { appModel.currentTaskDetail = $0 }
                    ),
                    prompt: Text("Add execution detail"),
                    axis: .vertical
                )
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)

                Label(
                    task.isReadyForExecution ? "Task frame is ready for execution." : "Task frame needs both a title and execution detail.",
                    systemImage: task.isReadyForExecution ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                )
                .foregroundStyle(task.isReadyForExecution ? .green : .orange)
            }
        }
    }

    private func signalPanel(signal: [SignalItem]) -> some View {
        panel(title: "Selected Signal", systemImage: "dot.scope") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(signal) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.kind.rawValue.uppercased())
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(item.title)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(.rect(cornerRadius: 12))
                }
            }
        }
    }

    private func scopePanel(scope: ScopeSnapshot) -> some View {
        panel(title: "Active Scope", systemImage: "square.stack.3d.up") {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Surfaces In Play")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(scope.surfaces) { surface in
                        Label(surface.rawValue, systemImage: "checkmark.circle")
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Files In Scope")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(scope.files, id: \.self) { file in
                        Text(file)
                            .font(.system(.body, design: .monospaced))
                    }
                }
            }
        }
    }

    private func executionPanel(execution: ExecutionSummary) -> some View {
        panel(title: "Execution Result", systemImage: "bolt.horizontal") {
            VStack(alignment: .leading, spacing: 8) {
                Text(execution.headline)
                    .font(.title3.weight(.semibold))
                Text(execution.detail)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func savedStatePanel(savedState: SavedIterationState, carryForwardSummary: String) -> some View {
        panel(title: "Saved Next Iteration State", systemImage: "tray.full") {
            VStack(alignment: .leading, spacing: 10) {
                Text(savedState.summary)
                    .foregroundStyle(.secondary)
                Text(carryForwardSummary)
                    .font(.subheadline.weight(.medium))

                Divider()

                ForEach(savedState.carriedForwardItems, id: \.self) { item in
                    Label(item.capitalized, systemImage: "arrowshape.turn.up.right")
                }
            }
        }
    }

    private func panel<Content: View>(title: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
        .background(Color.primary.opacity(0.035))
        .clipShape(.rect(cornerRadius: 18))
    }

    private func statusBadge(title: String, tint: Color) -> some View {
        Text(title)
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.12))
            .foregroundStyle(tint)
            .clipShape(.capsule)
    }
}

#Preview {
    ContentView()
        .environment(NangaAppModel())
}
