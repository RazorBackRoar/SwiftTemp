import Foundation
import IOKit

// MARK: - Low-level SMC wire structures
//
// These mirror the long-standing SMC user-client structures that were
// originally reverse-engineered on Intel Macs and have been independently
// reproduced across many open source SMC tools for well over a decade —
// a de facto standard even though Apple has never published or supported
// this for third-party use. The calling mechanism (`IOConnectCallStructMethod`)
// is itself ordinary, public IOKit API used by countless legitimate
// drivers; what's undocumented is which selectors/structs/keys the
// "AppleSMC" service specifically expects.
//
// THIS IS THE LEAST CERTAIN FILE IN THE PROJECT. Field layout, byte
// order, and the exact service name have no way to be verified without
// running on real Apple Silicon hardware. If temperature reads as
// "Unavailable" or as an obviously wrong number, this file — specifically
// the struct layout below or the byte order in `decode(bytes:dataType:)`
// — is the first place to look. See README troubleshooting.

private typealias SMCBytes = (
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
)

private let zeroSMCBytes: SMCBytes = (
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
)

private struct SMCVersion {
    var major: UInt8 = 0
    var minor: UInt8 = 0
    var build: UInt8 = 0
    var reserved: UInt8 = 0
    var release: UInt16 = 0
}

private struct SMCPLimitData {
    var version: UInt16 = 0
    var length: UInt16 = 0
    var cpuPLimit: UInt32 = 0
    var gpuPLimit: UInt32 = 0
    var memPLimit: UInt32 = 0
}

private struct SMCKeyInfoData {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
}

private struct SMCParamStruct {
    var key: UInt32 = 0
    var vers = SMCVersion()
    var pLimitData = SMCPLimitData()
    var keyInfo = SMCKeyInfoData()
    var padding: UInt16 = 0
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: SMCBytes = zeroSMCBytes
}

private enum SMCSelector: UInt8 {
    case readKey = 5
    case getKeyInfo = 9
    case getKeyFromIndex = 8
}

/// Container for the raw bytes, size and type returned by a single SMC
/// key read.
private struct SMCValue {
    let dataSize: UInt32
    let dataType: String
    let bytes: [UInt8]
}

/// Raw connection to the SMC (System Management Controller) via its
/// private IOKit user client — the only way to get real component
/// temperatures on Apple Silicon, because Apple provides no public API
/// for it. See the file-level comment above for the honest risk profile.
final class SMCConnection {
    private var connection: io_connect_t = 0
    private(set) var isOpen = false

    init?() {
        var service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        if service == 0 {
            // Observed under a different service name on some Apple
            // Silicon configurations; fall back before giving up.
            service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMCKeysEndpoint"))
        }
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
        guard result == kIOReturnSuccess else { return nil }
        isOpen = true
    }

    deinit {
        if isOpen {
            IOServiceClose(connection)
        }
    }

    /// Every key discovered by scanning the SMC's full key table that (a)
    /// starts with "T" — the common prefix for temperature keys on both
    /// Intel and Apple Silicon SMC implementations — and (b) decodes to a
    /// plausible temperature value. This is a runtime discovery approach
    /// rather than a hard-coded, model-specific key table, since this
    /// project has no way to verify exact key names for your specific
    /// M5 hardware.
    func discoverTemperatureKeys() -> [(key: String, celsius: Double)] {
        guard let count = keyCount(), count > 0 else { return [] }

        var found: [(String, Double)] = []
        for index in 0..<count {
            guard let keyName = key(atIndex: index) else { continue }
            let lower = keyName.lowercased()
            guard lower.hasPrefix("t") else { continue }
            guard let celsius = readFloatValue(forKey: keyName) else { continue }
            guard celsius > -20, celsius < 150 else { continue }
            found.append((keyName, celsius))
        }
        return found
    }

    // MARK: - Low-level reads

    private func readSMCValue(forKey keyName: String) -> SMCValue? {
        let code = fourCharCode(keyName)
        guard let info = call(.getKeyInfo, configure: { $0.key = code }) else { return nil }

        let dataSize = info.keyInfo.dataSize
        let dataType = fourCharString(info.keyInfo.dataType)
        guard dataSize > 0, dataSize <= 32 else { return nil }

        guard let output = call(.readKey, configure: { param in
            param.key = code
            param.keyInfo.dataSize = dataSize
        }) else { return nil }

        let raw = Array(rawBytes(of: output.bytes).prefix(Int(dataSize)))
        return SMCValue(dataSize: dataSize, dataType: dataType, bytes: raw)
    }

    func readFloatValue(forKey keyName: String) -> Double? {
        guard let value = readSMCValue(forKey: keyName) else { return nil }
        return decodeTemperature(value: value)
    }

    func readNumber(forKey keyName: String) -> Double? {
        guard let value = readSMCValue(forKey: keyName) else { return nil }
        return decodeNumber(value: value)
    }

    func readInteger(forKey keyName: String) -> UInt32? {
        guard let value = readSMCValue(forKey: keyName) else { return nil }
        return decodeInteger(value: value)
    }

    // MARK: - Fan helpers

    func readFanCount() -> Int? {
        guard let value = readSMCValue(forKey: "FNum") else { return nil }
        guard let count = decodeInteger(value: value) else { return nil }
        return count > 0 && count < 100 ? Int(count) : nil
    }

    func readFanRPM() -> Int? {
        guard let rpms = readFanRPMs(), !rpms.isEmpty else { return nil }
        return rpms.compactMap { $0 }.max()
    }

    func readFanRPMs() -> [Int?]? {
        guard let count = readFanCount(), count > 0 else { return nil }
        return readFanRPMs(count: count)
    }

    func readFanRPMs(count: Int) -> [Int?] {
        (0..<count).map { index in
            guard let rpm = readNumber(forKey: String(format: "F%dAc", index)), rpm >= 0 else {
                return nil
            }
            return Int(rpm.rounded())
        }
    }

    private func keyCount() -> Int? {
        let keyCountCode = fourCharCode("#KEY")
        guard let info = call(.getKeyInfo, configure: { $0.key = keyCountCode }) else { return nil }
        let size = info.keyInfo.dataSize
        guard size == 4 else { return nil }
        guard let output = call(.readKey, configure: { $0.key = keyCountCode; $0.keyInfo.dataSize = size }) else { return nil }
        let raw = rawBytes(of: output.bytes)
        let count = (UInt32(raw[0]) << 24) | (UInt32(raw[1]) << 16) | (UInt32(raw[2]) << 8) | UInt32(raw[3])
        guard count > 0, count <= 100_000 else { return nil }
        return Int(count)
    }

    private func key(atIndex index: Int) -> String? {
        guard let output = call(.getKeyFromIndex, configure: { $0.data32 = UInt32(index) }) else { return nil }
        return fourCharString(output.key)
    }

    private func call(_ selector: SMCSelector, configure: (inout SMCParamStruct) -> Void = { _ in }) -> SMCParamStruct? {
        guard isOpen else { return nil }

        var input = SMCParamStruct()
        input.data8 = selector.rawValue
        configure(&input)

        var output = SMCParamStruct()
        let inputSize = MemoryLayout<SMCParamStruct>.stride
        var outputSize = MemoryLayout<SMCParamStruct>.stride

        let result = withUnsafePointer(to: &input) { inputPointer -> kern_return_t in
            withUnsafeMutablePointer(to: &output) { outputPointer -> kern_return_t in
                // Selector 2 (kSMCHandleYPCEvent) is the fixed IOKit-level
                // selector for all SMC struct calls; the actual operation
                // (read/get-info/get-by-index) travels inside the struct
                // itself, in `data8`, set above.
                IOConnectCallStructMethod(connection, 2, inputPointer, inputSize, outputPointer, &outputSize)
            }
        }

        guard result == kIOReturnSuccess, output.result == 0 else { return nil }
        return output
    }

    private func fourCharCode(_ string: String) -> UInt32 {
        var result: UInt32 = 0
        for byte in string.utf8.prefix(4) {
            result = (result << 8) | UInt32(byte)
        }
        return result
    }

    private func fourCharString(_ code: UInt32) -> String {
        let bytes: [UInt8] = [
            UInt8((code >> 24) & 0xFF),
            UInt8((code >> 16) & 0xFF),
            UInt8((code >> 8) & 0xFF),
            UInt8(code & 0xFF)
        ]
        return String(bytes: bytes, encoding: .ascii) ?? ""
    }

    private func rawBytes(of bytes: SMCBytes) -> [UInt8] {
        withUnsafeBytes(of: bytes) { Array($0) }
    }

    // MARK: - Value decoding

    /// Temperature values are little-endian IEEE-754 `flt ` on Apple
    /// Silicon and big-endian signed 8.8 fixed-point `sp78` on Intel.
    private func decodeTemperature(value: SMCValue) -> Double? {
        Self.decodeTemperature(bytes: value.bytes, dataType: value.dataType)
    }

    static func decodeTemperature(bytes: [UInt8], dataType: String) -> Double? {
        let decoded: Double
        switch dataType.trimmingCharacters(in: .whitespaces) {
        case "flt":
            guard bytes.count >= 4 else { return nil }
            let bits = UInt32(bytes[0]) | (UInt32(bytes[1]) << 8)
                | (UInt32(bytes[2]) << 16) | (UInt32(bytes[3]) << 24)
            decoded = Double(Float(bitPattern: bits))
        case "sp78":
            guard bytes.count >= 2 else { return nil }
            let raw = Int16(bitPattern: (UInt16(bytes[0]) << 8) | UInt16(bytes[1]))
            decoded = Double(raw) / 256
        default:
            return nil
        }

        guard decoded.isFinite, decoded > -20, decoded < 150 else { return nil }
        return decoded
    }

    /// Fan RPM can be "flt" (Apple Silicon / modern Intel), "fpe2" (older
    /// Intel), or a plain unsigned integer. We accept 0 (stopped fan) but
    /// reject tiny subnormal values that are clearly the wrong byte order.
    private func decodeNumber(value: SMCValue) -> Double? {
        let raw = value.bytes
        let type = value.dataType.trimmingCharacters(in: .whitespaces)

        switch type {
        case "flt":
            guard raw.count >= 4 else { return nil }
            let bitsLE = UInt32(raw[0]) | (UInt32(raw[1]) << 8)
                | (UInt32(raw[2]) << 16) | (UInt32(raw[3]) << 24)
            let bitsBE = (UInt32(raw[0]) << 24) | (UInt32(raw[1]) << 16)
                | (UInt32(raw[2]) << 8) | UInt32(raw[3])

            for bits in [bitsLE, bitsBE] {
                let val = Double(Float(bitPattern: bits))
                let isPlausible = (val == 0 || val.isNormal) && !val.isNaN && !val.isInfinite
                if isPlausible && val >= 0 && val < 20000 && (val == 0 || val >= 0.5) {
                    return val
                }
            }
            return nil

        case "fpe2":
            guard raw.count >= 2 else { return nil }
            let rawBE = (UInt16(raw[0]) << 8) | UInt16(raw[1])
            let val = Double(rawBE) / 4.0
            return (val >= 0 && val < 20000) ? val : nil

        case "ui8":
            guard raw.count >= 1 else { return nil }
            return Double(raw[0])

        case "ui16":
            guard raw.count >= 2 else { return nil }
            let be = Double((UInt16(raw[0]) << 8) | UInt16(raw[1]))
            let le = Double((UInt16(raw[1]) << 8) | UInt16(raw[0]))
            if be >= 0 && be < 20000 { return be }
            if le >= 0 && le < 20000 { return le }
            return nil

        case "ui32":
            guard raw.count >= 4 else { return nil }
            let be = Double((UInt32(raw[0]) << 24) | (UInt32(raw[1]) << 16)
                | (UInt32(raw[2]) << 8) | UInt32(raw[3]))
            let le = Double(UInt32(raw[0]) | (UInt32(raw[1]) << 8)
                | (UInt32(raw[2]) << 16) | (UInt32(raw[3]) << 24))
            if be >= 0 && be < 20000 { return be }
            if le >= 0 && le < 20000 { return le }
            return nil

        default:
            return nil
        }
    }

    private func decodeInteger(value: SMCValue) -> UInt32? {
        let raw = value.bytes
        switch raw.count {
        case 1:
            return UInt32(raw[0])
        case 2:
            let be = (UInt32(raw[0]) << 8) | UInt32(raw[1])
            let le = (UInt32(raw[1]) << 8) | UInt32(raw[0])
            return be < 100 ? be : (le < 100 ? le : be)
        case 4:
            let be = (UInt32(raw[0]) << 24) | (UInt32(raw[1]) << 16)
                | (UInt32(raw[2]) << 8) | UInt32(raw[3])
            let le = UInt32(raw[0]) | (UInt32(raw[1]) << 8)
                | (UInt32(raw[2]) << 16) | (UInt32(raw[3]) << 24)
            return be < 100 ? be : (le < 100 ? le : be)
        default:
            return nil
        }
    }
}
