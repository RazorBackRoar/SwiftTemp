#!/usr/bin/env swift

import Foundation

let script = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("generate-icon.py")

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
process.arguments = ["uv", "run", "--with", "pillow", "python3", script.path]
try process.run()
process.waitUntilExit()
exit(process.terminationStatus)
