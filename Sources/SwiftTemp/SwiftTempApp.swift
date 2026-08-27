import SwiftUI

@main
struct SwiftTempApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var settings: AppSettings
    @State private var monitor: SystemMonitor

    init() {
        let settings = AppSettings()
        _settings = State(initialValue: settings)
        _monitor = State(initialValue: SystemMonitor(settings: settings))
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(monitor: monitor, settings: settings)
        } label: {
            MenuBarLabel(monitor: monitor, settings: settings)
        }
        .menuBarExtraStyle(.window)

        Window("Memory Breakdown", id: "memoryBreakdown") {
            MemoryBreakdownView()
        }
        .defaultSize(width: 480, height: 420)
        .defaultPosition(.center)
        .windowResizability(.contentMinSize)
        .defaultLaunchBehavior(.suppressed)

        Window("CPU Breakdown", id: "cpuBreakdown") {
            ProcessBreakdownView(
                title: "CPU Breakdown",
                subtitle: "Highest CPU first — right-click a row for Force Quit.",
                systemImage: "cpu",
                accent: .green,
                load: ProcessBreakdownLoaders.cpu
            )
        }
        .defaultSize(width: 480, height: 420)
        .defaultPosition(.center)
        .windowResizability(.contentMinSize)
        .defaultLaunchBehavior(.suppressed)

        Window("GPU Breakdown", id: "gpuBreakdown") {
            ProcessBreakdownView(
                title: "GPU Breakdown",
                subtitle: "Highest Metal GPU time first — right-click a row for Force Quit.",
                systemImage: "display",
                accent: .blue,
                load: ProcessBreakdownLoaders.gpu
            )
        }
        .defaultSize(width: 480, height: 420)
        .defaultPosition(.center)
        .windowResizability(.contentMinSize)
        .defaultLaunchBehavior(.suppressed)

        Settings {
            SettingsView(settings: settings, monitor: monitor)
        }
    }
}
