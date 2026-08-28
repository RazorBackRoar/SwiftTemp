import Foundation
import IOKit

actor GPUUsage {
    private let fallbackInterval: TimeInterval = 10
    private var registryAvailable: Bool?
    private var lastFallbackRead = Date.distantPast
    private var fallbackValue: Double?

    func current() async -> Double? {
        if registryAvailable != false {
            let value = await Task.detached(priority: .utility) {
                Self.fromRegistry()
            }.value
            if let value {
                registryAvailable = true
                return value
            }
            registryAvailable = false
        }

        let now = Date()
        guard now.timeIntervalSince(lastFallbackRead) >= fallbackInterval else {
            return fallbackValue
        }
        lastFallbackRead = now
        let value = await Task.detached(priority: .utility) {
            Self.parsePerformanceStatistics(Self.runIOReg() ?? "")
        }.value
        fallbackValue = value
        return value
    }

    private static func fromRegistry() -> Double? {
        guard let matching = IOServiceMatching("IOAccelerator") else { return nil }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS
        else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            let current = service
            service = IOIteratorNext(iterator)
            defer { IOObjectRelease(current) }

            var propertiesRef: Unmanaged<CFMutableDictionary>?
            guard
                IORegistryEntryCreateCFProperties(current, &propertiesRef, kCFAllocatorDefault, 0)
                    == KERN_SUCCESS,
                let properties = propertiesRef?.takeRetainedValue() as NSDictionary?,
                let stats = properties["PerformanceStatistics"] as? NSDictionary
            else {
                continue
            }

            if let value = doubleValue(
                in: stats, keys: ["Device Utilization %", "Renderer Utilization %"])
            {
                return min(100, max(0, value))
            }
            if let active = doubleValue(in: stats, keys: ["Device Active"]) {
                return min(100, max(0, active <= 1 ? active * 100 : active))
            }
        }
        return nil
    }

    private static func doubleValue(in stats: NSDictionary, keys: [String]) -> Double? {
        for key in keys {
            if let number = stats[key] as? NSNumber {
                return number.doubleValue
            }
        }
        return nil
    }

    private static func runIOReg() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/ioreg")
        process.arguments = ["-r", "-c", "AGXAccelerator", "-d", "1"]

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

    /// Accepts both spaced (`"key" = 12`) and compact (`"key"=12`) ioreg dumps.
    static func parsePerformanceStatistics(_ text: String) -> Double? {
        if let value = firstNumber(afterKey: "\"Device Utilization %\"", in: text)
            ?? firstNumber(afterKey: "\"Renderer Utilization %\"", in: text)
        {
            return min(100, max(0, value))
        }
        if let active = firstNumber(afterKey: "\"Device Active\"", in: text) {
            return min(100, max(0, active <= 1 ? active * 100 : active))
        }
        return nil
    }

    private static func firstNumber(afterKey key: String, in text: String) -> Double? {
        guard let keyRange = text.range(of: key) else { return nil }
        var index = keyRange.upperBound
        while index < text.endIndex, text[index].isWhitespace {
            index = text.index(after: index)
        }
        guard index < text.endIndex, text[index] == "=" else { return nil }
        index = text.index(after: index)
        while index < text.endIndex, text[index].isWhitespace {
            index = text.index(after: index)
        }
        let number = text[index...].prefix(while: { $0.isNumber || $0 == "." })
        return Double(number)
    }
}
