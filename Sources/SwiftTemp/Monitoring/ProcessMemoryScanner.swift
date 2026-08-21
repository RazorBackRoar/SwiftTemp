import Darwin
import Foundation

/// Snapshots per-process resident memory using macOS `libproc` APIs.
/// Processes that cannot be inspected are skipped, and this app's own
/// process is excluded.
enum ProcessMemoryScanner {
    static func snapshot() -> [ProcessMemoryInfo] {
        let currentPID = ProcessInfo.processInfo.processIdentifier

        let estimatedCount = proc_listallpids(nil, 0)
        guard estimatedCount > 0 else { return [] }

        // Padding in case processes are created between the sizing call
        // above and the fetch below.
        var pids = [pid_t](repeating: 0, count: Int(estimatedCount) + 64)
        let returnedCount = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size))
        guard returnedCount > 0 else { return [] }

        let actualCount = min(Int(returnedCount), pids.count)

        var results: [ProcessMemoryInfo] = []
        results.reserveCapacity(actualCount)

        for index in 0..<actualCount {
            let pid = pids[index]
            guard pid > 0, pid != currentPID else { continue }
            guard let info = taskInfo(for: pid), info.pti_resident_size > 0 else { continue }

            let name = processName(for: pid) ?? "pid \(pid)"
            results.append(
                ProcessMemoryInfo(id: pid, pid: pid, name: name, memoryBytes: info.pti_resident_size)
            )
        }

        return results.sorted { $0.memoryBytes > $1.memoryBytes }
    }

    private static func taskInfo(for pid: pid_t) -> proc_taskinfo? {
        var info = proc_taskinfo()
        let size = Int32(MemoryLayout<proc_taskinfo>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer -> Int32 in
            proc_pidinfo(pid, PROC_PIDTASKINFO, 0, pointer, size)
        }
        guard result == size else { return nil }
        return info
    }

    private static func processName(for pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        let length = proc_name(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        return String(decoding: buffer.prefix(Int(length)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}
