# SwiftTemp AGENTS

Guidance for agents in this repository. Use with `../AGENTS.md`.

## Branding

| Surface | Value |
|---------|-------|
| Display name | **SwiftTemp** |
| GitHub | `RazorBackRoar/SwiftTemp` |
| `appId` | `com.razorbackroar.swifttemp` |
| Executable | `SwiftTemp` |

## Purpose and entry points

Native macOS menu bar thermal monitor for Apple Silicon.

- App entry: `Sources/SwiftTemp/SwiftTempApp.swift`
- Models: `Sources/SwiftTemp/Models/`
- Monitoring: `Sources/SwiftTemp/Monitoring/`
- Settings: `Sources/SwiftTemp/Settings/`
- Views: `Sources/SwiftTemp/Views/`
- Notifications: `Sources/SwiftTemp/Notifications/`
- Private sensors: `Sources/SwiftTemp/PrivateSensors/`

## Commands

```zsh
swift build
swift test
```

`swift test` requires the full Xcode.app. The project uses Swift 6 language mode.

Package a macOS `.app` and DMG with ad-hoc signing:

```zsh
./scripts/build-mac.sh
```

Local output: `build/Release/SwiftTemp.dmg`.

## Learned User Preferences

- CPU and GPU rows must open process-breakdown windows the same way Memory does — click to see which processes are using them.
- Menu bar popover and Settings chrome must stay high-contrast and fully visible; do not truncate the Settings label.

## Learned Workspace Facts

- SwiftTemp is a RazorBackRoar product app at v1.0.0 (`Sources/SwiftTemp/Resources/version.json`); native Swift 6 menu bar thermal monitor for Apple Silicon.
- After a new install, quit the previous menu bar extra or the old UI stays on screen.

## Repository rules

- Do not create branches unless explicitly requested.
- Do not commit, push, or create branches unless explicitly requested.
