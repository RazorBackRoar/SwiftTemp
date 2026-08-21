# Build & Release — SwiftTemp

Organization-standard build and release guide for
[RazorBackRoar/SwiftTemp](https://github.com/RazorBackRoar/SwiftTemp).

## Overview

SwiftTemp is a native macOS menu bar thermal monitor built with **Swift** and **SwiftUI**.

## Development

```zsh
swift build
swift run
```

## Packaging

```zsh
./scripts/build-mac.sh
# Output: build/Release/SwiftTemp.dmg
```

## Release Process

1. Ensure `main` is green (CI `swift build`).
2. Confirm the version in `Sources/SwiftTemp/Resources/version.json`.
3. Run `./scripts/build-mac.sh`.
4. Smoke-test the packaged `.app` from the DMG.
5. Publish a GitHub Release and attach `build/Release/SwiftTemp.dmg`.
6. Tag `vX.Y.Z` to match the version file.
