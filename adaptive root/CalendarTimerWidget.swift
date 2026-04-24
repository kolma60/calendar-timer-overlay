//
//  CalendarTimerWidget.swift
//  adaptive root
//

import SwiftUI
import EventKit
import AppKit
import UniformTypeIdentifiers

struct CalendarTimerWidget: View {
    @State private var model = CalendarTimerModel()
    @State private var showingMarkDone = false
    @State private var pulsePhase = false
    @Binding private var showingSettings: Bool

    init(showingSettings: Binding<Bool> = .constant(false)) {
        _showingSettings = showingSettings
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let snapshot = model.snapshot(at: context.date)
            let display = CalendarTimerDisplay(snapshot: snapshot, now: context.date)

            ZStack {
                if let image = CalendarTimerSettings.shared.backgroundImage {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .opacity(0.62)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }

                if CalendarTimerSettings.shared.backgroundImage != nil {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.black.opacity(0.22))
                }

                CalendarTimerGlassBackground(opacity: CalendarTimerSettings.shared.bgOpacity)

                if display.shouldPulse {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(display.tint.opacity(pulsePhase ? 0.95 : 0.25), lineWidth: pulsePhase ? 3.5 : 1.5)
                        .animation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true), value: pulsePhase)
                }

                VStack(spacing: 0) {
                    topBar(display: display)
                    centerContent(display: display)
                    bottomSection(display: display)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .shadow(color: Color.black.opacity(0.18), radius: 3, x: 0, y: 1)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .popover(isPresented: $showingSettings, arrowEdge: .top) {
            CalendarTimerSettingsPanel(onChanged: {
                Task { await model.refresh() }
            })
        }
        .task {
            pulsePhase = true
            await model.activate()
        }
    }

    private func topBar(display: CalendarTimerDisplay) -> some View {
        HStack(spacing: 8) {
            if display.showsDot {
                Circle()
                    .fill(display.tint)
                    .frame(width: 6, height: 6)
                    .shadow(color: display.tint, radius: 5)
            }

            Text(display.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(nsColor: CalendarTimerSettings.shared.textColor).opacity(0.92))
                .lineLimit(1)

            Spacer()

            if display.hasActiveEvent {
                markDoneButton(display: display)
            }
        }
        .frame(height: 20)
    }

    private func centerContent(display: CalendarTimerDisplay) -> some View {
        Group {
            switch display.kind {
            case .countdown(let timeText):
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(timeText)
                        .font(.system(size: 40, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color(nsColor: CalendarTimerSettings.shared.textColor))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text("left")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(nsColor: CalendarTimerSettings.shared.accentColor))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            case .message(let text):
                if display.requiresAccessAction {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(text)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color(nsColor: CalendarTimerSettings.shared.textColor))

                        Button("Grant Access") {
                            Task { await model.requestAccess() }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                } else {
                    Text(text)
                        .font(.system(size: display.isDoneState ? 40 : 18, weight: .semibold))
                        .foregroundStyle(Color(nsColor: CalendarTimerSettings.shared.textColor))
                        .multilineTextAlignment(display.isDoneState ? .center : .leading)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: display.isDoneState ? .center : .leading)
                }
            }
        }
    }

    private func bottomSection(display: CalendarTimerDisplay) -> some View {
        VStack(spacing: 6) {
            if display.showsProgress {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(nsColor: CalendarTimerSettings.shared.trackColor))
                        Capsule()
                            .fill(display.tint)
                            .frame(width: proxy.size.width * display.progress)
                    }
                    .overlay(
                        Capsule()
                            .stroke(Color.black.opacity(0.18), lineWidth: 0.5)
                    )
                }
                .frame(height: 5)
            }

            HStack {
                Text(display.footerLeft)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Color(nsColor: CalendarTimerSettings.shared.accentColor))
                    .lineLimit(1)

                Spacer()

                Text(display.footerRight)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Color(nsColor: CalendarTimerSettings.shared.accentColor))
                    .lineLimit(1)
            }
            .frame(height: 14)
        }
    }

    private func markDoneButton(display: CalendarTimerDisplay) -> some View {
        Button {
            showingMarkDone.toggle()
        } label: {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color(nsColor: CalendarTimerSettings.shared.textColor).opacity(0.82))
                .frame(width: 20, height: 20)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.14), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingMarkDone, arrowEdge: .top) {
            CalendarTimerMarkDonePanel(
                eventTitle: display.title,
                remainingSeconds: display.remainingSeconds,
                onStartNext: { title in
                    Task {
                        await model.completeAndStartNew(title: title)
                        showingMarkDone = false
                    }
                },
                onJustEnd: {
                    Task {
                        await model.completeCurrent()
                        showingMarkDone = false
                    }
                },
                onCancel: {
                    showingMarkDone = false
                }
            )
        }
    }
}

private struct CalendarTimerGlassBackground: View {
    let opacity: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial.opacity(opacity))

            LinearGradient(
                colors: [
                    Color.white.opacity(0.22),
                    Color.white.opacity(0.06),
                    Color.white.opacity(0.12)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    Color.white.opacity(0.38),
                    Color.white.opacity(0.0)
                ],
                center: UnitPoint(x: 0.30, y: -0.05),
                startRadius: 0,
                endRadius: 220
            )
            .blendMode(.screen)

            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.71, blue: 0.86).opacity(0.10),
                    Color(red: 0.71, green: 0.86, blue: 1.0).opacity(0.0),
                    Color(red: 0.78, green: 1.0, blue: 0.90).opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

private struct CalendarTimerDisplay {
    enum Kind {
        case countdown(String)
        case message(String)
    }

    let title: String
    let kind: Kind
    let footerLeft: String
    let footerRight: String
    let progress: CGFloat
    let tint: Color
    let showsDot: Bool
    let showsProgress: Bool
    let shouldPulse: Bool
    let isDoneState: Bool
    let requiresAccessAction: Bool
    let remainingSeconds: TimeInterval
    let hasActiveEvent: Bool

    init(snapshot: CalendarTimerModel.Snapshot, now: Date) {
        let settings = CalendarTimerSettings.shared

        switch snapshot {
        case .loading:
            title = "Loading calendar"
            kind = .countdown("--:--:--")
            footerLeft = "Loading calendar..."
            footerRight = ""
            progress = 0
            tint = Color(nsColor: settings.accentColor)
            showsDot = false
            showsProgress = false
            shouldPulse = false
            isDoneState = false
            requiresAccessAction = false
            remainingSeconds = 0
            hasActiveEvent = false

        case .permissionRequired:
            title = "Calendar access required"
            kind = .message("Grant Access")
            footerLeft = ""
            footerRight = ""
            progress = 0
            tint = Color(nsColor: settings.midColor)
            showsDot = false
            showsProgress = false
            shouldPulse = false
            isDoneState = false
            requiresAccessAction = true
            remainingSeconds = 0
            hasActiveEvent = false

        case .denied:
            title = "Calendar access denied"
            kind = .message("Access denied")
            footerLeft = "Allow calendar access in System Settings."
            footerRight = ""
            progress = 0
            tint = Color(nsColor: settings.hotColor)
            showsDot = false
            showsProgress = false
            shouldPulse = false
            isDoneState = false
            requiresAccessAction = false
            remainingSeconds = 0
            hasActiveEvent = false

        case .idle:
            title = ""
            kind = .message("Done!")
            footerLeft = ""
            footerRight = ""
            progress = 0
            tint = Color(nsColor: settings.textColor)
            showsDot = false
            showsProgress = false
            shouldPulse = false
            isDoneState = true
            requiresAccessAction = false
            remainingSeconds = 0
            hasActiveEvent = false

        case .active(let event):
            let remaining = max(0, event.endDate.timeIntervalSince(now))
            let total = max(1, event.totalDuration)
            let fraction = max(0, min(1, remaining / total))
            let color = urgencyColor(frac: fraction, enabled: settings.urgencyEnabled)

            title = event.title
            kind = .countdown(Self.timeText(remaining))
            footerLeft = "ends \(event.endDate.formatted(date: .omitted, time: .shortened))"
            footerRight = "\(Int((fraction * 100).rounded()))%"
            progress = fraction
            tint = Color(nsColor: color)
            showsDot = true
            showsProgress = true
            shouldPulse = settings.urgencyEnabled && fraction <= settings.criticalThreshold
            isDoneState = false
            requiresAccessAction = false
            remainingSeconds = remaining
            hasActiveEvent = true
        }
    }

    private static func timeText(_ interval: TimeInterval) -> String {
        let totalSeconds = max(0, Int(interval.rounded(.down)))
        return String(
            format: "%02d:%02d:%02d",
            totalSeconds / 3600,
            (totalSeconds % 3600) / 60,
            totalSeconds % 60
        )
    }
}

private struct CalendarTimerSettingsPanel: View {
    @State private var opacity = CalendarTimerSettings.shared.bgOpacity
    @State private var urgencyEnabled = CalendarTimerSettings.shared.urgencyEnabled
    @State private var urgentThreshold = CalendarTimerSettings.shared.urgentThreshold
    @State private var criticalThreshold = CalendarTimerSettings.shared.criticalThreshold
    @State private var calmColor = Color(nsColor: CalendarTimerSettings.shared.calmColor)
    @State private var midColor = Color(nsColor: CalendarTimerSettings.shared.midColor)
    @State private var hotColor = Color(nsColor: CalendarTimerSettings.shared.hotColor)
    @State private var textColor = Color(nsColor: CalendarTimerSettings.shared.textColor)
    @State private var accentColor = Color(nsColor: CalendarTimerSettings.shared.accentColor)
    @State private var trackColor = Color(nsColor: CalendarTimerSettings.shared.trackColor)
    @State private var backgroundImageName = CalendarTimerSettings.shared.backgroundImageName

    let onChanged: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Timer settings")
                    .font(.system(size: 13, weight: .semibold))

                VStack(alignment: .leading, spacing: 6) {
                    settingsLabel("Background opacity")
                    Slider(value: $opacity, in: 0.3...1.0) { _ in
                        CalendarTimerSettings.shared.bgOpacity = opacity
                        onChanged()
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    settingsLabel("Background image")
                    HStack {
                        Button("Choose image…") {
                            chooseBackgroundImage()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button("Clear") {
                            CalendarTimerSettings.shared.backgroundImagePath = nil
                            backgroundImageName = CalendarTimerSettings.shared.backgroundImageName
                            onChanged()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(CalendarTimerSettings.shared.backgroundImagePath == nil)
                    }

                    Text(backgroundImageName)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Toggle("Urgency colors & pulse", isOn: $urgencyEnabled)
                    .font(.system(size: 12, weight: .medium))
                    .onChange(of: urgencyEnabled) { _, newValue in
                        CalendarTimerSettings.shared.urgencyEnabled = newValue
                        onChanged()
                    }

                VStack(alignment: .leading, spacing: 6) {
                    settingsLabel("Urgent color starts below")
                    Slider(value: $urgentThreshold, in: 0.05...0.75) { _ in
                        if urgentThreshold < criticalThreshold {
                            criticalThreshold = urgentThreshold
                            CalendarTimerSettings.shared.criticalThreshold = criticalThreshold
                        }
                        CalendarTimerSettings.shared.urgentThreshold = urgentThreshold
                        onChanged()
                    }
                    monoValue("\(Int(urgentThreshold * 100))%")
                }

                VStack(alignment: .leading, spacing: 6) {
                    settingsLabel("Critical + pulse starts below")
                    Slider(value: $criticalThreshold, in: 0.0...0.50) { _ in
                        if criticalThreshold > urgentThreshold {
                            urgentThreshold = criticalThreshold
                            CalendarTimerSettings.shared.urgentThreshold = urgentThreshold
                        }
                        CalendarTimerSettings.shared.criticalThreshold = criticalThreshold
                        onChanged()
                    }
                    monoValue("\(Int(criticalThreshold * 100))%")
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    settingsLabel("Text colors")
                    HStack {
                        colorWell("Text", selection: $textColor) {
                            CalendarTimerSettings.shared.textColor = NSColor(textColor)
                            onChanged()
                        }
                        colorWell("Accent", selection: $accentColor) {
                            CalendarTimerSettings.shared.accentColor = NSColor(accentColor)
                            onChanged()
                        }
                        colorWell("Track", selection: $trackColor) {
                            CalendarTimerSettings.shared.trackColor = NSColor(trackColor)
                            onChanged()
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    settingsLabel("Colors")
                    HStack {
                        colorWell("Calm", selection: $calmColor) {
                            CalendarTimerSettings.shared.calmColor = NSColor(calmColor)
                            onChanged()
                        }
                        colorWell("Urgent", selection: $midColor) {
                            CalendarTimerSettings.shared.midColor = NSColor(midColor)
                            onChanged()
                        }
                        colorWell("Critical", selection: $hotColor) {
                            CalendarTimerSettings.shared.hotColor = NSColor(hotColor)
                            onChanged()
                        }
                    }
                }

                Button("Reset thresholds & colors") {
                    CalendarTimerSettings.shared.resetColorsAndThresholds()
                    syncFromSettings()
                    onChanged()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(14)
        }
        .frame(width: 300, height: 460)
    }

    private func chooseBackgroundImage() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]
        NSApp.activate(ignoringOtherApps: true)
        let response = panel.runModal()
        guard response == .OK, let url = panel.url else { return }
        DispatchQueue.main.async {
            CalendarTimerSettings.shared.backgroundImagePath = url.path
            backgroundImageName = CalendarTimerSettings.shared.backgroundImageName
            onChanged()
        }
    }

    private func syncFromSettings() {
        opacity = CalendarTimerSettings.shared.bgOpacity
        urgencyEnabled = CalendarTimerSettings.shared.urgencyEnabled
        urgentThreshold = CalendarTimerSettings.shared.urgentThreshold
        criticalThreshold = CalendarTimerSettings.shared.criticalThreshold
        calmColor = Color(nsColor: CalendarTimerSettings.shared.calmColor)
        midColor = Color(nsColor: CalendarTimerSettings.shared.midColor)
        hotColor = Color(nsColor: CalendarTimerSettings.shared.hotColor)
        textColor = Color(nsColor: CalendarTimerSettings.shared.textColor)
        accentColor = Color(nsColor: CalendarTimerSettings.shared.accentColor)
        trackColor = Color(nsColor: CalendarTimerSettings.shared.trackColor)
        backgroundImageName = CalendarTimerSettings.shared.backgroundImageName
    }

    private func settingsLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
    }

    private func monoValue(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(.secondary)
    }

    private func colorWell(_ title: String, selection: Binding<Color>, onSet: @escaping () -> Void) -> some View {
        VStack(spacing: 4) {
            ColorPicker("", selection: selection, supportsOpacity: true)
                .labelsHidden()
                .onChange(of: selection.wrappedValue) { _, _ in
                    onSet()
                }
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct CalendarTimerMarkDonePanel: View {
    let eventTitle: String
    let remainingSeconds: TimeInterval
    let onStartNext: (String) -> Void
    let onJustEnd: () -> Void
    let onCancel: () -> Void

    @State private var nextTaskTitle = ""

    var body: some View {
        let forceNew = remainingSeconds > 300

        VStack(alignment: .leading, spacing: 12) {
            Text("Mark as done")
                .font(.system(size: 13, weight: .semibold))

            Text("\(eventTitle) — \(formattedDuration(remainingSeconds)) left")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(forceNew ? "Next task name (required — more than 5 min left)" : "Next task name")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            TextField("What's next?", text: $nextTaskTitle)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)

                Spacer()

                if !forceNew {
                    Button("Just end", action: onJustEnd)
                }

                Button("Start next task") {
                    let title = nextTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !title.isEmpty else { return }
                    onStartNext(title)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(nextTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .frame(width: 340)
    }

    private func formattedDuration(_ interval: TimeInterval) -> String {
        let value = max(0, Int(interval))
        let hours = value / 3600
        let minutes = (value % 3600) / 60
        let seconds = value % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%d:%02d", minutes, seconds)
    }
}

private final class CalendarTimerSettings {
    static let shared = CalendarTimerSettings()
    private let defaults = UserDefaults.standard

    private let kOpacity = "bgOpacity"
    private let kUrgency = "urgencyEnabled"
    private let kUrgentT = "urgentThreshold"
    private let kCritT = "criticalThreshold"
    private let kCalm = "calmColor"
    private let kMid = "midColor"
    private let kHot = "hotColor"
    private let kText = "textColor"
    private let kAccent = "accentColor"
    private let kTrack = "trackColor"
    private let kBgImage = "backgroundImagePath"

    static let dfOpacity: CGFloat = 0.94
    static let dfUrgent: Double = 0.25
    static let dfCrit: Double = 0.20
    static let dfCalm = NSColor(red: 0.25, green: 0.75, blue: 0.46, alpha: 1)
    static let dfMid = NSColor(red: 0.88, green: 0.72, blue: 0.16, alpha: 1)
    static let dfHot = NSColor(red: 0.87, green: 0.36, blue: 0.25, alpha: 1)
    static let dfText = NSColor.white
    static let dfAccent = NSColor(white: 1, alpha: 0.62)
    static let dfTrack = NSColor(white: 1, alpha: 0.14)

    var bgOpacity: CGFloat {
        get { (defaults.object(forKey: kOpacity) as? Double).map { CGFloat($0) } ?? Self.dfOpacity }
        set { defaults.set(Double(newValue), forKey: kOpacity) }
    }

    var urgencyEnabled: Bool {
        get { (defaults.object(forKey: kUrgency) as? Bool) ?? true }
        set { defaults.set(newValue, forKey: kUrgency) }
    }

    var urgentThreshold: Double {
        get { defaults.object(forKey: kUrgentT) as? Double ?? Self.dfUrgent }
        set { defaults.set(newValue, forKey: kUrgentT) }
    }

    var criticalThreshold: Double {
        get { defaults.object(forKey: kCritT) as? Double ?? Self.dfCrit }
        set { defaults.set(newValue, forKey: kCritT) }
    }

    var calmColor: NSColor {
        get { loadColor(kCalm) ?? Self.dfCalm }
        set { saveColor(newValue, key: kCalm) }
    }

    var midColor: NSColor {
        get { loadColor(kMid) ?? Self.dfMid }
        set { saveColor(newValue, key: kMid) }
    }

    var hotColor: NSColor {
        get { loadColor(kHot) ?? Self.dfHot }
        set { saveColor(newValue, key: kHot) }
    }

    var textColor: NSColor {
        get { loadColor(kText) ?? Self.dfText }
        set { saveColor(newValue, key: kText) }
    }

    var accentColor: NSColor {
        get { loadColor(kAccent) ?? Self.dfAccent }
        set { saveColor(newValue, key: kAccent) }
    }

    var trackColor: NSColor {
        get { loadColor(kTrack) ?? Self.dfTrack }
        set { saveColor(newValue, key: kTrack) }
    }

    var backgroundImagePath: String? {
        get { defaults.string(forKey: kBgImage) }
        set {
            if let newValue {
                defaults.set(newValue, forKey: kBgImage)
            } else {
                defaults.removeObject(forKey: kBgImage)
            }
        }
    }

    var backgroundImage: NSImage? {
        guard let backgroundImagePath else { return nil }
        return NSImage(contentsOfFile: backgroundImagePath)
    }

    var backgroundImageName: String {
        guard let backgroundImagePath else { return "No image" }
        return (backgroundImagePath as NSString).lastPathComponent
    }

    func resetColorsAndThresholds() {
        defaults.removeObject(forKey: kUrgentT)
        defaults.removeObject(forKey: kCritT)
        defaults.removeObject(forKey: kCalm)
        defaults.removeObject(forKey: kMid)
        defaults.removeObject(forKey: kHot)
        defaults.removeObject(forKey: kText)
        defaults.removeObject(forKey: kAccent)
        defaults.removeObject(forKey: kTrack)
    }

    private func loadColor(_ key: String) -> NSColor? {
        guard let values = defaults.array(forKey: key) as? [Double], values.count == 4 else {
            return nil
        }
        return NSColor(srgbRed: values[0], green: values[1], blue: values[2], alpha: values[3])
    }

    private func saveColor(_ color: NSColor, key: String) {
        let rgb = color.usingColorSpace(.sRGB) ?? color
        defaults.set(
            [
                Double(rgb.redComponent),
                Double(rgb.greenComponent),
                Double(rgb.blueComponent),
                Double(rgb.alphaComponent)
            ],
            forKey: key
        )
    }
}

private func urgencyColor(frac: Double, enabled: Bool) -> NSColor {
    if !enabled {
        return NSColor(white: 1.0, alpha: 0.55)
    }

    let settings = CalendarTimerSettings.shared
    if frac > settings.urgentThreshold {
        return settings.calmColor
    }
    if frac > settings.criticalThreshold {
        return settings.midColor
    }
    return settings.hotColor
}

@MainActor
@Observable
final class CalendarTimerModel {
    struct ActiveEvent {
        let title: String
        let endDate: Date
        let totalDuration: TimeInterval
    }

    enum Snapshot {
        case loading
        case permissionRequired
        case denied
        case idle
        case active(ActiveEvent)
    }

    private let store = EKEventStore()
    private var changeObserver: NSObjectProtocol?
    private(set) var snapshotState: Snapshot = .loading

    func activate() async {
        if changeObserver == nil {
            changeObserver = NotificationCenter.default.addObserver(
                forName: .EKEventStoreChanged,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    await self?.refresh()
                }
            }
        }

        await refresh()
    }

    func snapshot(at date: Date) -> Snapshot {
        switch snapshotState {
        case .loading, .permissionRequired, .denied:
            return snapshotState
        case .idle, .active:
            if let activeEvent = activeEvent(at: date) {
                return .active(activeEvent)
            }
            return .idle
        }
    }

    func requestAccess() async {
        do {
            if #available(macOS 14.0, *) {
                let granted = try await store.requestFullAccessToEvents()
                snapshotState = granted ? .loading : .denied
            } else {
                let granted = try await store.requestAccess(to: .event)
                snapshotState = granted ? .loading : .denied
            }
        } catch {
            snapshotState = .denied
        }

        await refresh()
    }

    func refresh() async {
        let status = EKEventStore.authorizationStatus(for: .event)

        switch status {
        case .fullAccess, .authorized:
            break
        case .notDetermined:
            snapshotState = .permissionRequired
            return
        default:
            snapshotState = .denied
            return
        }

        guard let activeEvent = activeEvent(at: Date()) else {
            snapshotState = .idle
            return
        }

        snapshotState = .active(activeEvent)
    }

    func completeCurrent() async {
        guard let event = currentEvent() else { return }
        event.endDate = Date()

        do {
            try store.save(event, span: .thisEvent)
        } catch {
            return
        }

        await refresh()
    }

    func completeAndStartNew(title: String) async {
        let nextTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nextTitle.isEmpty, let event = currentEvent() else { return }

        let now = Date()
        let originalEnd = event.endDate
        let calendar = store.defaultCalendarForNewEvents ?? event.calendar

        event.endDate = now

        do {
            try store.save(event, span: .thisEvent)

            let newEvent = EKEvent(eventStore: store)
            newEvent.title = nextTitle
            newEvent.startDate = now
            newEvent.endDate = originalEnd
            newEvent.calendar = calendar
            try store.save(newEvent, span: .thisEvent)
        } catch {
            return
        }

        await refresh()
    }

    private func currentEvent() -> EKEvent? {
        currentEvent(at: Date())
    }

    private func currentEvent(at date: Date) -> EKEvent? {
        let dayStart = Calendar.current.startOfDay(for: date)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? date.addingTimeInterval(86_400)
        let predicate = store.predicateForEvents(withStart: dayStart, end: dayEnd, calendars: nil)
        let maxDuration: TimeInterval = 10 * 60 * 60

        return store.events(matching: predicate)
            .filter {
                $0.startDate <= date &&
                $0.endDate > date &&
                $0.endDate.timeIntervalSince($0.startDate) <= maxDuration
            }
            .sorted { $0.endDate < $1.endDate }
            .first
    }

    private func activeEvent(at date: Date) -> ActiveEvent? {
        guard let event = currentEvent(at: date) else { return nil }
        return ActiveEvent(
            title: event.title?.isEmpty == false ? event.title! : "Untitled",
            endDate: event.endDate,
            totalDuration: event.endDate.timeIntervalSince(event.startDate)
        )
    }
}
