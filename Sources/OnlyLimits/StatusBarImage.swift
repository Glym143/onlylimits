import AppKit

/// Single source of truth for the soft status palette, shared by the SwiftUI
/// bars and the AppKit-drawn menu-bar image.
enum Palette {
    /// (r,g,b) 0…1 for a given remaining percentage.
    static func rgb(_ remaining: Double) -> (r: Double, g: Double, b: Double) {
        switch remaining {
        case ..<10:  return (0.83, 0.44, 0.44)   // soft red
        case ..<30:  return (0.85, 0.66, 0.36)   // soft amber
        default:     return (0.40, 0.71, 0.53)   // soft green
        }
    }

    static func nsColor(_ remaining: Double) -> NSColor {
        let c = rgb(remaining)
        return NSColor(srgbRed: c.r, green: c.g, blue: c.b, alpha: 1)
    }
}

/// Renders the menu-bar status item as a compact colored mini bar chart —
/// the same idiom system monitors (iStat Menus / Stats) use. One vertical bar
/// per account, height = remaining %, colored by the status palette. Drawn as
/// a non-template NSImage so the colors survive (template would force mono).
enum StatusBarImage {
    struct Value { let remaining: Double; let color: NSColor }

    /// - showNumber: when true, each bar is followed by its own "NN%".
    static func make(values: [Value], showNumber: Bool) -> NSImage {
        let barW: CGFloat = 3.5
        let radius: CGFloat = 1.75
        let height: CGFloat = 18
        let bottom: CGFloat = 2
        let trackH = height - 4
        let font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        let numGap: CGFloat = 3      // bar → its number
        let groupGap: CGFloat = 8    // account → next account (with numbers)
        let barGap: CGFloat = 2.5    // bar → next bar (no numbers)

        struct Item { let v: Value; let text: NSString?; let size: NSSize }
        let items: [Item] = values.map { v in
            guard showNumber else { return Item(v: v, text: nil, size: .zero) }
            let t = "\(Int(v.remaining.rounded()))%" as NSString
            let size = t.size(withAttributes: [.font: font, .foregroundColor: v.color])
            return Item(v: v, text: t, size: size)
        }

        // Total width.
        var width: CGFloat = 0
        for (i, it) in items.enumerated() {
            width += barW
            if let _ = it.text { width += numGap + it.size.width }
            if i < items.count - 1 { width += showNumber ? groupGap : barGap }
        }
        width = max(width, barW)

        // Monochrome template: the system tints it (white on a dark menu bar,
        // black on a light one) so it's always legible. Only alpha matters here.
        let trackInk = NSColor(white: 0, alpha: 0.30)
        let ink = NSColor(white: 0, alpha: 1)

        let image = NSImage(size: NSSize(width: ceil(width), height: height), flipped: false) { _ in
            var x: CGFloat = 0
            for it in items {
                let track = NSBezierPath(roundedRect: NSRect(x: x, y: bottom, width: barW, height: trackH),
                                         xRadius: radius, yRadius: radius)
                trackInk.setFill()
                track.fill()
                let pct = min(100, max(0, it.v.remaining)) / 100
                let fh = max(1.5, trackH * CGFloat(pct))
                let fill = NSBezierPath(roundedRect: NSRect(x: x, y: bottom, width: barW, height: fh),
                                        xRadius: radius, yRadius: radius)
                ink.setFill()
                fill.fill()
                x += barW
                if let t = it.text {
                    let ty = (height - it.size.height) / 2
                    t.draw(at: NSPoint(x: x + numGap, y: ty),
                           withAttributes: [.font: font, .foregroundColor: ink])
                    x += numGap + it.size.width
                }
                x += showNumber ? groupGap : barGap
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    /// Shown briefly before the first data load (and when there are no accounts):
    /// a static monochrome version of our bar motif — matches the app icon and the
    /// live chart, so the launch → data transition is seamless. Template so the
    /// menu bar tints it (white on dark, black on light).
    static func placeholder() -> NSImage {
        let barW: CGFloat = 3.5, gap: CGFloat = 2.5, height: CGFloat = 18, radius: CGFloat = 1.75
        let bottom: CGFloat = 2, trackH = height - 4
        let levels: [CGFloat] = [0.25, 0.5, 0.75, 1.0]     // the icon's rising LED bars
        let width = CGFloat(levels.count) * barW + CGFloat(levels.count - 1) * gap
        let img = NSImage(size: NSSize(width: ceil(width), height: height), flipped: false) { _ in
            var x: CGFloat = 0
            for lvl in levels {
                let track = NSBezierPath(roundedRect: NSRect(x: x, y: bottom, width: barW, height: trackH),
                                         xRadius: radius, yRadius: radius)
                NSColor(white: 0, alpha: 0.30).setFill(); track.fill()
                let fh = max(1.5, trackH * lvl)
                let fill = NSBezierPath(roundedRect: NSRect(x: x, y: bottom, width: barW, height: fh),
                                        xRadius: radius, yRadius: radius)
                NSColor(white: 0, alpha: 1).setFill(); fill.fill()
                x += barW + gap
            }
            return true
        }
        img.isTemplate = true
        return img
    }
}
