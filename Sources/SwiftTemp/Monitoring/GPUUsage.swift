import Foundation

enum GPUUsage {
    static func current() async -> Double? {
        await Task.detached(priority: .utility) {
            blockingCurrent()
        }.value
    }

    private static func blockingCurrent() -> Double? {
        guard let output = runIOReg() else { return nil }
        return parsePerformanceStatistics(output)
    }

    private static func runIOReg() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/ioreg")
        process.arguments = ["-r", "-c", "AGXAccelerator", "-d", "2"]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0, !data.isEmpty else { return nil }
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    static func parsePerformanceStatistics(_ text: String) -> Double? {
        guard let startRange = text.range(of: "\"PerformanceStatistics\" = {") else { return nil }
        let tail = text[startRange.upperBound...]

        guard let endRange = tail.range(of: "}") else { return nil }
        let block = String(tail[..<endRange.lowerBound])

        if let range = block.range(of: "\"Device Utilization %\" = ") {
            let after = block[range.upperBound...]
            let number = after.prefix(while: { $0.isNumber || $0 == "." })
            return Double(number)
        }

        if let range = block.range(of: "\"Device Active\" = ") {
            let after = block[range.upperBound...]
            let number = after.prefix(while: { $0.isNumber || $0 == "." })
            if let value = Double(number) {
                return value * 100
            }
        }

        return nil
    }
}
