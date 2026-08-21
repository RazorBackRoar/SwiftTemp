import Darwin

enum CPUUsage {
    /// Computes overall CPU usage (0...100) as the delta between two
    /// `host_cpu_load_info` samples. Pass the previous sample by reference;
    /// it is updated in place after each call. The first call after launch
    /// (or after a reset) has no prior sample to diff against and returns 0.
    static func currentTotalUsage(previous: inout host_cpu_load_info?) -> Double {
        var load = host_cpu_load_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size
        )

        let result = withUnsafeMutablePointer(to: &load) { pointer -> kern_return_t in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPointer in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, intPointer, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            AppLogger.system.error("host_statistics(HOST_CPU_LOAD_INFO) failed: \(result)")
            return 0
        }

        defer { previous = load }

        guard let previous else {
            return 0
        }

        let userDelta = Double(load.cpu_ticks.0 &- previous.cpu_ticks.0)
        let systemDelta = Double(load.cpu_ticks.1 &- previous.cpu_ticks.1)
        let idleDelta = Double(load.cpu_ticks.2 &- previous.cpu_ticks.2)
        let niceDelta = Double(load.cpu_ticks.3 &- previous.cpu_ticks.3)

        let totalDelta = userDelta + systemDelta + idleDelta + niceDelta
        guard totalDelta > 0 else { return 0 }

        let busyDelta = userDelta + systemDelta + niceDelta
        return min(max((busyDelta / totalDelta) * 100, 0), 100)
    }
}
