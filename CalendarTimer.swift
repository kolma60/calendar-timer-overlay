import Cocoa
import EventKit
import ServiceManagement

// MARK: - Settings

class Settings {
    static let shared = Settings()
    private let d = UserDefaults.standard

    // Keys
    private let kOpacity = "bgOpacity"
    private let kUrgency = "urgencyEnabled"
    private let kUrgentT = "urgentThreshold"
    private let kCritT   = "criticalThreshold"
    private let kCalm    = "calmColor"
    private let kMid     = "midColor"
    private let kHot     = "hotColor"

    // Defaults
    static let dfOpacity: CGFloat = 0.94
    static let dfUrgent:  CGFloat = 0.25
    static let dfCrit:    CGFloat = 0.20
    static let dfCalm = NSColor(red: 0.25, green: 0.75, blue: 0.46, alpha: 1)
    static let dfMid  = NSColor(red: 0.88, green: 0.72, blue: 0.16, alpha: 1)
    static let dfHot  = NSColor(red: 0.87, green: 0.36, blue: 0.25, alpha: 1)

    var bgOpacity: CGFloat {
        get { (d.object(forKey: kOpacity) as? Double).map { CGFloat($0) } ?? Settings.dfOpacity }
        set { d.set(Double(newValue), forKey: kOpacity) }
    }
    var urgencyEnabled: Bool {
        get { (d.object(forKey: kUrgency) as? Bool) ?? true }
        set { d.set(newValue, forKey: kUrgency) }
    }
    var urgentThreshold: CGFloat {
        get { (d.object(forKey: kUrgentT) as? Double).map { CGFloat($0) } ?? Settings.dfUrgent }
        set { d.set(Double(newValue), forKey: kUrgentT) }
    }
    var criticalThreshold: CGFloat {
        get { (d.object(forKey: kCritT) as? Double).map { CGFloat($0) } ?? Settings.dfCrit }
        set { d.set(Double(newValue), forKey: kCritT) }
    }
    var calmColor: NSColor {
        get { loadColor(kCalm) ?? Settings.dfCalm }
        set { saveColor(newValue, key: kCalm) }
    }
    var midColor: NSColor {
        get { loadColor(kMid) ?? Settings.dfMid }
        set { saveColor(newValue, key: kMid) }
    }
    var hotColor: NSColor {
        get { loadColor(kHot) ?? Settings.dfHot }
        set { saveColor(newValue, key: kHot) }
    }

    func resetColorsAndThresholds() {
        d.removeObject(forKey: kUrgentT)
        d.removeObject(forKey: kCritT)
        d.removeObject(forKey: kCalm)
        d.removeObject(forKey: kMid)
        d.removeObject(forKey: kHot)
    }

    private func loadColor(_ key: String) -> NSColor? {
        guard let a = d.array(forKey: key) as? [Double], a.count == 4 else { return nil }
        return NSColor(srgbRed: a[0], green: a[1], blue: a[2], alpha: a[3])
    }
    private func saveColor(_ c: NSColor, key: String) {
        let rgb = c.usingColorSpace(.sRGB) ?? c
        d.set([Double(rgb.redComponent), Double(rgb.greenComponent),
               Double(rgb.blueComponent), Double(rgb.alphaComponent)], forKey: key)
    }
}

// MARK: - Colors

let neutralAccent = NSColor(white: 1.0, alpha: 0.55)

func urgencyColor(frac: Double, enabled: Bool) -> NSColor {
    if !enabled { return neutralAccent }
    let s = Settings.shared
    if frac > Double(s.urgentThreshold)   { return s.calmColor }
    if frac > Double(s.criticalThreshold) { return s.midColor }
    return s.hotColor
}

// MARK: - Passthrough label (doesn't intercept mouse — drag works over text)

class PassthroughLabel: NSTextField {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

// MARK: - Dot indicator

class DotView: NSView {
    var color: NSColor = NSColor(red: 0.25, green: 0.75, blue: 0.46, alpha: 1) {
        didSet { needsDisplay = true }
    }
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 5, color: color.cgColor)
        let p = NSBezierPath(ovalIn: bounds.insetBy(dx: 0.5, dy: 0.5))
        color.setFill(); p.fill()
        ctx.restoreGState()
    }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

// MARK: - Progress bar

class ProgressBarView: NSView {
    var fraction: CGFloat = 1.0 { didSet { needsDisplay = true } }
    var barColor: NSColor = NSColor(red: 0.25, green: 0.75, blue: 0.46, alpha: 1) {
        didSet { needsDisplay = true }
    }
    override func draw(_ dirtyRect: NSRect) {
        let r = bounds.height / 2
        let track = NSBezierPath(roundedRect: bounds, xRadius: r, yRadius: r)
        NSColor(white: 1, alpha: 0.14).setFill(); track.fill()
        NSColor(white: 0, alpha: 0.18).setStroke(); track.lineWidth = 0.5; track.stroke()
        let fw = max(0, bounds.width * fraction)
        if fw > 0 {
            let fillPath = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: fw, height: bounds.height),
                                        xRadius: r, yRadius: r)
            barColor.setFill(); fillPath.fill()
        }
    }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

// MARK: - Round glass chip button

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

// MARK: - Glass background (rendering + pulse ring)

class GlassView: NSVisualEffectView {
    private let cr: CGFloat = 20
    private let pulseLayer = CAShapeLayer()

    override init(frame: NSRect) {
        super.init(frame: frame)
        material = .hudWindow; blendingMode = .behindWindow; state = .active
        wantsLayer = true
        layer?.cornerRadius  = cr
        layer?.cornerCurve   = .continuous
        layer?.masksToBounds = true

        pulseLayer.fillColor = NSColor.clear.cgColor
        pulseLayer.lineWidth = 2.5
        pulseLayer.opacity = 0
        layer?.addSublayer(pulseLayer)
        updatePulsePath()
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layout() { super.layout(); updatePulsePath() }
    override func setFrameSize(_ s: NSSize) { super.setFrameSize(s); updatePulsePath() }

    private func updatePulsePath() {
        pulseLayer.frame = bounds
        pulseLayer.path = CGPath(roundedRect: bounds.insetBy(dx: 1.5, dy: 1.5),
                                 cornerWidth: cr - 1.5, cornerHeight: cr - 1.5,
                                 transform: nil)
    }

    func startPulse(color: NSColor) {
        pulseLayer.strokeColor = color.cgColor
        if pulseLayer.animation(forKey: "pulse-opacity") != nil { return }
        let op = CABasicAnimation(keyPath: "opacity")
        op.fromValue = 0.25; op.toValue = 0.95
        op.duration = 0.85; op.autoreverses = true; op.repeatCount = .infinity
        op.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        pulseLayer.add(op, forKey: "pulse-opacity")

        let lw = CABasicAnimation(keyPath: "lineWidth")
        lw.fromValue = 1.5; lw.toValue = 3.5
        lw.duration = 0.85; lw.autoreverses = true; lw.repeatCount = .infinity
        lw.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        pulseLayer.add(lw, forKey: "pulse-width")
    }

    func stopPulse() {
        pulseLayer.removeAllAnimations()
        pulseLayer.opacity = 0
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5),
                                xRadius: cr - 0.5, yRadius: cr - 0.5)
        ctx.saveGState(); path.addClip()

        NSGradient(colors: [
            NSColor(white: 1, alpha: 0.22),
            NSColor(white: 1, alpha: 0.06),
            NSColor(white: 1, alpha: 0.12),
        ], atLocations: [0, 0.55, 1], colorSpace: .genericRGB)!.draw(in: bounds, angle: 90)

        let specPt = CGPoint(x: bounds.width * 0.30, y: bounds.height * 1.05)
        let cs = CGColorSpaceCreateDeviceRGB()
        let sc = [NSColor(white: 1, alpha: 0.38).cgColor,
                  NSColor(white: 1, alpha: 0.00).cgColor] as CFArray
        if let g = CGGradient(colorsSpace: cs, colors: sc, locations: [0, 1]) {
            ctx.drawRadialGradient(g, startCenter: specPt, startRadius: 0,
                                   endCenter: specPt, endRadius: bounds.width * 0.72, options: [])
        }

        NSGradient(colors: [
            NSColor(red: 1.0, green: 0.71, blue: 0.86, alpha: 0.10),
            NSColor(red: 0.71, green: 0.86, blue: 1.00, alpha: 0.00),
            NSColor(red: 0.78, green: 1.00, blue: 0.90, alpha: 0.08),
        ], atLocations: [0, 0.40, 1], colorSpace: .genericRGB)!.draw(in: bounds, angle: -60)

        ctx.restoreGState()
        path.lineWidth = 1.0
        NSColor(white: 1, alpha: 0.22).setStroke(); path.stroke()
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }  // clicks pass through
}

// MARK: - Content host (drag + hover)

class ContentHostView: NSView {
    var onHoverChange: ((Bool) -> Void)?
    private var dragOrigin: NSPoint?
    private var winOrigin: NSPoint?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        addTrackingArea(NSTrackingArea(rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self, userInfo: nil))
    }
    override func mouseEntered(with event: NSEvent) { onHoverChange?(true) }
    override func mouseExited(with event: NSEvent)  { onHoverChange?(false) }

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
        let nw = max(260, min(380, f.width + (c.x - s.x)))
        var nh = max(110, min(380, f.height - (c.y - s.y)))
        nh = min(nh, nw)  // cap aspect ratio at 1:1 (never taller than wide)
        window?.setFrame(NSRect(x: f.origin.x, y: f.maxY - nh, width: nw, height: nh), display: true)
    }
    override func mouseUp(with event: NSEvent) { ds = nil; fa = nil }
}

// MARK: - Panel

class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool  { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - Settings popover VC

class SettingsVC: NSViewController {
    var onOpacityChange: ((CGFloat) -> Void)?
    var onUrgencyToggle: ((Bool) -> Void)?
    var onColorsChanged: (() -> Void)?

    private var urgencySwitch: NSSwitch!
    private var urgentSlider: NSSlider!
    private var urgentValueLbl: NSTextField!
    private var critSlider: NSSlider!
    private var critValueLbl: NSTextField!
    private var calmWell: NSColorWell!
    private var midWell: NSColorWell!
    private var hotWell: NSColorWell!

    override func loadView() {
        let W: CGFloat = 300
        let H: CGFloat = 380
        let inset: CGFloat = 16
        let sw = W - inset * 2
        let v = NSView(frame: NSRect(x: 0, y: 0, width: W, height: H))

        // Title
        let title = NSTextField(labelWithString: "Timer settings")
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        title.frame = NSRect(x: inset, y: H - 30, width: sw, height: 18)
        v.addSubview(title)

        // Background opacity
        let opLbl = NSTextField(labelWithString: "Background opacity")
        opLbl.font = .systemFont(ofSize: 11, weight: .medium)
        opLbl.textColor = .secondaryLabelColor
        opLbl.frame = NSRect(x: inset, y: H - 56, width: sw, height: 14)
        v.addSubview(opLbl)

        let opSlider = NSSlider(value: Double(Settings.shared.bgOpacity),
                                minValue: 0.3, maxValue: 1.0,
                                target: self, action: #selector(opacityChanged(_:)))
        opSlider.isContinuous = true
        opSlider.frame = NSRect(x: inset, y: H - 82, width: sw, height: 22)
        v.addSubview(opSlider)

        // Urgency toggle
        let togLbl = NSTextField(labelWithString: "Urgency colors & pulse")
        togLbl.font = .systemFont(ofSize: 12)
        togLbl.frame = NSRect(x: inset, y: H - 114, width: sw - 50, height: 18)
        v.addSubview(togLbl)

        urgencySwitch = NSSwitch()
        urgencySwitch.state = Settings.shared.urgencyEnabled ? .on : .off
        urgencySwitch.target = self
        urgencySwitch.action = #selector(urgencyToggle(_:))
        urgencySwitch.frame = NSRect(x: W - inset - 40, y: H - 118, width: 40, height: 24)
        v.addSubview(urgencySwitch)

        // Separator
        addSeparator(to: v, y: H - 140, width: sw, inset: inset)

        // Urgent threshold
        let urgLbl = NSTextField(labelWithString: "Urgent color starts below")
        urgLbl.font = .systemFont(ofSize: 11, weight: .medium)
        urgLbl.textColor = .secondaryLabelColor
        urgLbl.frame = NSRect(x: inset, y: H - 164, width: sw - 50, height: 14)
        v.addSubview(urgLbl)

        urgentValueLbl = NSTextField(labelWithString: "")
        urgentValueLbl.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        urgentValueLbl.textColor = .secondaryLabelColor
        urgentValueLbl.alignment = .right
        urgentValueLbl.frame = NSRect(x: W - inset - 48, y: H - 164, width: 48, height: 14)
        v.addSubview(urgentValueLbl)

        urgentSlider = NSSlider(value: Double(Settings.shared.urgentThreshold) * 100,
                                minValue: 5, maxValue: 75,
                                target: self, action: #selector(urgentChanged(_:)))
        urgentSlider.isContinuous = true
        urgentSlider.frame = NSRect(x: inset, y: H - 186, width: sw, height: 22)
        v.addSubview(urgentSlider)

        // Critical threshold
        let crLbl = NSTextField(labelWithString: "Critical + pulse starts below")
        crLbl.font = .systemFont(ofSize: 11, weight: .medium)
        crLbl.textColor = .secondaryLabelColor
        crLbl.frame = NSRect(x: inset, y: H - 214, width: sw - 50, height: 14)
        v.addSubview(crLbl)

        critValueLbl = NSTextField(labelWithString: "")
        critValueLbl.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        critValueLbl.textColor = .secondaryLabelColor
        critValueLbl.alignment = .right
        critValueLbl.frame = NSRect(x: W - inset - 48, y: H - 214, width: 48, height: 14)
        v.addSubview(critValueLbl)

        critSlider = NSSlider(value: Double(Settings.shared.criticalThreshold) * 100,
                              minValue: 0, maxValue: 50,
                              target: self, action: #selector(critChanged(_:)))
        critSlider.isContinuous = true
        critSlider.frame = NSRect(x: inset, y: H - 236, width: sw, height: 22)
        v.addSubview(critSlider)

        updateThresholdLabels()

        // Separator
        addSeparator(to: v, y: H - 256, width: sw, inset: inset)

        // Colors section
        let colLbl = NSTextField(labelWithString: "Colors")
        colLbl.font = .systemFont(ofSize: 11, weight: .medium)
        colLbl.textColor = .secondaryLabelColor
        colLbl.frame = NSRect(x: inset, y: H - 278, width: sw, height: 14)
        v.addSubview(colLbl)

        // Three color wells with labels
        let wellW: CGFloat = 50, wellH: CGFloat = 26
        let wellY: CGFloat = H - 318
        let labelY: CGFloat = wellY - 16
        let colW = sw / 3

        calmWell = makeWell(color: Settings.shared.calmColor, action: #selector(calmChanged(_:)))
        calmWell.frame = NSRect(x: inset + (colW - wellW)/2, y: wellY, width: wellW, height: wellH)
        v.addSubview(calmWell)
        addColorLabel(to: v, text: "Calm", x: inset, width: colW, y: labelY)

        midWell = makeWell(color: Settings.shared.midColor, action: #selector(midChanged(_:)))
        midWell.frame = NSRect(x: inset + colW + (colW - wellW)/2, y: wellY, width: wellW, height: wellH)
        v.addSubview(midWell)
        addColorLabel(to: v, text: "Urgent", x: inset + colW, width: colW, y: labelY)

        hotWell = makeWell(color: Settings.shared.hotColor, action: #selector(hotChanged(_:)))
        hotWell.frame = NSRect(x: inset + colW * 2 + (colW - wellW)/2, y: wellY, width: wellW, height: wellH)
        v.addSubview(hotWell)
        addColorLabel(to: v, text: "Critical", x: inset + colW * 2, width: colW, y: labelY)

        // Reset button
        let reset = NSButton(title: "Reset thresholds & colors",
                             target: self, action: #selector(resetTapped))
        reset.bezelStyle = .rounded
        reset.frame = NSRect(x: inset, y: 14, width: sw, height: 26)
        v.addSubview(reset)

        self.view = v
    }

    // Helpers
    private func addSeparator(to v: NSView, y: CGFloat, width: CGFloat, inset: CGFloat) {
        let sep = NSBox(frame: NSRect(x: inset, y: y, width: width, height: 1))
        sep.boxType = .separator
        v.addSubview(sep)
    }
    private func addColorLabel(to v: NSView, text: String, x: CGFloat, width: CGFloat, y: CGFloat) {
        let l = NSTextField(labelWithString: text)
        l.font = .systemFont(ofSize: 10)
        l.textColor = .tertiaryLabelColor
        l.alignment = .center
        l.frame = NSRect(x: x, y: y, width: width, height: 12)
        v.addSubview(l)
    }
    private func makeWell(color: NSColor, action: Selector) -> NSColorWell {
        let w = NSColorWell()
        w.color = color
        w.target = self
        w.action = action
        return w
    }
    private func updateThresholdLabels() {
        urgentValueLbl.stringValue = "\(Int(urgentSlider.doubleValue))%"
        critValueLbl.stringValue   = "\(Int(critSlider.doubleValue))%"
    }

    // Actions
    @objc func opacityChanged(_ s: NSSlider) {
        let v = CGFloat(s.doubleValue)
        Settings.shared.bgOpacity = v
        onOpacityChange?(v)
    }
    @objc func urgencyToggle(_ s: NSSwitch) {
        let on = s.state == .on
        Settings.shared.urgencyEnabled = on
        onUrgencyToggle?(on)
    }
    @objc func urgentChanged(_ s: NSSlider) {
        let v = s.doubleValue
        if v < critSlider.doubleValue {
            critSlider.doubleValue = v
            Settings.shared.criticalThreshold = CGFloat(v / 100)
        }
        Settings.shared.urgentThreshold = CGFloat(v / 100)
        updateThresholdLabels()
        onColorsChanged?()
    }
    @objc func critChanged(_ s: NSSlider) {
        let v = s.doubleValue
        if v > urgentSlider.doubleValue {
            urgentSlider.doubleValue = v
            Settings.shared.urgentThreshold = CGFloat(v / 100)
        }
        Settings.shared.criticalThreshold = CGFloat(v / 100)
        updateThresholdLabels()
        onColorsChanged?()
    }
    @objc func calmChanged(_ w: NSColorWell) {
        Settings.shared.calmColor = w.color
        onColorsChanged?()
    }
    @objc func midChanged(_ w: NSColorWell) {
        Settings.shared.midColor = w.color
        onColorsChanged?()
    }
    @objc func hotChanged(_ w: NSColorWell) {
        Settings.shared.hotColor = w.color
        onColorsChanged?()
    }
    @objc func resetTapped() {
        Settings.shared.resetColorsAndThresholds()
        urgentSlider.doubleValue = Double(Settings.dfUrgent) * 100
        critSlider.doubleValue   = Double(Settings.dfCrit) * 100
        calmWell.color = Settings.dfCalm
        midWell.color  = Settings.dfMid
        hotWell.color  = Settings.dfHot
        updateThresholdLabels()
        onColorsChanged?()
    }
}

// MARK: - Mark-Done popover VC

class MarkDoneVC: NSViewController, NSTextFieldDelegate {
    var eventTitle: String = ""
    var remainingSeconds: TimeInterval = 0
    var onStartNewTask: ((String) -> Void)?
    var onJustEnd: (() -> Void)?
    var onCancel: (() -> Void)?

    private var nameField: NSTextField!
    private var startBtn: NSButton!

    override func loadView() {
        let forceNew = remainingSeconds > 300
        let w: CGFloat = 340
        let h: CGFloat = 184
        let v = NSView(frame: NSRect(x: 0, y: 0, width: w, height: h))

        let titleL = NSTextField(labelWithString: "Mark as done")
        titleL.font = .systemFont(ofSize: 13, weight: .semibold)
        titleL.frame = NSRect(x: 16, y: h - 30, width: w - 32, height: 18)
        v.addSubview(titleL)

        let subL = NSTextField(labelWithString: "\(eventTitle) — \(fmtDur(remainingSeconds)) left")
        subL.font = .systemFont(ofSize: 11)
        subL.textColor = .secondaryLabelColor
        subL.lineBreakMode = .byTruncatingTail
        subL.frame = NSRect(x: 16, y: h - 50, width: w - 32, height: 16)
        v.addSubview(subL)

        let prompt = NSTextField(labelWithString:
            forceNew ? "Next task name (required — more than 5 min left)"
                     : "Next task name")
        prompt.font = .systemFont(ofSize: 11, weight: .medium)
        prompt.textColor = .secondaryLabelColor
        prompt.frame = NSRect(x: 16, y: h - 80, width: w - 32, height: 14)
        v.addSubview(prompt)

        nameField = NSTextField(frame: NSRect(x: 16, y: h - 112, width: w - 32, height: 24))
        nameField.placeholderString = "What's next?"
        nameField.font = .systemFont(ofSize: 13)
        nameField.delegate = self
        nameField.target = self
        nameField.action = #selector(startFromField)
        v.addSubview(nameField)

        // Buttons row
        let cancelBtn = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancelBtn.bezelStyle = .rounded
        cancelBtn.keyEquivalent = "\u{1b}"
        cancelBtn.frame = NSRect(x: 16, y: 16, width: 76, height: 28)
        v.addSubview(cancelBtn)

        var rightX = w - 16

        startBtn = NSButton(title: "Start next task", target: self, action: #selector(startNext))
        startBtn.bezelStyle = .rounded
        startBtn.keyEquivalent = "\r"
        startBtn.isEnabled = false
        let startW: CGFloat = 132
        rightX -= startW
        startBtn.frame = NSRect(x: rightX, y: 16, width: startW, height: 28)
        v.addSubview(startBtn)

        if !forceNew {
            let just = NSButton(title: "Just end", target: self, action: #selector(justEnd))
            just.bezelStyle = .rounded
            let jw: CGFloat = 80
            rightX -= (jw + 6)
            just.frame = NSRect(x: rightX, y: 16, width: jw, height: 28)
            v.addSubview(just)
        }

        self.view = v

        DispatchQueue.main.async { [weak self] in
            self?.nameField.becomeFirstResponder()
        }
    }

    func controlTextDidChange(_ obj: Notification) {
        let s = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        startBtn.isEnabled = !s.isEmpty
    }

    @objc func startFromField() { startNext() }

    @objc func startNext() {
        let s = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return }
        onStartNewTask?(s)
    }

    @objc func justEnd() { onJustEnd?() }
    @objc func cancel() { onCancel?() }

    private func fmtDur(_ s: TimeInterval) -> String {
        let i = max(0, Int(s))
        let h = i / 3600, m = (i % 3600) / 60, sec = i % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, sec)
            : String(format: "%d:%02d", m, sec)
    }
}

// MARK: - App delegate

class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate, NSWindowDelegate, NSMenuDelegate {
    var window: OverlayPanel!
    var glass: GlassView!
    var content: ContentHostView!

    var dotView: DotView!
    var titleLabel: PassthroughLabel!
    var digitLabel: PassthroughLabel!
    var leftLabel: PassthroughLabel!
    var progressBar: ProgressBarView!
    var footerLeft: PassthroughLabel!
    var footerRight: PassthroughLabel!
    var closeBtn: ChipButton!
    var gearBtn: ChipButton!
    var doneBtn: ChipButton!
    var resizeGrip: ResizeGrip!

    var settingsPopover: NSPopover?
    var markDonePopover: NSPopover?
    var hovering = false
    var showingDone = false

    var store = EKEventStore()
    var ticker: Timer?
    var currentEvent: EKEvent?

    var statusItem: NSStatusItem?
    var toggleWindowItem: NSMenuItem!
    var launchAtLoginItem: NSMenuItem!

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

    // MARK: Build

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
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.minSize = NSSize(width: 260, height: 110)
        window.maxSize = NSSize(width: 380, height: 380)
        window.delegate = self

        let cv = window.contentView!

        // ── Layer 1: glass (background only, opacity-controllable) ──
        glass = GlassView(frame: cv.bounds)
        glass.autoresizingMask = [.width, .height]
        glass.alphaValue = Settings.shared.bgOpacity
        cv.addSubview(glass)

        // ── Layer 2: content host (all text/buttons, always opaque) ──
        content = ContentHostView(frame: cv.bounds)
        content.autoresizingMask = [.width, .height]
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor.clear.cgColor
        content.onHoverChange = { [weak self] h in
            self?.hovering = h
            self?.updateChromeVisibility()
        }
        cv.addSubview(content)

        let hPad: CGFloat = 18
        let headerY: CGFloat = H - 12 - 20

        dotView = DotView(frame: NSRect(x: hPad, y: headerY + 7, width: 6, height: 6))
        dotView.autoresizingMask = [.minYMargin]
        content.addSubview(dotView)

        titleLabel = lbl(size: 11, weight: .semibold, color: NSColor(white: 1, alpha: 0.92))
        titleLabel.frame = NSRect(x: hPad + 14, y: headerY, width: W - hPad * 2 - 78, height: 20)
        titleLabel.autoresizingMask = [.width, .minYMargin]
        content.addSubview(titleLabel)

        doneBtn = ChipButton(frame: NSRect(x: W - hPad - 68, y: headerY, width: 20, height: 20))
        doneBtn.autoresizingMask = [.minXMargin, .minYMargin]
        doneBtn.image = NSImage(systemSymbolName: "checkmark", accessibilityDescription: "Mark done")
        doneBtn.contentTintColor = NSColor(white: 1, alpha: 0.82)
        doneBtn.imageScaling = .scaleProportionallyDown
        doneBtn.alphaValue = 0
        doneBtn.target = self; doneBtn.action = #selector(markDone(_:))
        content.addSubview(doneBtn)

        gearBtn = ChipButton(frame: NSRect(x: W - hPad - 44, y: headerY, width: 20, height: 20))
        gearBtn.autoresizingMask = [.minXMargin, .minYMargin]
        gearBtn.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings")
        gearBtn.contentTintColor = NSColor(white: 1, alpha: 0.82)
        gearBtn.imageScaling = .scaleProportionallyDown
        gearBtn.alphaValue = 0
        gearBtn.target = self; gearBtn.action = #selector(showSettings(_:))
        content.addSubview(gearBtn)

        closeBtn = ChipButton(frame: NSRect(x: W - hPad - 20, y: headerY, width: 20, height: 20))
        closeBtn.autoresizingMask = [.minXMargin, .minYMargin]
        closeBtn.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Quit")
        closeBtn.contentTintColor = NSColor(white: 1, alpha: 0.82)
        closeBtn.imageScaling = .scaleProportionallyDown
        closeBtn.alphaValue = 0
        closeBtn.target = self; closeBtn.action = #selector(toggleWindow(_:))
        content.addSubview(closeBtn)

        let digitY: CGFloat = 44
        digitLabel = lbl(size: 40, weight: .semibold, color: .white)
        digitLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 40, weight: .semibold)
        digitLabel.stringValue = "--:--:--"
        digitLabel.frame = NSRect(x: hPad, y: digitY, width: W - hPad * 2 - 34, height: 50)
        digitLabel.autoresizingMask = [.width]
        content.addSubview(digitLabel)

        leftLabel = lbl(size: 12, weight: .medium, color: NSColor(white: 1, alpha: 0.62))
        leftLabel.stringValue = "left"
        leftLabel.frame = NSRect(x: W - hPad - 30, y: digitY + 6, width: 30, height: 16)
        leftLabel.autoresizingMask = [.minXMargin]
        content.addSubview(leftLabel)

        progressBar = ProgressBarView(frame: NSRect(x: hPad, y: 34, width: W - hPad * 2, height: 5))
        progressBar.autoresizingMask = [.width]
        content.addSubview(progressBar)

        footerLeft = lbl(size: 11, weight: .regular, color: NSColor(white: 1, alpha: 0.60))
        footerLeft.frame = NSRect(x: hPad, y: 14, width: 160, height: 14)
        footerLeft.autoresizingMask = [.width]
        content.addSubview(footerLeft)

        footerRight = lbl(size: 11, weight: .regular, color: NSColor(white: 1, alpha: 0.60))
        footerRight.alignment = .right
        footerRight.frame = NSRect(x: W - hPad - 50, y: 14, width: 50, height: 14)
        footerRight.autoresizingMask = [.minXMargin]
        content.addSubview(footerRight)

        resizeGrip = ResizeGrip(frame: NSRect(x: W - 18, y: 0, width: 18, height: 18))
        resizeGrip.autoresizingMask = [.minXMargin]
        resizeGrip.wantsLayer = true
        resizeGrip.alphaValue = 0
        content.addSubview(resizeGrip)

        window.makeKeyAndOrderFront(nil)
        setupStatusBar()
        relayout()
        tick()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
    }

    // MARK: Scaling layout

    func relayout() {
        guard let cv = window?.contentView else { return }
        let W = cv.bounds.width
        let H = cv.bounds.height
        let s = max(0.85, min(1.6, min(W / 300.0, H / 130.0)))

        let hPad: CGFloat = 18
        let chipSize: CGFloat = 20 * s
        let gap: CGFloat = 4 * s
        let cr = chipSize / 2

        // Header
        let headerH: CGFloat = 20 * s
        let topPad: CGFloat  = 12 * s
        let headerY = H - topPad - headerH

        closeBtn.frame = NSRect(x: W - hPad - chipSize, y: headerY, width: chipSize, height: chipSize)
        closeBtn.layer?.cornerRadius = cr
        gearBtn.frame  = NSRect(x: W - hPad - chipSize*2 - gap, y: headerY, width: chipSize, height: chipSize)
        gearBtn.layer?.cornerRadius = cr
        doneBtn.frame  = NSRect(x: W - hPad - chipSize*3 - gap*2, y: headerY, width: chipSize, height: chipSize)
        doneBtn.layer?.cornerRadius = cr

        let dotSize: CGFloat = 6 * s
        dotView.frame = NSRect(x: hPad, y: headerY + (headerH - dotSize)/2,
                               width: dotSize, height: dotSize)

        let titleX = hPad + dotSize + 8 * s
        let titleRightX = doneBtn.frame.minX - 6 * s
        titleLabel.frame = NSRect(x: titleX, y: headerY,
                                  width: max(0, titleRightX - titleX), height: headerH)
        titleLabel.font = NSFont.systemFont(ofSize: 11 * s, weight: .semibold)

        // Footer + progress
        let footerH: CGFloat = 14 * s
        let footerY: CGFloat = 14 * s
        footerLeft.font  = NSFont.systemFont(ofSize: 11 * s, weight: .regular)
        footerRight.font = NSFont.systemFont(ofSize: 11 * s, weight: .regular)
        footerLeft.frame  = NSRect(x: hPad,   y: footerY, width: W/2 - hPad, height: footerH)
        footerRight.frame = NSRect(x: W/2,    y: footerY, width: W/2 - hPad, height: footerH)

        let progressH: CGFloat = 5 * s
        let progressY = footerY + footerH + 6 * s
        progressBar.frame = NSRect(x: hPad, y: progressY,
                                   width: W - hPad*2, height: progressH)

        // Digit — centered between header and progress
        let digitSize: CGFloat = 40 * s
        let digitH = digitSize * 1.3
        let availTop = headerY - 6 * s
        let availBot = progressY + progressH + 4 * s
        let digitY = availBot + max(0, (availTop - availBot - digitH) / 2)
        let leftW: CGFloat = 30 * s

        if showingDone {
            digitLabel.font = NSFont.systemFont(ofSize: digitSize, weight: .semibold)
            digitLabel.alignment = .center
            digitLabel.frame = NSRect(x: hPad, y: digitY, width: W - hPad*2, height: digitH)
            leftLabel.isHidden = true
        } else {
            digitLabel.font = NSFont.monospacedDigitSystemFont(ofSize: digitSize, weight: .semibold)
            digitLabel.alignment = .left
            digitLabel.frame = NSRect(x: hPad, y: digitY,
                                      width: W - hPad*2 - leftW - 4, height: digitH)
            leftLabel.isHidden = false
        }
        leftLabel.font = NSFont.systemFont(ofSize: 12 * s, weight: .medium)
        leftLabel.frame = NSRect(x: W - hPad - leftW, y: digitY + digitH * 0.25,
                                 width: leftW, height: 16 * s)

        let gripSize: CGFloat = 18 * s
        resizeGrip.frame = NSRect(x: W - gripSize, y: 0, width: gripSize, height: gripSize)
        resizeGrip.needsDisplay = true
    }

    func windowDidResize(_ notification: Notification) { relayout() }

    func lbl(size: CGFloat, weight: NSFont.Weight, color: NSColor) -> PassthroughLabel {
        let t = PassthroughLabel(labelWithString: "")
        t.font = NSFont.systemFont(ofSize: size, weight: weight)
        t.textColor = color
        t.alignment = .left
        t.lineBreakMode = .byTruncatingTail
        t.maximumNumberOfLines = 1
        t.isBezeled = false; t.drawsBackground = false; t.isEditable = false; t.isSelectable = false
        return t
    }

    // MARK: Chrome visibility

    var anyPopoverOpen: Bool {
        (settingsPopover?.isShown ?? false) || (markDonePopover?.isShown ?? false)
    }

    func updateChromeVisibility() {
        let visible = hovering || anyPopoverOpen
        let hasEvent = currentEvent != nil
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            closeBtn.animator().alphaValue    = visible ? 1 : 0
            gearBtn.animator().alphaValue     = visible ? 1 : 0
            doneBtn.animator().alphaValue     = (visible && hasEvent) ? 1 : 0
            resizeGrip.animator().alphaValue  = visible ? 1 : 0
        }
        doneBtn.isEnabled = hasEvent
    }

    // MARK: Settings popover

    @objc func showSettings(_ sender: NSButton) {
        if let p = settingsPopover, p.isShown {
            p.performClose(nil); return
        }
        let p = NSPopover()
        p.behavior = .transient
        p.delegate = self
        let vc = SettingsVC()
        vc.onOpacityChange = { [weak self] v in
            guard let self else { return }
            self.glass.animator().alphaValue = v
        }
        vc.onUrgencyToggle = { [weak self] _ in self?.tick() }
        vc.onColorsChanged = { [weak self] in self?.tick() }
        p.contentViewController = vc
        settingsPopover = p
        updateChromeVisibility()
        p.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
    }

    // MARK: Mark-done popover

    @objc func markDone(_ sender: NSButton) {
        if let p = markDonePopover, p.isShown {
            p.performClose(nil); return
        }
        if let sp = settingsPopover, sp.isShown {
            sp.performClose(nil)
            settingsPopover = nil
        }
        guard let ev = currentEvent else { return }
        let remaining = max(0, ev.endDate.timeIntervalSinceNow)

        let p = NSPopover()
        p.behavior = .semitransient
        p.delegate = self
        let vc = MarkDoneVC()
        vc.eventTitle = ev.title ?? "Current event"
        vc.remainingSeconds = remaining
        vc.onStartNewTask = { [weak self] name in
            self?.completeAndStartNew(title: name)
        }
        vc.onJustEnd = { [weak self] in
            self?.completeCurrent()
        }
        vc.onCancel = { [weak self] in
            self?.markDonePopover?.performClose(nil)
        }
        p.contentViewController = vc
        markDonePopover = p
        updateChromeVisibility()
        p.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
    }

    func completeCurrent() {
        guard let ev = currentEvent else { return }
        ev.endDate = Date()
        do { try store.save(ev, span: .thisEvent) }
        catch { NSLog("Failed to save shortened event: \(error)") }
        markDonePopover?.performClose(nil)
        tick()
    }

    func completeAndStartNew(title: String) {
        guard let ev = currentEvent else { return }
        let originalEnd = ev.endDate
        let now = Date()

        ev.endDate = now
        do { try store.save(ev, span: .thisEvent) }
        catch { NSLog("Failed to save current: \(error)"); return }

        let newEv = EKEvent(eventStore: store)
        newEv.title = title
        newEv.startDate = now
        newEv.endDate = originalEnd
        newEv.calendar = store.defaultCalendarForNewEvents ?? ev.calendar
        do { try store.save(newEv, span: .thisEvent) }
        catch { NSLog("Failed to save new event: \(error)") }

        markDonePopover?.performClose(nil)
        tick()
    }

    func popoverDidClose(_ notification: Notification) {
        guard let p = notification.object as? NSPopover else { return }
        if p === settingsPopover { settingsPopover = nil }
        if p === markDonePopover { markDonePopover = nil }
        let mouse = NSEvent.mouseLocation
        hovering = window.frame.contains(mouse)
        updateChromeVisibility()
    }

    // MARK: Tick

    func tick() {
        let now = Date()
        let dayStart = Calendar.current.startOfDay(for: now)
        let pred = store.predicateForEvents(withStart: dayStart,
                                            end: Date(timeIntervalSinceNow: 86400),
                                            calendars: nil)
        let events = store.events(matching: pred)
        let urgency = Settings.shared.urgencyEnabled
        let maxDur: TimeInterval = 10 * 3600

        let prevHadEvent = currentEvent != nil
        let active = events.filter {
            $0.startDate <= now && $0.endDate > now &&
            $0.endDate.timeIntervalSince($0.startDate) <= maxDur
        }.sorted(by: { $0.endDate < $1.endDate })

        if let ev = active.first {
            if showingDone { showingDone = false; relayout() }
            currentEvent = ev
            let remaining = ev.endDate.timeIntervalSince(now)
            let total     = ev.endDate.timeIntervalSince(ev.startDate)
            let frac      = total > 0 ? max(0, min(1, remaining / total)) : 0
            let color     = urgencyColor(frac: frac, enabled: urgency)

            dotView.isHidden = false
            progressBar.isHidden = false
            dotView.color = color
            titleLabel.stringValue = ev.title ?? "Untitled"
            digitLabel.stringValue = fmt(Int(remaining))
            digitLabel.textColor   = .white
            leftLabel.stringValue  = "left"
            progressBar.fraction   = CGFloat(frac)
            progressBar.barColor   = color

            let tf = DateFormatter(); tf.dateFormat = "h:mm a"
            footerLeft.stringValue  = "ends \(tf.string(from: ev.endDate))"
            footerRight.stringValue = "\(Int(frac * 100))%"

            if urgency && frac <= Double(Settings.shared.criticalThreshold) {
                glass.startPulse(color: color)
            } else {
                glass.stopPulse()
            }

        } else {
            if !showingDone { showingDone = true; relayout() }
            currentEvent = nil
            dotView.isHidden = true
            progressBar.isHidden = true
            titleLabel.stringValue  = ""
            digitLabel.stringValue  = "Done!"
            digitLabel.textColor    = NSColor(white: 1, alpha: 0.92)
            leftLabel.stringValue   = ""
            footerLeft.stringValue  = ""
            footerRight.stringValue = ""
            glass.stopPulse()
        }

        if prevHadEvent != (currentEvent != nil) {
            updateChromeVisibility()
        }
    }

    func fmt(_ s: Int) -> String {
        String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }

    // MARK: Menubar

    func setupStatusBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let img = NSImage(systemSymbolName: "timer", accessibilityDescription: "Calendar Timer") {
            img.isTemplate = true
            item.button?.image = img
        } else {
            item.button?.title = "⏱"
        }

        let menu = NSMenu()
        menu.delegate = self

        toggleWindowItem = NSMenuItem(title: "Hide Timer",
                                      action: #selector(toggleWindow(_:)), keyEquivalent: "")
        toggleWindowItem.target = self
        menu.addItem(toggleWindowItem)

        menu.addItem(.separator())

        launchAtLoginItem = NSMenuItem(title: "Launch at Login",
                                       action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        launchAtLoginItem.target = self
        menu.addItem(launchAtLoginItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Calendar Timer",
                                  action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        statusItem = item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        toggleWindowItem.title = (window?.isVisible ?? false) ? "Hide Timer" : "Show Timer"
        if #available(macOS 13, *) {
            launchAtLoginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
            launchAtLoginItem.isEnabled = true
        } else {
            launchAtLoginItem.isEnabled = false
        }
    }

    @objc func toggleWindow(_ sender: Any?) {
        guard let w = window else { return }
        if w.isVisible {
            settingsPopover?.performClose(nil)
            markDonePopover?.performClose(nil)
            w.orderOut(nil)
        } else {
            w.makeKeyAndOrderFront(nil)
            relayout()
        }
    }

    @objc func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        guard #available(macOS 13, *) else { return }
        let svc = SMAppService.mainApp
        do {
            if svc.status == .enabled {
                try svc.unregister()
            } else {
                try svc.register()
            }
        } catch {
            let a = NSAlert()
            a.messageText = "Could not change Launch at Login setting"
            a.informativeText = "\(error.localizedDescription)\n\nMake sure Calendar Timer is in your /Applications folder."
            a.runModal()
        }
    }

    @objc func quit() { NSApp.terminate(nil) }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

// MARK: - Entry point

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
