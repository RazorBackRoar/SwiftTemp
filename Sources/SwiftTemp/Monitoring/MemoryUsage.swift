import Darwin
import Foundation

struct MemorySnapshot: Sendable {
    let usedGB: Double
    let totalGB: Double
}

enum MemoryUsage {
    /// Matches Activity Monitor's "Memory Used": App Memory + Wired + Compressed.
    /// App Memory = anonymous (internal) pages minus purgeable (reclaimable) pages;
    /// Wired = wired-down pages; Compressed = pages used by the VM compressor.
    static func current() -> MemorySnapshot {
        let totalGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824.0

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size
        )

        let result = withUnsafeMutablePointer(to: &stats) { pointer -> kern_return_t in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPointer in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPointer, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            AppLogger.system.error("host_statistics64(HOST_VM_INFO64) failed: \(result)")
            return MemorySnapshot(usedGB: 0, totalGB: totalGB)
        }

        var pageSizeValue: vm_size_t = 0
        let pageSizeResult = host_page_size(mach_host_self(), &pageSizeValue)
        guard pageSizeResult == KERN_SUCCESS else {
            AppLogger.system.error("host_page_size failed: \(pageSizeResult)")
            return MemorySnapshot(usedGB: 0, totalGB: totalGB)
        }

        let pageSize = Double(pageSizeValue)
        let appPages = max(0.0, Double(stats.internal_page_count) - Double(stats.purgeable_count))
        let usedPages = appPages + Double(stats.wire_count) + Double(stats.compressor_page_count)
        let usedGB = (usedPages * pageSize) / 1_073_741_824.0

        return MemorySnapshot(usedGB: usedGB, totalGB: totalGB)
    }
}
