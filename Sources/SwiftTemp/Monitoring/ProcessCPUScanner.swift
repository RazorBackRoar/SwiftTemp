import Darwin
import Foundation

struct ProcessCPUInfo: Identifiable, Sendable {
    let id: pid_t
    let pid: pid_t
    let name: String
    let cpuPercent: Double
}

final class ProcessCPUScanner {
    private var previousTaskTimes: [pid_t: (user: UInt64, system: UInt64, time: ContinuousClock.Instant)] = [:]
    private let clock = ContinuousClock()

    func reset() {
        previousTaskTimes.removeAll(keepingCapacity: true)
    }

    func topProcesses(limit: Int = 3) -> [ProcessCPUInfo] {
        let pidSize = MemoryLayout<pid_t>.size
        let estimatedBytes = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard estimatedBytes > 0 else { return [] }

        var pids = [pid_t](repeating: 0, count: (Int(estimatedBytes) / pidSize) + 64)
        let bytesWritten = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, Int32(pidSize * pids.count))
        guard bytesWritten > 0 else { return [] }

        let count = min(pids.count, Int(bytesWritten) / pidSize)
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let now = clock.now
        let maximumPercent = Double(max(1, ProcessInfo.processInfo.activeProcessorCount)) * 100

        var currentTimes: [pid_t: (user: UInt64, system: UInt64, time: ContinuousClock.Instant)] = [:]
        currentTimes.reserveCapacity(count)
        var cpuInfos: [ProcessCPUInfo] = []

        for pid in pids.prefix(count) {
            guard pid > 0, pid != currentPID else { continue }

            var info = proc_taskinfo()
            let size = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, Int32(MemoryLayout<proc_taskinfo>.size))
            guard size == MemoryLayout<proc_taskinfo>.size else { continue }

            currentTimes[pid] = (info.pti_total_user, info.pti_total_system, now)
            guard let previous = previousTaskTimes[pid] else { continue }

            let duration = previous.time.duration(to: now)
            let elapsedSeconds = Double(duration.components.seconds)
                + Double(duration.components.attoseconds) / 1_000_000_000_000_000_000
            guard elapsedSeconds >= 0.5 else { continue }

            let userDelta = info.pti_total_user >= previous.user ? info.pti_total_user - previous.user : 0
            let systemDelta = info.pti_total_system >= previous.system ? info.pti_total_system - previous.system : 0
            let usedSeconds = Double(userDelta + systemDelta) / 1_000_000_000
            let percent = min(maximumPercent, max(0, (usedSeconds / elapsedSeconds) * 100))

            if percent >= 1 {
                let name = processName(for: pid) ?? "PID \(pid)"
                cpuInfos.append(ProcessCPUInfo(id: pid, pid: pid, name: name, cpuPercent: percent))
            }
        }

        previousTaskTimes = currentTimes
        cpuInfos.sort { $0.cpuPercent > $1.cpuPercent }
        return Array(cpuInfos.prefix(limit))
    }

    private func processName(for pid: pid_t) -> String? {
        var nameBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        let size = proc_name(pid, &nameBuffer, UInt32(nameBuffer.count))
        guard size > 0 else { return nil }
        return String(cString: nameBuffer)
    }
}
