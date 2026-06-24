import Foundation
import Darwin.Mach

enum CpuMonitorError: Error {
    case processorInfoFailed(kern_return_t)
}

final class CpuMonitor {
    private let host: host_t
    private var previousTicks: [UInt32] = []

    init(host: host_t = mach_host_self()) {
        self.host = host
    }

    func usage() throws -> Double {
        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0

        let kr = host_processor_info(
            host,
            PROCESSOR_CPU_LOAD_INFO,
            &cpuCount,
            &info,
            &infoCount
        )
        guard kr == KERN_SUCCESS, let info else {
            throw CpuMonitorError.processorInfoFailed(kr)
        }
        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(UInt(bitPattern: UnsafeRawPointer(info))),
                vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride)
            )
        }

        let states = Int(CPU_STATE_MAX)
        let cpus = Int(cpuCount)

        // Snapshot atual dos ticks, achatado em um único array.
        let current = (0..<cpus * states).map { UInt32(bitPattern: info[$0]) }

        // Primeira amostra: ainda não dá pra calcular delta.
        guard previousTicks.count == current.count else {
            previousTicks = current
            return 0
        }

        var totalUsed = 0.0
        var totalTicks = 0.0

        for cpu in 0..<cpus {
            let base = cpu * states
            let user   = Double(current[base + Int(CPU_STATE_USER)]   &- previousTicks[base + Int(CPU_STATE_USER)])
            let system = Double(current[base + Int(CPU_STATE_SYSTEM)] &- previousTicks[base + Int(CPU_STATE_SYSTEM)])
            let nice   = Double(current[base + Int(CPU_STATE_NICE)]   &- previousTicks[base + Int(CPU_STATE_NICE)])
            let idle   = Double(current[base + Int(CPU_STATE_IDLE)]   &- previousTicks[base + Int(CPU_STATE_IDLE)])

            totalUsed  += user + system + nice
            totalTicks += user + system + nice + idle
        }

        previousTicks = current

        guard totalTicks > 0 else { return 0 }
        return totalUsed / totalTicks * 100.0
    }
}
