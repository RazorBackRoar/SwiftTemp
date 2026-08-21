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

`swift test` requires the full Xcode.app.

Package a macOS `.app` and DMG with ad-hoc signing:

```zsh
./scripts/build-mac.sh
```

Output: `build/Release/SwiftTemp.dmg` only.

## Repository rules

- Do not create branches unless explicitly requested.
- Do not commit, push, or create branches unless explicitly requested.
