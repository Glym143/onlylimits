import Foundation

/// How hard the kernel is squeezing memory right now (`kern.memorystatus_vm_pressure_level`).
/// This — not the raw "used" number — is what actually tells you the Mac is struggling:
/// macOS happily keeps RAM full of cache and compressed pages while staying green.
enum MemoryPressure {
    case normal, warning, critical

    /// Mapped onto the shared status palette (which speaks "remaining %").
    var paletteRemaining: Double {
        switch self {
        case .normal: return 100
        case .warning: return 20
        case .critical: return 5
        }
    }
}

/// One sample of system-wide memory, accounted for the same way Activity Monitor does:
/// Memory Used = App + Wired + Compressed (cached files are *not* counted as used).
struct MemorySnapshot: Equatable {
    var total: UInt64        // hw.memsize
    var app: UInt64          // anonymous, non-purgeable pages
    var wired: UInt64        // pages the kernel can't page out
    var compressed: UInt64   // pages held by the VM compressor
    var cached: UInt64       // file-backed + purgeable → "Cached Files"
    var swapUsed: UInt64
    var pressure: MemoryPressure

    var used: UInt64 { app &+ wired &+ compressed }
    var usedPercent: Double {
        guard total > 0 else { return 0 }
        return min(100, Double(used) / Double(total) * 100)
    }

    /// True when the two samples differ in anything the UI actually draws — used to
    /// skip redraws (menu-bar image + panel) for a handful of pages moving around.
    func visiblyDiffers(from o: MemorySnapshot) -> Bool {
        func tenths(_ b: UInt64) -> Int { Int((Double(b) / 1_073_741_824 * 10).rounded()) }
        return pressure != o.pressure
            || Int(usedPercent.rounded()) != Int(o.usedPercent.rounded())
            || tenths(used) != tenths(o.used)
            || tenths(swapUsed) != tenths(o.swapUsed)
            || tenths(cached) != tenths(o.cached)
    }
}

/// Reads system memory straight from the kernel (mach + sysctl). No entitlements,
/// no shelling out, sub-millisecond — safe to poll every couple of seconds.
enum MemorySampler {
    /// Installed RAM never changes while we're running.
    static let totalBytes: UInt64 = {
        var v: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        guard sysctlbyname("hw.memsize", &v, &size, nil, 0) == 0 else { return 0 }
        return v
    }()

    private static let pageSize: UInt64 = {
        var ps: vm_size_t = 0
        guard host_page_size(mach_host_self(), &ps) == KERN_SUCCESS, ps > 0 else { return 4096 }
        return UInt64(ps)
    }()

    static func sample() -> MemorySnapshot? {
        guard totalBytes > 0, let vm = vmStatistics() else { return nil }
        let ps = pageSize
        func bytes(_ pages: natural_t) -> UInt64 { UInt64(pages) &* ps }

        // internal = anonymous pages; purgeable ones are reclaimable, so Activity
        // Monitor bills them to "Cached Files" rather than to App Memory.
        let purgeable = min(vm.purgeable_count, vm.internal_page_count)
        return MemorySnapshot(
            total: totalBytes,
            app: bytes(vm.internal_page_count - purgeable),
            wired: bytes(vm.wire_count),
            compressed: bytes(vm.compressor_page_count),
            cached: bytes(vm.external_page_count) &+ bytes(purgeable),
            swapUsed: swapUsed(),
            pressure: pressureLevel()
        )
    }

    private static func vmStatistics() -> vm_statistics64_data_t? {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &stats) { p in
            p.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { ptr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, ptr, &count)
            }
        }
        return kr == KERN_SUCCESS ? stats : nil
    }

    private static func swapUsed() -> UInt64 {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        guard sysctlbyname("vm.swapusage", &usage, &size, nil, 0) == 0 else { return 0 }
        return usage.xsu_used
    }

    /// 1 = normal, 2 = warning, 4 = critical (DISPATCH_MEMORYPRESSURE_*).
    private static func pressureLevel() -> MemoryPressure {
        var level: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0) == 0 else {
            return .normal
        }
        switch level {
        case 4: return .critical
        case 2: return .warning
        default: return .normal
        }
    }
}
