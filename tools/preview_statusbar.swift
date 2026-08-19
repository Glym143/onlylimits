import AppKit

/// Renders every menu-bar layout to one PNG sheet, using the app's real
/// `StatusBarImage` drawing code.
///
/// The status item can't be screenshotted from a script, and the image it
/// produces is a *template* — the system decides its colour — so each layout is
/// drawn twice here: tinted black over a light strip and white over a dark one,
/// exactly what macOS does on a light vs. dark menu bar. Handy for checking
/// glyph alignment, gaps and the hairline separator after touching the drawing
/// code, without installing a build.
///
///   tools/preview_statusbar.sh [out.png] [--live]
///
/// Values are fixed by default so two runs are diffable; `--live` samples this
/// Mac's real memory and disk instead.
@main
enum StatusBarPreview {

    // Fixed stand-ins: three accounts and a machine with 96 GB of RAM in use
    // and 3 TB of disk taken.
    static let accounts: [Double] = [72, 25, 5]
    static let fixedRAM: UInt64 = 96 * 1024 * 1024 * 1024
    static let fixedDisk: UInt64 = 3_000_000_000_000

    static func main() {
        var args = CommandLine.arguments.dropFirst()
        let live = args.contains("--live")
        args = args.filter { $0 != "--live" }
        let out = args.first ?? "docs/statusbar-preview.png"

        var ram = fixedRAM, disk = fixedDisk
        if live {
            ram = MemorySampler.sample()?.used ?? fixedRAM
            disk = DiskSampler.sample()?.used ?? fixedDisk
        }

        let ru = Strings(lang: .ru), en = Strings(lang: .en)
        func extras(_ s: Strings, ram wantRAM: Bool = true, disk wantDisk: Bool = true) -> [StatusBarImage.Extra] {
            var e: [StatusBarImage.Extra] = []
            if wantRAM { e.append(.init(symbol: "memorychip", text: s.gbCompact(ram))) }
            if wantDisk { e.append(.init(symbol: "internaldrive", text: s.disk(disk))) }
            return e
        }
        func value(_ remaining: Double) -> StatusBarImage.Value {
            .init(remaining: remaining, color: Palette.nsColor(remaining))
        }
        let one = [value(accounts[0])]
        let all = accounts.map(value)

        let sheet: [(String, NSImage)] = [
            ("active + RAM + disk", .make(values: one, showNumber: true, extras: extras(ru))),
            ("active + disk only", .make(values: one, showNumber: true, extras: extras(ru, ram: false))),
            ("all bars + both", .make(values: all, showNumber: false, extras: extras(ru))),
            ("all + numbers + both", .make(values: all, showNumber: true, extras: extras(ru))),
            ("all + numbers + both (en)", .make(values: all, showNumber: true, extras: extras(en))),
            ("system only", .make(values: [], showNumber: false, extras: extras(ru))),
            ("no extras", .make(values: one, showNumber: true)),
            ("placeholder (no data yet)", StatusBarImage.placeholder()),
        ]

        write(sheet, to: out)
        print("RAM \(ru.gbCompact(ram)) · disk \(ru.disk(disk))\(live ? "  (live)" : "  (fixed)")")
        print("wrote \(out)")
    }

    /// Keep the alpha, replace the colour — what the menu bar does to a template.
    static func tinted(_ img: NSImage, _ color: NSColor) -> NSImage {
        NSImage(size: img.size, flipped: false) { rect in
            img.draw(in: rect)
            color.set()
            rect.fill(using: .sourceAtop)
            return true
        }
    }

    static func write(_ rows: [(String, NSImage)], to path: String) {
        let scale: CGFloat = 3, rowH: CGFloat = 26, pad: CGFloat = 10, labelW: CGFloat = 170
        let maxW = rows.map(\.1.size.width).max() ?? 100
        let w = (labelW + maxW + pad * 2) * scale
        let h = (CGFloat(rows.count) * rowH * 2 + pad * 2) * scale

        let sheet = NSImage(size: NSSize(width: w, height: h), flipped: false) { _ in
            NSColor.white.setFill()
            NSRect(x: 0, y: 0, width: w, height: h).fill()
            var y = h - pad * scale - rowH * scale
            for (dark, bg) in [(false, NSColor.white), (true, NSColor(white: 0.12, alpha: 1))] {
                for (name, img) in rows {
                    bg.setFill()
                    NSRect(x: 0, y: y, width: w, height: rowH * scale).fill()
                    (name as NSString).draw(
                        at: NSPoint(x: pad * scale, y: y + 7 * scale),
                        withAttributes: [.font: NSFont.systemFont(ofSize: 9 * scale),
                                         .foregroundColor: dark ? NSColor.white : NSColor.black])
                    let r = NSRect(x: labelW * scale,
                                   y: y + (rowH - img.size.height) / 2 * scale,
                                   width: img.size.width * scale,
                                   height: img.size.height * scale)
                    tinted(img, dark ? .white : .black).draw(in: r)
                    y -= rowH * scale
                }
            }
            return true
        }

        guard let tiff = sheet.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            print("failed to encode PNG"); exit(1)
        }
        do { try png.write(to: URL(fileURLWithPath: path)) }
        catch { print("failed to write \(path): \(error)"); exit(1) }
    }
}

private extension NSImage {
    static func make(values: [StatusBarImage.Value], showNumber: Bool,
                     extras: [StatusBarImage.Extra] = []) -> NSImage {
        StatusBarImage.make(values: values, showNumber: showNumber, extras: extras)
    }
}
