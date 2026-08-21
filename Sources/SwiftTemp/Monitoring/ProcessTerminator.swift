import Darwin
import Foundation

enum ProcessTerminator {
    /// Sends SIGTERM (graceful) or SIGKILL (force). The process name is
    /// rechecked immediately before signaling to reduce the risk from PID
    /// reuse between the displayed snapshot and the user action.
    @discardableResult
    static func terminate(process: ProcessMemoryInfo, force: Bool) -> Bool {
        guard currentName(for: process.pid) == process.name else {
            AppLogger.system.error("Refusing to signal PID \(process.pid, privacy: .public) because the process identity changed")
            return false
        }

        let signal: Int32 = force ? SIGKILL : SIGTERM
        let result = kill(process.pid, signal)
        if result != 0 {
            AppLogger.system.error(
                "kill(pid: \(process.pid, privacy: .public), signal: \(signal, privacy: .public)) failed, errno \(errno, privacy: .public)"
            )
        }
        return result == 0
    }

    private static func currentName(for pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        let length = proc_name(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        return String(decoding: buffer.prefix(Int(length)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}
