import Darwin
import Foundation
import IOKit

struct ProcessGPUInfo: Identifiable, Sendable {
    let id: pid_t
    let pid: pid_t
    let name: String
    let gpuPercent: Double
    let accumulatedNanoseconds: UInt64
}

/// Ranks processes by Metal GPU time from `AGXDeviceUserClient` `AppUsage`.
enum ProcessGPUScanner {
    private struct Accumulated {
        var name: String
        var nanoseconds: UInt64
    }

    static func rankedSnapshot(limit: Int = 15, sampleSeconds: Double = 0.6) async
        -> [ProcessGPUInfo]
    {
        let first = accumulatedTimesByPID()
        try? await Task.sleep(for: .seconds(max(0.4, sampleSeconds)))
        let second = accumulatedTimesByPID()
        let elapsed = max(0.4, sampleSeconds)
        let pids = Set(first.keys).union(second.keys)

        var results: [ProcessGPUInfo] = []
        results.reserveCapacity(pids.count)
        for pid in pids {
            let before = first[pid]
            let after = second[pid]
            let total = after?.nanoseconds ?? before?.nanoseconds ?? 0
            let delta = {
                let start = before?.nanoseconds ?? 0
                let end = after?.nanoseconds ?? start
                return end >= start ? end - start : 0
            }()
            let percent = Double(delta) / (elapsed * 1_000_000_000) * 100
            if percent < 0.05 && total == 0 { continue }
            let name =
                processName(for: pid)
                ?? after?.name
                ?? before?.name
                ?? "PID \(pid)"
            results.append(
                ProcessGPUInfo(
                    id: pid,
                    pid: pid,
                    name: name,
                    gpuPercent: min(999, max(0, percent)),
                    accumulatedNanoseconds: total
                )
            )
        }

        results.sort {
            if $0.gpuPercent != $1.gpuPercent { return $0.gpuPercent > $1.gpuPercent }
            return $0.accumulatedNanoseconds > $1.accumulatedNanoseconds
        }
        return Array(results.prefix(limit))
    }

    static func parseCreator(_ raw: String) -> (pid: pid_t, name: String)? {
        guard raw.hasPrefix("pid ") else { return nil }
        let rest = raw.dropFirst(4)
        guard let comma = rest.firstIndex(of: ",") else { return nil }
        let pidText = rest[..<comma].trimmingCharacters(in: .whitespaces)
        guard let pid = pid_t(pidText), pid > 0 else { return nil }
        let name = rest[rest.index(after: comma)...].trimmingCharacters(in: .whitespaces)
        return (pid, name.isEmpty ? "PID \(pid)" : name)
    }

    static func accumulatedGPUTime(fromAppUsage usage: Any?) -> UInt64 {
        guard let entries = usage as? [Any] else { return 0 }
        var total: UInt64 = 0
        for entry in entries {
            guard let dict = entry as? [String: Any] else { continue }
            if let number = dict["accumulatedGPUTime"] as? NSNumber {
                total += number.uint64Value
            }
        }
        return total
    }

    static func accumulatedTimesByPID() -> [pid_t: (name: String, nanoseconds: UInt64)] {
        var totals: [pid_t: Accumulated] = [:]
        forEachUserClient { properties in
            guard let creator = properties["IOUserClientCreator"] as? String,
                let parsed = parseCreator(creator)
            else { return }
            let extra = accumulatedGPUTime(fromAppUsage: properties["AppUsage"])
            var current = totals[parsed.pid] ?? Accumulated(name: parsed.name, nanoseconds: 0)
            current.nanoseconds += extra
            if current.name.count < parsed.name.count {
                current.name = parsed.name
            }
            totals[parsed.pid] = current
        }

        var result: [pid_t: (name: String, nanoseconds: UInt64)] = [:]
        result.reserveCapacity(totals.count)
        for (pid, value) in totals {
            result[pid] = (value.name, value.nanoseconds)
        }
        return result
    }

    private static func forEachUserClient(_ body: (NSDictionary) -> Void) {
        guard let matching = IOServiceMatching("IOAccelerator") else { return }
        var acceleratorIterator: io_iterator_t = 0
        guard
            IOServiceGetMatchingServices(kIOMainPortDefault, matching, &acceleratorIterator)
                == KERN_SUCCESS
        else {
            return
        }
        defer { IOObjectRelease(acceleratorIterator) }

        var accelerator = IOIteratorNext(acceleratorIterator)
        while accelerator != 0 {
            let currentAccelerator = accelerator
            accelerator = IOIteratorNext(acceleratorIterator)
            defer { IOObjectRelease(currentAccelerator) }

            var childIterator: io_iterator_t = 0
            guard
                IORegistryEntryGetChildIterator(currentAccelerator, kIOServicePlane, &childIterator)
                    == KERN_SUCCESS
            else {
                continue
            }
            defer { IOObjectRelease(childIterator) }

            var child = IOIteratorNext(childIterator)
            while child != 0 {
                let current = child
                child = IOIteratorNext(childIterator)
                defer { IOObjectRelease(current) }

                var propertiesRef: Unmanaged<CFMutableDictionary>?
                guard
                    IORegistryEntryCreateCFProperties(
                        current, &propertiesRef, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                    let properties = propertiesRef?.takeRetainedValue() as NSDictionary?,
                    properties["IOUserClientCreator"] != nil
                else {
                    continue
                }
                body(properties)
            }
        }
    }

    private static func processName(for pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        let length = proc_name(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        return String(
            decoding: buffer.prefix(Int(length)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}
