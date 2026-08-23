# SwiftTemp

[![Download](https://img.shields.io/github/v/release/RazorBackRoar/SwiftTemp?style=for-the-badge&label=Download%20DMG&color=d32f2f)](https://github.com/RazorBackRoar/SwiftTemp/releases/latest)
[![Version](https://img.shields.io/badge/version-1.0.0-blue?style=for-the-badge)](https://github.com/RazorBackRoar/SwiftTemp/releases/tag/v1.0.0)
[![CI](https://img.shields.io/github/actions/workflow/status/RazorBackRoar/SwiftTemp/ci.yml?branch=main&style=for-the-badge&label=CI)](https://github.com/RazorBackRoar/SwiftTemp/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blueviolet?style=for-the-badge)](LICENSE)
[![Swift](https://img.shields.io/badge/Swift-F05138?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org/)
[![macOS](https://img.shields.io/badge/mac%20os-Apple%20Silicon-d32f2f?style=for-the-badge&logo=apple&logoColor=white)](https://support.apple.com/en-us/HT211814)

<!-- Workspace Health Layer -->
![Status](https://img.shields.io/badge/status-active-2ea44f?style=for-the-badge)
![Tests](https://img.shields.io/badge/tests-present-2ea44f?style=for-the-badge)
![Build](https://img.shields.io/badge/build-swift-F05138?style=for-the-badge)

A lightweight native macOS menu bar utility for Apple Silicon Macs. It shows Apple’s supported system thermal state alongside CPU usage, memory usage, fan speed when available, and an experimental chip-temperature reading.

Most features use public macOS APIs (`ProcessInfo.thermalState`, Mach host statistics, Swift Charts, `UserNotifications`, and `ServiceManagement`). Degree and fan readings are different: macOS exposes no supported public API for them, so SwiftTemp uses the private, undocumented AppleSMC interface and clearly treats those values as experimental.

The app is built and packaged for arm64 on macOS 14 or later. Private sensor availability and key meanings vary by Mac model and macOS release; unsupported readings fail closed as “Unavailable” rather than being estimated from unrelated sensors.

---

## Table of contents

- [Download](#download)
- [What it does](#what-it-does)
- [Degree readings (private API, experimental)](#degree-readings-private-api-experimental)
- [Memory breakdown & killing processes](#memory-breakdown--killing-processes)
- [What's not included, and why](#whats-not-included-and-why)
- [Requirements](#requirements)
- [Project structure](#project-structure)
- [Building & running](#building--running)
- [Using the app](#using-the-app)
- [Settings reference](#settings-reference)
- [Customizing](#customizing)
- [Troubleshooting](#troubleshooting)
- [Download](#download)
- [Possible extensions](#possible-extensions-not-implemented-here)

## Download

The latest release is available on the [Releases page](https://github.com/RazorBackRoar/SwiftTemp/releases/latest) as a signed DMG.

---

## What it does

- Lives entirely in the menu bar by default — no Dock icon, no
  app-switcher entry (optionally toggleable in Settings).
- **Menu bar display** — configurable as icon only, temperature only, or temperature plus CPU and memory. The selected Celsius/Fahrenheit unit is respected everywhere.
- **Popover** (click the menu bar item) shows:
  - Thermal state (Nominal / Fair / Serious / Critical), color-coded
    green → yellow → red → purple
  - Experimental hottest compute-sensor temperature (°F by default, °C optional) when a plausible private SMC key is available — “Unavailable” otherwise
  - CPU usage %
  - GPU usage % when the Apple GPU reports utilization through IORegistry
  - Memory used / total (GB), with a link to the full process breakdown
  - Last-updated timestamp
  - Current monitoring status, with a **Pause/Resume Monitoring** control
  - A live, bounded-point chip-temperature history graph (Swift Charts), colored yellow → orange → red → purple by measured value
- **Memory breakdown window** — per-process memory, largest first, with a
  one-click **Quit** (right-click for **Force Quit**); local-AI runtimes
  (Ollama, LM Studio, etc.) are flagged when detected by name.
- **Opt-in local notifications** for serious/critical Apple thermal-state transitions and, separately, an experimental chip-sensor threshold. Permission is requested only when an alert is enabled.
- **Launch at login**, via `ServiceManagement`'s `SMAppService`.
- **Settings window** (⌘,) — temperature unit, refresh interval, menu bar
  display mode, Dock icon visibility, launch at login, notification
  threshold, graph window length, history retention length, verbose
  logging.
- Logs thermal transitions, errors, SMC sensor discovery, and (optionally)
  every sample via `os.Logger`, viewable in Console.app under subsystem
  `com.razorbackroar.swifttemp`.

## Degree readings (private API, experimental)

Apple’s supported thermal API on macOS is `ProcessInfo.thermalState`: a system-wide pressure state, not a temperature in degrees. SwiftTemp treats this as the authoritative health signal.

To provide an optional degree value, `SMCConnection.swift` uses the private AppleSMC IOKit protocol. Apple does not document this protocol or guarantee stable sensor keys. The implementation decodes Apple Silicon `flt` values as little-endian IEEE-754 and legacy `sp78` values as big-endian signed 8.8 fixed point.

At launch, sensor discovery runs off the main actor. SwiftTemp accepts only plausible compute-family keys (`Tp*`, `Te*`, and `Tg*`), retains the 12 hottest initial candidates to bound recurring IOKit work, and displays the hottest current tracked reading. It intentionally does **not** treat `TCHP` as “SoC average”; public reverse-engineering references associate that key with charger/heat-pipe temperature. If no plausible compute key is available, the degree value and graph remain unavailable.

This value is a model-dependent chip-sensor reading, not an Apple overheating diagnosis. Normal Apple Silicon temperatures vary by model and workload. Color is a visual progression only; Apple’s Nominal/Fair/Serious/Critical thermal state determines actual system pressure.

All private reads are optional and range-checked. A failed connection, unknown format, unexpected key table, or unsupported machine returns “Unavailable” without blocking CPU/memory/thermal-state monitoring.

## Memory breakdown & killing processes

Click **View Memory Breakdown…** in the popover (or under the Memory
Used row) to open a separate window listing every process the current
user can inspect, sorted largest-first, via the macOS `libproc` interfaces (`proc_listallpids`, `proc_pidinfo`, and `proc_name`).

- **Quit** sends `SIGTERM` (graceful); right-click a row → **Force Quit**
  sends `SIGKILL`. Both require confirmation first.
- macOS applies normal process-signal permissions. SwiftTemp excludes itself, requires confirmation, and rechecks the process name before signaling to reduce PID-reuse risk. It can still quit important user-owned processes such as Finder or Dock, so review the target carefully.
- Processes with "ollama," "lm studio," "llama," etc. in their name are
  labeled "Local AI workload" as a highlight, not a filter — everything
  else still shows up sorted by size the same way.
- Top 15 shown at a time; window doesn't auto-refresh (data can go stale
  between opens) — use **Refresh**.

## What's not included, and why

GPU utilization is read through the private `AGXAccelerator` IORegistry interface when available; it may report "Not Available" on some configurations because there is no stable public macOS API for system-wide GPU usage. Fan RPM is shown only when the same private SMC path reports a plausible fan count and speed. Graph zoom/pan is intentionally omitted to keep the compact popover predictable and inexpensive.

---

## Requirements

- **macOS 14 (Sonoma) or later** — `Observation` (`@Observable`),
  `MenuBarExtra`, `@Bindable`, and `Settings { }`'s modern APIs all need
  this baseline.
- **Xcode 16+ / Swift 6 toolchain.**
- **Apple Silicon Mac** (arm64). Untested on Intel.

```bash
swift --version
```

---

## Project structure

```text
SwiftTemp/
├── Package.swift
├── README.md
├── Resources/
│   └── AppIcon.icns
├── Tests/
│   └── SwiftTempTests/
│       └── SwiftTempTests.swift
├── scripts/
│   └── build-mac.sh                     # Release build → double-clickable .app
└── Sources/
    └── SwiftTemp/
        ├── SwiftTempApp.swift           # @main entry, MenuBarExtra + Settings scenes
        ├── AppDelegate.swift            # Initial Dock-icon policy
        ├── Models/
        │   ├── ThermalState+Extensions.swift   # Label/icon/color per thermal state
        │   ├── SystemSample.swift              # One historical data point
        │   ├── ProcessMemoryInfo.swift          # One process's memory reading
        │   └── Temperature.swift                # C→F formatting (pure math, no private API)
        ├── Monitoring/
        │   ├── SystemMonitor.swift      # @Observable — state, timer, history, pause/resume
        │   ├── CPUUsage.swift           # host_statistics-based CPU % calc
        │   ├── MemoryUsage.swift        # host_statistics64-based memory calc
        │   ├── ProcessCPUScanner.swift  # On-demand libproc CPU process scan
        │   ├── ProcessMemoryScanner.swift # libproc-based per-process memory scan
        │   └── ProcessTerminator.swift  # kill() wrapper for Quit/Force Quit
        ├── PrivateSensors/
        │   ├── SMCConnection.swift      # Private SMC/IOKit client and value decoding
        │   └── SMCTemperatureReader.swift # Actor-isolated sensor discovery and snapshots
        ├── Views/
        │   ├── MenuBarLabel.swift       # Menu bar icon/text, respects display mode
        │   ├── MenuContentView.swift    # Popover content
        │   ├── HistoryGraphView.swift   # Swift Charts temperature history
        │   ├── MemoryBreakdownView.swift # Per-process memory window, Quit/Force Quit
        │   └── ThermostatIcon.swift     # Lightweight Canvas menu-bar symbol
        ├── Settings/
        │   ├── AppSettings.swift        # @Observable, UserDefaults-backed settings
        │   ├── SettingsView.swift       # Settings window (General/Alerts/History)
        │   └── LaunchAtLoginToggle.swift # SMAppService-backed toggle
        ├── Notifications/
        │   └── ThermalNotifier.swift    # UNUserNotificationCenter wrapper
        └── Logging/
            └── AppLogger.swift          # os.Logger instances
```

Plain **Swift Package Manager (SPM)** project — no `.xcodeproj`, matching
how Libra/Looper/MetaBurn/Swifter are set up in your `RazorBackRoar`
monorepo. Xcode opens `Package.swift` directly. Drops into
`~/Workspace/Apps/SwiftTemp` if you want it alongside your other
Swift apps.

---

## Building & running

### Option A — Xcode

1. Double-click `Package.swift` (or **File → Open…** the folder).
2. Select the **SwiftTemp** scheme.
3. **⌘R** to run, **⌘B** to build.
4. Menu bar icon appears top-right; no Dock icon by default.

### Option B — Terminal

```bash
swift run              # debug build + run, foreground
swift build             # debug build only
swift build -c release  # optimized build
```

Bare binary from a release build:

```bash
$(swift build -c release --show-bin-path)/SwiftTemp
```

Runnable directly, but it's not a `.app` bundle — no icon, no Login Items
entry, and **notifications/launch-at-login are unreliable this way** (see
below). Use the build script for real use.

### Option C — Build script (recommended)

```bash
./scripts/build-mac.sh
```

Release build → `build/Release/SwiftTemp.dmg` with a properly
assembled, ad-hoc signed `SwiftTemp.app` inside.

Open the DMG and drag `SwiftTemp.app` into `/Applications/`.

Then, if wanted: **System Settings → General → Login Items & Extensions**
to add it manually, or use the in-app **Launch at login** toggle once
it's actually running from `/Applications`.

---

## Using the app

- **Menu bar item** — click to open the popover. Shape/color/opacity
  reflect thermal state and whether monitoring is paused.
- **Pause/Resume Monitoring** — stops or resumes sampling; while paused,
  displayed values stay frozen at their last reading (the popover's
  "Monitoring: Paused" row makes this explicit).
- **History graph** — shows experimental chip-sensor temperature over the configured time window. Rendering is capped at roughly 180 points while full retained history remains in memory.
- **View Memory Breakdown…** — opens a separate window with per-process
  memory, largest first; **Quit** per row, right-click for **Force
  Quit**. See [Memory breakdown & killing processes](#memory-breakdown--killing-processes).
- **Refresh Now** — forces an immediate sample.
- **Settings…** (⌘,) — opens the Settings window.
- **Quit SwiftTemp** — exits cleanly.

---

## Settings reference

### General

- *Temperature unit* — Fahrenheit / Celsius. Default **Fahrenheit**; applies to the menu bar, popover, graph, and accessibility text.
- *Refresh interval* — 1/2/5/10/30/60 seconds. Default **2 seconds**. Polling is rescheduled immediately with run-loop tolerance for timer coalescing.
- *Menu bar* — Icon Only / Temperature Only / Temperature + System Stats.
- *Allow top CPU process details* — process enumeration runs only while the expandable details are visible.
- *Show Dock icon* — off by default; updates the activation policy without relaunching.
- *Launch at login* — uses `SMAppService.mainApp` and reports when System Settings approval is required.

### Alerts

- *Thermal-state alerts* — Off / Serious or Critical / Critical Only. Default **Off**.
- *Experimental temperature threshold* — separate opt-in toggle and 130–200°F threshold. It alerts on an upward crossing and rearms after dropping 5°F below the threshold.
- Notification permission is requested in context when either alert feature is enabled, not on first launch.

### History

- *Graph shows* — 1/5/15/60 minutes. Default **15 minutes**.
- *Keep history* — 1/5/15/60 minutes. Default **60 minutes**. Retention is time-based and remains correct when the polling interval changes.
- *Verbose diagnostic logging* — logs each sample at debug level. History remains in memory only and is cleared at quit.

---

## Customizing

- **Add option values** (e.g. a 15s refresh interval) — edit
  `AppSettings.pollIntervalOptions` / `.historyWindowOptions`.
- **Menu bar popover style** — `.menuBarExtraStyle(.window)` in
  `SwiftTempApp.swift` gives the current custom floating panel. `.menu`
  gives a native dropdown look instead; you'd want to simplify
  `MenuContentView` (drop the graph, most `Form`-style layout) since plain
  `NSMenu` content is more restrictive.
- **Renaming the app**:
  1. Rename `Sources/SwiftTemp` folder.
  2. Update `name:`/`.executableTarget` `name:`/`path:` in `Package.swift`.
  3. Rename `SwiftTempApp.swift` and `struct SwiftTempApp`.
  4. Update `APP_NAME`/`BUNDLE_ID` in `scripts/build-mac.sh`.
  5. Update the subsystem string in `Logging/AppLogger.swift`.
- **App icon** — `Sources/SwiftTemp/Resources/AppIcon.icns`; picked up
  automatically by `scripts/build-mac.sh`.

---

## Troubleshooting

**"Can't be opened because it is from an unidentified developer"** —
expected for a locally-built, ad-hoc-signed app. Right-click → **Open**
once, or allow it in **System Settings → Privacy & Security**.

**No menu bar icon** — check Console.app for crashes. If not crashing,
check menu bar overflow / Control Center settings if your menu bar is
crowded.

**Shows up in the Dock unexpectedly** — check the **Show Dock icon**
setting; confirm you're running the actual built `.app`, not a stray old
binary.

**Settings window won't open** — `openSettings()` (via
`@Environment(\.openSettings)`) requires macOS 14+; confirm your deployment
target/SDK actually matches `platforms: [.macOS(.v14)]` in `Package.swift`.

**Notifications never appear** — run the built `.app`, enable at least one alert in Settings, and confirm macOS granted notification permission under System Settings → Notifications → SwiftTemp.

**Launch at login toggle doesn't stick** — same root cause as
notifications: `SMAppService` needs a real, stable bundle at a normal
location (`/Applications`), not a `swift run` process. Check Console.app
for `Launch-at-login change failed` log entries.

**Graph says “Waiting for sensor data”** — the chart needs at least two valid private compute-sensor samples. CPU, memory, fan, and Apple Thermal State monitoring continue even when degree data is unavailable.

**Build error about `@Observable`/`Observation`/`@Bindable`** — toolchain
older than Swift 5.9 or SDK older than macOS 14. Update Xcode.

**Build error in `CPUUsage.swift`/`MemoryUsage.swift`** (Mach types) — API
names are correct as of current SDKs; if something doesn't resolve, check
for a renamed field in `<mach/host_info.h>`/`<mach/vm_statistics.h>` in
your SDK version. Both files already `import Darwin`.

**CPU usage reads 0% right after launch** — expected; the calculation
needs two consecutive samples to compute a delta.

**Temperature always shows “Unavailable”** — the SMC connection could not be opened, or no `Tp*`, `Te*`, or `Tg*` key decoded to a plausible value. Check Console.app (subsystem `com.razorbackroar.swifttemp`) for the compute-temperature discovery count. This is the expected safe failure mode; see [Degree readings](#degree-readings-private-api-experimental).

**Temperature looks wrong** — treat it as unsupported sensor data rather than an overheating diagnosis. Disable experimental threshold alerts and report the sensor key shown by the row’s Help tooltip together with the Mac model and macOS version.

**Build error in `SMCConnection.swift`** (`IOServiceGetMatchingService`,
`IOConnectCallStructMethod`, etc. not found) — confirm `import IOKit`
resolves at all on your SDK; these are real, public IOKit functions (only
the SMC-specific selectors/struct-layout built on top are private), so a
missing-symbol error here would be unusual and worth flagging directly.

**Memory Breakdown window doesn't open** — same `openWindow`/macOS 14+
requirement as Settings above; also confirm `Window("Memory Breakdown",
id: "memoryBreakdown")` in `SwiftTempApp.swift` wasn't accidentally
dropped.

**Quit/Force Quit doesn't seem to do anything** — `kill()` silently fails
(returns nonzero, logged) for processes you don't own; check Console.app
for a `kill(...) failed` line with an errno. `EPERM` (1) means permission
was correctly denied by the OS, not a bug.

---

## Possible extensions (not implemented here)

- Graph zoom/pan for longer retained histories.
- Optional CSV export with an explicit save panel.
- Auto-refresh for the memory breakdown window. It remains manual by design so opening the main popover does not create another background polling loop.
- Model-specific sensor mappings backed by independently verified hardware data.
