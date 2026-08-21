import SwiftUI

struct MemoryBreakdownView: View {
    @State private var processes: [ProcessMemoryInfo] = []
    @State private var pendingTermination: ProcessMemoryInfo?
    @State private var forceQuitPending = false
    @State private var isRefreshing = false
    @State private var errorMessage: String?

    private let displayLimit = 15

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()

            if processes.isEmpty {
                emptyState
            } else {
                List(processes.prefix(displayLimit)) { process in
                    processRow(process)
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 480, minHeight: 420)
        .task {
            await refresh()
        }
        .confirmationDialog(
            confirmationTitle,
            isPresented: confirmationBinding,
            titleVisibility: .visible
        ) {
            Button(forceQuitPending ? "Force Quit" : "Quit", role: .destructive) {
                confirmTermination()
            }
            Button("Cancel", role: .cancel) {
                pendingTermination = nil
            }
        }
        .alert("Couldn’t Quit Process", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "The process may have exited or macOS denied the request.")
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Memory Breakdown")
                    .font(.headline)
                Text("Largest consumers first — right-click a row for Force Quit.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await refresh() }
            } label: {
                if isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Refresh")
                }
            }
            .disabled(isRefreshing)
        }
        .padding()
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "memorychip")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("No process data yet")
                .foregroundStyle(.secondary)
            Button("Scan Now") {
                Task { await refresh() }
            }
            .disabled(isRefreshing)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func processRow(_ process: ProcessMemoryInfo) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(process.name)
                    .fontWeight(isLikelyAIWorkload(process.name) ? .semibold : .regular)
                if isLikelyAIWorkload(process.name) {
                    Text("Local AI workload")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(String(format: "%.2f GB", process.memoryGB))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 80, alignment: .trailing)

            Button("Quit") {
                pendingTermination = process
                forceQuitPending = false
            }
            .buttonStyle(.bordered)
        }
        .contextMenu {
            Button("Quit") {
                pendingTermination = process
                forceQuitPending = false
            }
            Button("Force Quit", role: .destructive) {
                pendingTermination = process
                forceQuitPending = true
            }
        }
    }

    private var confirmationTitle: String {
        guard let pendingTermination else { return "" }
        return forceQuitPending
            ? "Force quit \"\(pendingTermination.name)\"?"
            : "Quit \"\(pendingTermination.name)\"?"
    }

    private var confirmationBinding: Binding<Bool> {
        Binding(
            get: { pendingTermination != nil },
            set: { isPresented in
                if !isPresented { pendingTermination = nil }
            }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented { errorMessage = nil }
            }
        )
    }

    private func confirmTermination() {
        guard let target = pendingTermination else { return }
        let succeeded = ProcessTerminator.terminate(process: target, force: forceQuitPending)
        pendingTermination = nil
        if !succeeded {
            errorMessage = "\(target.name) could not be quit. It may have exited, changed identity, or require different permissions."
        }
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            await refresh()
        }
    }

    private func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        processes = await Task.detached(priority: .userInitiated) {
            ProcessMemoryScanner.snapshot()
        }.value
    }

    /// Best-effort name matching so common local-AI tooling stands out in
    /// the list — a highlight, not a filter; everything else still shows
    /// up sorted by size same as ever.
    private func isLikelyAIWorkload(_ name: String) -> Bool {
        let needles = ["ollama", "lm studio", "lmstudio", "llama", "gpt4all", "text-generation", "koboldcpp"]
        let lowered = name.lowercased()
        return needles.contains { lowered.contains($0) }
    }
}
