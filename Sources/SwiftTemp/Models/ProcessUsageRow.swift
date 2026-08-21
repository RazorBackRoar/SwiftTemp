import Foundation

struct ProcessUsageRow: Identifiable, Equatable, Sendable {
    var id: pid_t { pid }
    let pid: pid_t
    let name: String
    let detail: String
}