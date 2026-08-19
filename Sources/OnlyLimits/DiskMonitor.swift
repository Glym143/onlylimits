import Foundation

/// One sample of the startup volume, counted the way Finder counts it:
/// available = free + purgeable, used = capacity − available.
struct DiskSnapshot: Equatable {
    var volumeName: String
    var total: UInt64
    var available: UInt64

    var used: UInt64 { total > available ? total - available : 0 }
    var usedPercent: Double {
        guard total > 0 else { return 0 }
        return min(100, Double(used) / Double(total) * 100)
    }
    var freePercent: Double { 100 - usedPercent }

    /// Free space is the signal here (not the used share): a 75%-full disk is
    /// fine, a nearly-full one is not. Mapped onto the shared status palette.
    var paletteRemaining: Double {
        switch freePercent {
        case ..<5: return 5      // red
        case ..<12: return 20    // amber
        default: return 100      // green
        }
    }

    /// True when the two samples differ in anything the UI draws (whole GB).
    func visiblyDiffers(from o: DiskSnapshot) -> Bool {
        func gb(_ b: UInt64) -> UInt64 { b / 1_000_000_000 }
        return volumeName != o.volumeName || gb(total) != gb(o.total) || gb(available) != gb(o.available)
    }
}

/// Reads the startup volume's capacity. On modern macOS the sealed system volume
/// and its data volume share one APFS container, so "/" already reports the whole
/// disk — the same numbers Finder and "About This Mac" show.
enum DiskSampler {
    private static let keys: Set<URLResourceKey> = [
        .volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey,
    ]

    static func sample() -> DiskSnapshot? {
        guard let v = try? URL(fileURLWithPath: "/").resourceValues(forKeys: keys),
              let total = v.volumeTotalCapacity, total > 0 else { return nil }
        // "Important usage" is what Finder calls available: free space plus what
        // macOS can purge (caches, local snapshots) if something needs the room.
        let available = max(0, v.volumeAvailableCapacityForImportantUsage ?? 0)
        return DiskSnapshot(volumeName: v.volumeName ?? "Macintosh HD",
                            total: UInt64(total),
                            available: UInt64(available))
    }
}
