import Darwin.Mach
import Foundation

enum MemoryMonitorError: Error {
    case hostStatsFailed(kern_return_t)
}

enum MemoryUnit {
    case bytes, megabytes, gigabytes  // defines the unit that will be used

    func convert(_ bytes: UInt64) -> Double {
        switch self {
        case .bytes: return Double(bytes)
        case .megabytes: return Double(bytes) / 1_048_576
        case .gigabytes: return Double(bytes) / 1_073_741_824
        }
    }

    var symbol: String {
        switch self {
        case .bytes: return "B"
        case .megabytes: return "MB"
        case .gigabytes: return "GB"
        }
    }
}

struct MemorySnapShot {
    let used: UInt64
    let total: UInt64

    var free: UInt64 { total > used ? total - used : 0 }
    var usageRatio: Double { total > 0 ? Double(used) / Double(total) : 0 }

    func usedFormatted(in unit: MemoryUnit, decimals: Int = 1) -> String {
        String(format: "%.\(decimals)f \(unit.symbol)", unit.convert(used))
    }

    func totalFormatted(in unit: MemoryUnit, decimals: Int = 1) -> String {
        String(format: "%.\(decimals)f \(unit.symbol)", unit.convert(total))
    }

    func formatted(in unit: MemoryUnit, decimals: Int = 1) -> String {
        let usedValue = String(format: "%.\(decimals)f", unit.convert(used))
        return "\(usedValue) / \(totalFormatted(in: unit, decimals: decimals))"
    }

}

final class MemoryMonitor {
    private let host: host_t = mach_host_self()

    func snapshot() throws -> MemorySnapShot {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size
        )

        let kr = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }

        guard kr == KERN_SUCCESS else {
            throw MemoryMonitorError.hostStatsFailed(kr)
        }

        let pageSize = UInt64(vm_kernel_page_size)

        let usedPages =
            UInt64(stats.internal_page_count)
            - UInt64(stats.purgeable_count)
            + UInt64(stats.wire_count)
            + UInt64(stats.compressor_page_count)
        let used = usedPages * pageSize
        let total = ProcessInfo.processInfo.physicalMemory

        return MemorySnapShot(used: used, total: total)
    }

}
