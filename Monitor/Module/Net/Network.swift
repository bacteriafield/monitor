import Foundation

enum NetworkMonitorError: Error {
    case getifaddrsFailed(Int32)
}

enum NetworkUnit {
    case bytes, kilobytes, megabytes, gigabytes

    func convert(_ bytes: UInt64) -> Double {
        switch self {
        case .bytes: return Double(bytes)
        case .kilobytes: return Double(bytes) / 1_024
        case .megabytes: return Double(bytes) / 1_048_576
        case .gigabytes: return Double(bytes) / 1_073_741_824
        }
    }

    var symbol: String {
        switch self {
        case .bytes: return "B"
        case .kilobytes: return "KB"
        case .megabytes: return "MB"
        case .gigabytes: return "GB"
        }
    }
}

struct NetworkSnapshot {
    let received: UInt64
    let sent: UInt64
    let timestamp: Date

    func receivedFormatted(in unit: NetworkUnit, decimals: Int = 1) -> String {
        String(format: "%.\(decimals)f \(unit.symbol)", unit.convert(received))
    }

    func sentFormatted(in unit: NetworkUnit, decimals: Int = 1) -> String {
        String(format: "%.\(decimals)f \(unit.symbol)", unit.convert(sent))
    }

    // calculate rates (bytes/s) relative to a previous snapshot
    func rate(since previous: NetworkSnapshot) -> NetworkRate {
        let elapsed = timestamp.timeIntervalSince(previous.timestamp)
        guard elapsed > 0 else {
            return NetworkRate(download: 0, upload: 0)
        }

        let deltaIn = received >= previous.received ? received - previous.received : 0
        let deltaOut = sent >= previous.sent ? sent - previous.sent : 0
        let download = Double(deltaIn) / elapsed
        let upload = Double(deltaOut) / elapsed
        return NetworkRate(
            download: download > 0 ? UInt64(download) : 0,
            upload: upload > 0 ? UInt64(upload) : 0
        )
    }
}

struct NetworkRate {
    let download: UInt64  // bytes/s
    let upload: UInt64  // bytes/s

    func downloadFormatted(in unit: NetworkUnit, decimals: Int = 1) -> String {
        "\(String(format: "%.\(decimals)f", unit.convert(download))) \(unit.symbol)/s"
    }

    func uploadFormatted(in unit: NetworkUnit, decimals: Int = 1) -> String {
        "\(String(format: "%.\(decimals)f", unit.convert(upload))) \(unit.symbol)/s"
    }
}

final class NetworkMonitor {
    private var previous: NetworkSnapshot?

    // returns the current snapshot of bytes accumulated since boot
    func snapshot() throws -> NetworkSnapshot {
        var addresses: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addresses) == 0, let first = addresses else {
            throw NetworkMonitorError.getifaddrsFailed(errno)
        }
        defer { freeifaddrs(addresses) }

        var received: UInt64 = 0
        var sent: UInt64 = 0
        var pointer: UnsafeMutablePointer<ifaddrs>? = first

        while let current = pointer {
            let iface = current.pointee
            defer { pointer = iface.ifa_next }

            // only the AF_LINK entry for each interface populates the `if_data` structure with byte counters; the IPv4/IPv6 entries are not suitable for this purpose.
            guard let addr = iface.ifa_addr,
                addr.pointee.sa_family == UInt8(AF_LINK)
            else { continue }

            // skips loopback (lo0): local traffic does not count as network traffic
            if (iface.ifa_flags & UInt32(IFF_LOOPBACK)) != 0 { continue }

            if let data = iface.ifa_data?.assumingMemoryBound(to: if_data.self) {
                received += UInt64(data.pointee.ifi_ibytes)
                sent += UInt64(data.pointee.ifi_obytes)
            }
        }

        return NetworkSnapshot(received: received, sent: sent, timestamp: Date())
    }

    // returns the transfer rate since the last call
    func rate() throws -> NetworkRate {
        let current = try snapshot()
        defer { previous = current }
        guard let previous else { return NetworkRate(download: 0, upload: 0) }
        return current.rate(since: previous)
    }
}
