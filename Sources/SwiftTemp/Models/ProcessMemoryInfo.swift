import Foundation

struct ProcessMemoryInfo: Identifiable, Equatable, Sendable {
    let id: Int32
    let pid: Int32
    let name: String
    let memoryBytes: UInt64

    var memoryGB: Double {
        Double(memoryBytes) / 1_073_741_824.0
    }
}
