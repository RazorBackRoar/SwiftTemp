import SwiftUI

struct ProcessBreakdownView: View {
    var title: String
    var subtitle: String
    var systemImage: String
    var accent: Color
    var load: @Sendable () async -> [ProcessUsageRow]

    @State private var processes: [ProcessUsageRow] = []
    @State private var pendingTermination: ProcessUsageRow?
    @State private var forceQuitPending = false
    @State private var isRefreshing = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()

            if processes.isEmpty {
                emptyState
            } else {
                List(processes) { process in
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
                Text(title)
                    .font(.headline)
                Text(subtitle)
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
            Image(systemName: systemImage)
                .font(.system(size: 32))
                .foregroundStyle(accent)
            Text(isRefreshing ? "Scanning processes…" : "No process data yet")
                .foregroundStyle(.secondary)
            Button("Scan Now") {
                Task { await refresh() }
            }
            .disabled(isRefreshing)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func processRow(_ process: ProcessUsageRow) -> some View {
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

            Text(process.detail)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(minWidth: 72, alignment: .trailing)

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
        let succeeded = ProcessTerminator.terminate(
            pid: target.pid, name: target.name, force: forceQuitPending)
        pendingTermination = nil
        if !succeeded {
            errorMessage =
                "\(target.name) could not be quit. It may have exited, changed identity, or require different permissions."
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
        processes = await load()
    }

    private func isLikelyAIWorkload(_ name: String) -> Bool {
        let needles = [
            "ollama", "lm studio", "lmstudio", "llama", "gpt4all", "text-generation", "koboldcpp",
        ]
        let lowered = name.lowercased()
        return needles.contains { lowered.contains($0) }
    }
}

enum ProcessBreakdownLoaders {
    static func memory() async -> [ProcessUsageRow] {
        await Task.detached(priority: .userInitiated) {
            Array(ProcessMemoryScanner.snapshot().prefix(15)).map { process in
                ProcessUsageRow(
                    pid: process.pid,
                    name: process.name,
                    detail: String(format: "%.2f GB", process.memoryGB)
                )
            }
        }.value
    }

    static func cpu() async -> [ProcessUsageRow] {
        await Task.detached(priority: .userInitiated) {
            await ProcessCPUScanner.rankedSnapshot().map { process in
                ProcessUsageRow(
                    pid: process.pid,
                    name: process.name,
                    detail: String(format: "%.1f%%", process.cpuPercent)
                )
            }
        }.value
    }

    static func gpu() async -> [ProcessUsageRow] {
        await Task.detached(priority: .userInitiated) {
            await ProcessGPUScanner.rankedSnapshot().map { process in
                ProcessUsageRow(
                    pid: process.pid,
                    name: process.name,
                    detail: String(format: "%.1f%%", process.gpuPercent)
                )
            }
        }.value
    }
}
