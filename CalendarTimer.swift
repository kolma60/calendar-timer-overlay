import Cocoa
import EventKit

// MARK: - Urgency colors (matching design: oklch green → amber → coral)

func urgencyColor(frac: Double) -> NSColor {
    if frac > 0.25 { return NSColor(red: 0.25, green: 0.75, blue: 0.46, alpha: 1) }
    if frac > 0.10 { return NSColor(red: 0.88, green: 0.72, blue: 0.16, alpha: 1) }
    return NSColor(red: 0.87, green: 0.36, blue: 0.25, alpha: 1)
}

// MARK: - Dot indicator (colored circle with glow)

class DotView: NSView {
    var color: NSColor = NSColor(red: 0.25, green: 0.75, blue: 0.46, alpha: 1) { didSet { needsDisplay = true } }
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 5, color: color.cgColor)
        let p = NSBezierPath(ovalIn: bounds.insetBy(dx: 0.5, dy: 0.5))
        color.setFill(); p.fill()
        ctx.restoreGState()
    }
}

// MARK: - Progress bar (groove + colored fill)

class ProgressBarView: NSView {
    var fraction: CGFloat = 1.0 { didSet { needsDisplay = true } }
    var barColor: NSColor = NSColor(red: 0.25, green: 0.75, blue: 0.46, alpha: 1) { didSet { needsDisplay = true } }

    override func draw(_ dirtyRect: NSRect) {
        let r = bounds.height / 2
        // Groove
        let track = NSBezierPath(roundedRect: bounds, xRadius: r, yRadius: r)
        NSColor(white: 1, alpha: 0.14).setFill(); track.fill()
        NSColor(white: 0, alpha: 0.18).setStroke(); track.lineWidth = 0.5; track.stroke()
        // Fill
        let fw = max(0, bounds.width * fraction)
        if fw > 0 {
            let fillPath = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: fw, height: bounds.height),
                                        xRadius: r, yRadius: r)
            barColor.setFill(); fillPath.fill()
        }
    }
}

// MARK: - Round icon button (glass chip style)

class ChipButton: NSButton {
    override init(frame: NSRect) {
        super.init(frame: frame)
        bezelStyle = .regularSquare; isBordered = false
        wantsLayer = true
        layer?.cornerRadius = frame.width / 2
        layer?.backgroundColor = NSColor(white: 1, alpha: 0.08).cgColor
        layer?.borderColor = NSColor(white: 1, alpha: 0.14).cgColor
        layer?.borderWidth = 1
    }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        addTrackingArea(NSTrackingArea(rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self, userInfo: nil))
    }
    override func mouseEntered(with event: NSEvent) {
        layer?.backgroundColor = NSColor(white: 1, alpha: 0.18).cgColor
    }
    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = NSColor(white: 1, alpha: 0.08).cgColor
    }
}

// MARK: - Glass background (blur + specular + chroma + edge)

class GlassView: NSVisualEffectView {
    private let cr: CGFloat = 20
    var onHoverChange: ((Bool) -> Void)?
    private var dragOrigin: NSPoint?
    private var winOrigin: NSPoint?

    override init(frame: NSRect) {
        super.init(frame: frame)
        material = .hudWindow; blendingMode = .behindWindow; state = .active
        wantsLayer = true
        layer?.cornerRadius = cr; layer?.cornerCurve = .continuous; layer?.masksToBounds = true
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        addTrackingArea(NSTrackingArea(rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self, userInfo: nil))
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5),
                                xRadius: cr - 0.5, yRadius: cr - 0.5)
        ctx.saveGState(); path.addClip()

        // Glass base: white gradient overlay
        NSGradient(colors: [
            NSColor(white: 1, alpha: 0.22),
            NSColor(white: 1, alpha: 0.06),
            NSColor(white: 1, alpha: 0.12),
        ], atLocations: [0, 0.55, 1], colorSpace: .genericRGB)!.draw(in: bounds, angle: 90)

        // Specular: top-left radial highlight
        let specPt = CGPoint(x: bounds.width * 0.30, y: bounds.height * 1.05)
        let cspace = CGColorSpaceCreateDeviceRGB()
        let specColors = [NSColor(white: 1, alpha: 0.38).cgColor,
                          NSColor(white: 1, alpha: 0.00).cgColor] as CFArray
        let locs: [CGFloat] = [0, 1]
        if let grad = CGGradient(colorsSpace: cspace, colors: specColors, locations: locs) {
            ctx.drawRadialGradient(grad, startCenter: specPt, startRadius: 0,
                                   endCenter: specPt, endRadius: bounds.width * 0.72, options: [])
        }

        // Chromatic aberration: subtle pink-to-teal tint
        NSGradient(colors: [
            NSColor(red: 1.0, green: 0.71, blue: 0.86, alpha: 0.10),
            NSColor(red: 0.71, green: 0.86, blue: 1.00, alpha: 0.00),
            NSColor(red: 0.78, green: 1.00, blue: 0.90, alpha: 0.08),
        ], atLocations: [0, 0.40, 1], colorSpace: .genericRGB)!.draw(in: bounds, angle: -60)

        ctx.restoreGState()

        // Rim border
        path.lineWidth = 1.0
        NSColor(white: 1, alpha: 0.22).setStroke(); path.stroke()
    }

    // Hover
    override func mouseEntered(with event: NSEvent) { onHoverChange?(true) }
    override func mouseExited(with event: NSEvent)  { onHoverChange?(false) }

    // Drag to move
    override func mouseDown(with event: NSEvent) {
        dragOrigin = NSEvent.mouseLocation; winOrigin = window?.frame.origin
    }
    override func mouseDragged(with event: NSEvent) {
        guard let d = dragOrigin, let o = winOrigin else { return }
        let c = NSEvent.mouseLocation
        window?.setFrameOrigin(NSPoint(x: o.x + c.x - d.x, y: o.y + c.y - d.y))
    }
    override func mouseUp(with event: NSEvent) { dragOrigin = nil; winOrigin = nil }
}

// MARK: - Resize grip

class ResizeGrip: NSView {
    private var ds: NSPoint?; private var fa: NSRect?
    override func draw(_ dirtyRect: NSRect) {
        let p = NSBezierPath()
        // Lines anchored to bottom-right corner (correct resize-grip orientation)
        for i in 1...3 {
            let d = CGFloat(i) * 4.5
            p.move(to: NSPoint(x: bounds.width - 2, y: d))
            p.line(to: NSPoint(x: bounds.width - d, y: 2))
        }
        p.lineWidth = 1.2; p.lineCapStyle = .round
        NSColor(white: 1, alpha: 0.30).setStroke(); p.stroke()
    }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }
    override func mouseDown(with event: NSEvent) { ds = NSEvent.mouseLocation; fa = window?.frame }
    override func mouseDragged(with event: NSEvent) {
        guard let s = ds, let f = fa else { return }
        let c = NSEvent.mouseLocation
        let nw = max(260, f.width + (c.x - s.x))
        let nh = max(110, f.height - (c.y - s.y))
        window?.setFrame(NSRect(x: f.origin.x, y: f.maxY - nh, width: nw, height: nh), display: true)
    }
    override func mouseUp(with event: NSEvent) { ds = nil; fa = nil }
}

// MARK: - Panel

class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool  { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - App delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: OverlayPanel!
    var glass: GlassView!

    // Subviews
    var dotView: DotView!
    var titleLabel: NSTextField!
    var digitLabel: NSTextField!
    var leftLabel: NSTextField!
    var progressBar: ProgressBarView!
    var footerLeft: NSTextField!
    var footerRight: NSTextField!
    var closeBtn: NSButton!
    var gearBtn: NSButton!
    var resizeGrip: ResizeGrip!
    var pulseTimer: Timer?
    var pulsing = false

    var store = EKEventStore()
    var ticker: Timer?

    func applicationDidFinishLaunching(_ n: Notification) {
        if #available(macOS 14, *) {
            store.requestFullAccessToEvents { g, _ in
                DispatchQueue.main.async { g ? self.build() : self.deny() }
            }
        } else {
            store.requestAccess(to: .event) { g, _ in
                DispatchQueue.main.async { g ? self.build() : self.deny() }
            }
        }
    }

    func deny() {
        let a = NSAlert()
        a.messageText = "Calendar access denied"
        a.informativeText = "Grant access in System Settings → Privacy → Calendars."
        a.runModal(); NSApp.terminate(nil)
    }

    // MARK: Build window

    func build() {
        let screen = NSScreen.main!.frame
        let W: CGFloat = 300, H: CGFloat = 130

        window = OverlayPanel(
            contentRect: NSRect(x: screen.width - W - 24, y: 24, width: W, height: H),
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered, defer: false
        )
        window.level = .floating
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.alphaValue = 0.94
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.minSize = NSSize(width: 260, height: 110)

        let cv = window.contentView!

        glass = GlassView(frame: cv.bounds)
        glass.autoresizingMask = [.width, .height]
        glass.onHoverChange = { [weak self] h in
            guard let self else { return }
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.15
                self.closeBtn.animator().alphaValue   = h ? 1 : 0
                self.gearBtn.animator().alphaValue    = h ? 1 : 0
                self.resizeGrip.animator().alphaValue = h ? 1 : 0
            }
        }
        cv.addSubview(glass)

        let hPad: CGFloat = 18

        // ── Header row (top) ──────────────────────────────────────────────
        // y positions are from bottom (AppKit coords)
        let headerY: CGFloat = H - 12 - 20   // = 98

        dotView = DotView(frame: NSRect(x: hPad, y: headerY + 7, width: 6, height: 6))
        dotView.autoresizingMask = [.minYMargin]
        glass.addSubview(dotView)

        titleLabel = lbl(size: 11, weight: .semibold, color: NSColor(white: 1, alpha: 0.92))
        titleLabel.frame = NSRect(x: hPad + 14, y: headerY, width: W - hPad * 2 - 54, height: 20)
        titleLabel.autoresizingMask = [.width, .minYMargin]
        glass.addSubview(titleLabel)

        // Gear button
        gearBtn = ChipButton(frame: NSRect(x: W - hPad - 44, y: headerY, width: 20, height: 20))
        gearBtn.autoresizingMask = [.minXMargin, .minYMargin]
        gearBtn.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings")
        gearBtn.contentTintColor = NSColor(white: 1, alpha: 0.82)
        gearBtn.imageScaling = .scaleProportionallyDown
        gearBtn.alphaValue = 0
        glass.addSubview(gearBtn)

        // Close button
        closeBtn = ChipButton(frame: NSRect(x: W - hPad - 20, y: headerY, width: 20, height: 20))
        closeBtn.autoresizingMask = [.minXMargin, .minYMargin]
        closeBtn.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Quit")
        closeBtn.contentTintColor = NSColor(white: 1, alpha: 0.82)
        closeBtn.imageScaling = .scaleProportionallyDown
        closeBtn.alphaValue = 0
        closeBtn.target = self; closeBtn.action = #selector(quit)
        glass.addSubview(closeBtn)

        // ── Digit + "left" row ────────────────────────────────────────────
        let digitY: CGFloat = 44

        digitLabel = lbl(size: 40, weight: .semibold, color: .white)
        digitLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 40, weight: .semibold)
        digitLabel.stringValue = "--:--:--"
        digitLabel.frame = NSRect(x: hPad, y: digitY, width: W - hPad * 2 - 34, height: 50)
        digitLabel.autoresizingMask = [.width]
        glass.addSubview(digitLabel)

        leftLabel = lbl(size: 12, weight: .medium, color: NSColor(white: 1, alpha: 0.62))
        leftLabel.stringValue = "left"
        leftLabel.frame = NSRect(x: W - hPad - 30, y: digitY + 6, width: 30, height: 16)
        leftLabel.autoresizingMask = [.minXMargin]
        glass.addSubview(leftLabel)

        // ── Progress bar ──────────────────────────────────────────────────
        progressBar = ProgressBarView(frame: NSRect(x: hPad, y: 34, width: W - hPad * 2, height: 5))
        progressBar.autoresizingMask = [.width]
        glass.addSubview(progressBar)

        // ── Footer ────────────────────────────────────────────────────────
        footerLeft = lbl(size: 11, weight: .regular, color: NSColor(white: 1, alpha: 0.60))
        footerLeft.frame = NSRect(x: hPad, y: 14, width: 160, height: 14)
        footerLeft.autoresizingMask = [.width]
        glass.addSubview(footerLeft)

        footerRight = lbl(size: 11, weight: .regular, color: NSColor(white: 1, alpha: 0.60))
        footerRight.alignment = .right
        footerRight.frame = NSRect(x: W - hPad - 50, y: 14, width: 50, height: 14)
        footerRight.autoresizingMask = [.minXMargin]
        glass.addSubview(footerRight)

        // ── Resize grip ───────────────────────────────────────────────────
        resizeGrip = ResizeGrip(frame: NSRect(x: W - 18, y: 0, width: 18, height: 18))
        resizeGrip.autoresizingMask = [.minXMargin]
        resizeGrip.wantsLayer = true
        resizeGrip.alphaValue = 0
        glass.addSubview(resizeGrip)

        window.makeKeyAndOrderFront(nil)
        tick()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
    }

    func lbl(size: CGFloat, weight: NSFont.Weight, color: NSColor) -> NSTextField {
        let t = NSTextField(labelWithString: "")
        t.font = NSFont.systemFont(ofSize: size, weight: weight)
        t.textColor = color
        t.alignment = .left
        t.lineBreakMode = .byTruncatingTail
        t.maximumNumberOfLines = 1
        return t
    }

    // MARK: Tick

    func tick() {
        let now = Date()
        // Start predicate from start-of-day to catch ongoing events
        let dayStart = Calendar.current.startOfDay(for: now)
        let pred = store.predicateForEvents(withStart: dayStart,
                                            end: Date(timeIntervalSinceNow: 86400),
                                            calendars: nil)
        let events = store.events(matching: pred)

        if let ev = events.filter({ $0.startDate <= now && $0.endDate > now })
                          .sorted(by: { $0.endDate < $1.endDate }).first {
            // ── Active event ──
            let remaining = ev.endDate.timeIntervalSince(now)
            let total     = ev.endDate.timeIntervalSince(ev.startDate)
            let frac      = total > 0 ? max(0, min(1, remaining / total)) : 0
            let color     = urgencyColor(frac: frac)

            dotView.color = color
            titleLabel.stringValue = ev.title ?? "Untitled"
            digitLabel.stringValue = fmt(Int(remaining))
            digitLabel.textColor   = .white
            progressBar.fraction   = CGFloat(frac)
            progressBar.barColor   = color

            let tf = DateFormatter(); tf.dateFormat = "h:mm a"
            footerLeft.stringValue  = "ends \(tf.string(from: ev.endDate))"
            footerRight.stringValue = "\(Int(frac * 100))%"

            frac <= 0.10 ? startPulse() : stopPulse()

        } else if let nxt = events.filter({ $0.startDate > now })
                                  .sorted(by: { $0.startDate < $1.startDate }).first {
            // ── Upcoming event ──
            let wait  = nxt.startDate.timeIntervalSince(now)
            let color = urgencyColor(frac: 1.0)
            dotView.color = NSColor(white: 1, alpha: 0.35)
            titleLabel.stringValue = "Next: \(nxt.title ?? "Untitled")"
            digitLabel.stringValue = fmt(Int(wait))
            digitLabel.textColor   = NSColor(white: 1, alpha: 0.45)
            progressBar.fraction   = 0
            progressBar.barColor   = color
            let tf = DateFormatter(); tf.dateFormat = "h:mm a"
            footerLeft.stringValue  = "starts \(tf.string(from: nxt.startDate))"
            footerRight.stringValue = "--"
            stopPulse()

        } else {
            // ── Idle ──
            dotView.color = NSColor(white: 1, alpha: 0.25)
            titleLabel.stringValue  = "No upcoming events"
            digitLabel.stringValue  = "--:--:--"
            digitLabel.textColor    = NSColor(white: 1, alpha: 0.35)
            progressBar.fraction    = 0
            footerLeft.stringValue  = ""
            footerRight.stringValue = ""
            stopPulse()
        }
    }

    func fmt(_ secs: Int) -> String {
        String(format: "%02d:%02d:%02d", secs / 3600, (secs % 3600) / 60, secs % 60)
    }

    // MARK: Pulse

    func startPulse() {
        guard pulseTimer == nil else { return }
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.pulsing.toggle()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.6
                self.window.animator().alphaValue = self.pulsing ? 0.72 : 0.98
            }
        }
    }

    func stopPulse() {
        pulseTimer?.invalidate(); pulseTimer = nil
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            self.window.animator().alphaValue = 0.94
        }
    }

    @objc func quit() { NSApp.terminate(nil) }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

// MARK: - Entry point

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
