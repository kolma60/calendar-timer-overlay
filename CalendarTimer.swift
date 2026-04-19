import Cocoa
import EventKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var label: NSTextField!
    var store = EKEventStore()
    var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        requestCalendarAccess()
    }

    func requestCalendarAccess() {
        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents { granted, error in
                DispatchQueue.main.async {
                    if granted { self.setupUI() }
                    else { self.showError("Calendar access denied") }
                }
            }
        } else {
            store.requestAccess(to: .event) { granted, error in
                DispatchQueue.main.async {
                    if granted { self.setupUI() }
                    else { self.showError("Calendar access denied") }
                }
            }
        }
    }

    func setupUI() {
        let screen = NSScreen.main!.frame
        let w: CGFloat = 340
        let h: CGFloat = 90
        let x = screen.width - w - 20
        let y: CGFloat = 20

        window = NSWindow(
            contentRect: NSRect(x: x, y: y, width: w, height: h),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.backgroundColor = NSColor(white: 0.08, alpha: 0.88)
        window.isOpaque = false
        window.hasShadow = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.isMovableByWindowBackground = true

        // Rounded corners via layer
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.cornerRadius = 14
        window.contentView?.layer?.masksToBounds = true

        let stack = NSStackView(frame: NSRect(x: 0, y: 0, width: w, height: h))
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 4
        stack.edgeInsets = NSEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)

        let eventLabel = NSTextField(labelWithString: "")
        eventLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        eventLabel.textColor = NSColor(white: 0.7, alpha: 1)
        eventLabel.alignment = .center
        eventLabel.maximumNumberOfLines = 1
        eventLabel.lineBreakMode = .byTruncatingTail
        eventLabel.tag = 1

        label = NSTextField(labelWithString: "--:--:--")
        label.font = NSFont.monospacedDigitSystemFont(ofSize: 36, weight: .bold)
        label.textColor = .white
        label.alignment = .center

        stack.addArrangedSubview(eventLabel)
        stack.addArrangedSubview(label)
        window.contentView?.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor),
            stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor),
            stack.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor),
        ])

        window.makeKeyAndOrderFront(nil)

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        tick()
    }

    func tick() {
        let now = Date()
        let end = Date(timeIntervalSinceNow: 86400)
        let predicate = store.predicateForEvents(withStart: now, end: end, calendars: nil)
        let events = store.events(matching: predicate)

        // Find the current ongoing event (started before now, ends after now)
        let current = events
            .filter { $0.startDate <= now && $0.endDate > now }
            .sorted { $0.endDate < $1.endDate }
            .first

        if let event = current {
            let remaining = event.endDate.timeIntervalSince(now)
            let h = Int(remaining) / 3600
            let m = (Int(remaining) % 3600) / 60
            let s = Int(remaining) % 60
            label.stringValue = String(format: "%02d:%02d:%02d", h, m, s)

            // Color shifts red as event nears its end
            if remaining < 60 {
                label.textColor = NSColor.systemRed
            } else if remaining < 300 {
                label.textColor = NSColor.systemOrange
            } else {
                label.textColor = .white
            }

            if let eventLabel = window.contentView?.viewWithTag(1) as? NSTextField {
                eventLabel.stringValue = event.title ?? "Untitled Event"
            }
        } else {
            // Look for next upcoming event today
            let upcoming = events
                .filter { $0.startDate > now }
                .sorted { $0.startDate < $1.startDate }
                .first

            if let next = upcoming {
                let wait = next.startDate.timeIntervalSince(now)
                let h = Int(wait) / 3600
                let m = (Int(wait) % 3600) / 60
                let s = Int(wait) % 60
                label.stringValue = String(format: "%02d:%02d:%02d", h, m, s)
                label.textColor = NSColor(white: 0.5, alpha: 1)
                if let eventLabel = window.contentView?.viewWithTag(1) as? NSTextField {
                    eventLabel.stringValue = "Next: \(next.title ?? "Untitled")"
                }
            } else {
                label.stringValue = "--:--:--"
                label.textColor = NSColor(white: 0.5, alpha: 1)
                if let eventLabel = window.contentView?.viewWithTag(1) as? NSTextField {
                    eventLabel.stringValue = "No upcoming events"
                }
            }
        }
    }

    func showError(_ msg: String) {
        let alert = NSAlert()
        alert.messageText = "Calendar Timer"
        alert.informativeText = msg
        alert.runModal()
        NSApp.terminate(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)  // No dock icon
let delegate = AppDelegate()
app.delegate = delegate
app.run()
