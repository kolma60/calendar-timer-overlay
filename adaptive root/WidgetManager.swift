//
//  WidgetManager.swift
//  adaptive root
//

import AppKit
import SwiftUI

@Observable
final class WidgetManager {
    static let shared = WidgetManager()

    // MARK: - State

    private(set) var activeWidgets: [UUID: WidgetType] = [:]
    private var panels: [UUID: NSPanel] = [:]

    var widgetPositions: [UUID: CGPoint] = [:]
    var centerPosition: CGPoint

    let rootSystem = RootSystem()

    // MARK: - Overlay

    private var overlayWindow: NSWindow?
    private var centerPanel: NSPanel?
    private var positionTimer: Timer?

    // MARK: - Init

    private init() {
        let s = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        centerPosition = CGPoint(x: s.midX, y: s.midY)
    }

    // MARK: - Public API

    func addWidget(_ type: WidgetType) {
        let id    = UUID()
        let panel = makeWidgetPanel(id: id, type: type)
        panels[id]       = panel
        activeWidgets[id] = type

        let offset = CGFloat(panels.count - 1) * 24
        panel.center()
        panel.setFrameOrigin(NSPoint(x: panel.frame.origin.x + offset,
                                     y: panel.frame.origin.y - offset))
        panel.makeKeyAndOrderFront(nil)

        ensureOverlayExists()
        startTracking()

        // Sync positions before rebuild so the new widget is included
        syncPositions()
        widgetPositions[id] = CGPoint(x: panel.frame.midX, y: panel.frame.midY)

        rootSystem.rebuild(center: centerPosition, widgets: widgetPositions)
    }

    func removeWidget(id: UUID) {
        guard panels[id] != nil else { return }

        positionTimer?.invalidate()
        positionTimer = nil

        panels[id]?.close()
        panels.removeValue(forKey: id)
        activeWidgets.removeValue(forKey: id)
        widgetPositions.removeValue(forKey: id)

        if panels.isEmpty {
            rootSystem.retractAll()
            tearDownOverlay()
        } else {
            startTracking()
            rootSystem.rebuild(center: centerPosition, widgets: widgetPositions)
        }
    }

    func refreshRootSystem() {
        guard !widgetPositions.isEmpty else { return }
        rootSystem.rebuild(center: centerPosition, widgets: widgetPositions)
    }

    // MARK: - Widget panel factory

    private func makeWidgetPanel(id: UUID, type: WidgetType) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: type.defaultSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level                    = .floating
        panel.isFloatingPanel          = true
        panel.isMovableByWindowBackground = true
        panel.backgroundColor          = .clear
        panel.isOpaque                 = false
        panel.hasShadow                = true
        panel.collectionBehavior       = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: WidgetView(type: type) { [weak self] in
            self?.removeWidget(id: id)
        })
        return panel
    }

    // MARK: - Overlay + centre-orb lifecycle

    private func ensureOverlayExists() {
        guard overlayWindow == nil else { return }
        let screen = NSScreen.main ?? NSScreen.screens[0]

        let overlay = NSWindow(contentRect: screen.frame, styleMask: .borderless,
                               backing: .buffered, defer: false)
        overlay.level              = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue - 1)
        overlay.backgroundColor    = .clear
        overlay.isOpaque           = false
        overlay.ignoresMouseEvents = true
        overlay.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        overlay.contentView = NSHostingView(rootView: LineOverlayView())
        overlay.orderFront(nil)
        overlayWindow = overlay

        let size: CGFloat = 44
        let cp = NSPanel(
            contentRect: NSRect(x: screen.frame.midX - size/2,
                                y: screen.frame.midY - size/2,
                                width: size, height: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        cp.level                    = .floating
        cp.isFloatingPanel          = true
        cp.isMovableByWindowBackground = true
        cp.backgroundColor          = .clear
        cp.isOpaque                 = false
        cp.hasShadow                = true
        cp.collectionBehavior       = [.canJoinAllSpaces, .fullScreenAuxiliary]
        cp.contentView = NSHostingView(rootView: CenterPointView())
        cp.makeKeyAndOrderFront(nil)
        centerPanel = cp
    }

    private func tearDownOverlay() {
        positionTimer?.invalidate()
        positionTimer = nil
        overlayWindow?.close()
        overlayWindow = nil
        centerPanel?.close()
        centerPanel = nil
        widgetPositions = [:]
    }

    // MARK: - 30 fps position tracking

    private func startTracking() {
        guard positionTimer == nil else { return }
        positionTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30, repeats: true) { [weak self] _ in
            self?.syncPositions()
        }
    }

    private func syncPositions() {
        guard !panels.isEmpty else {
            widgetPositions = [:]
            return
        }

        var positions: [UUID: CGPoint] = [:]
        for (id, panel) in panels {
            positions[id] = CGPoint(x: panel.frame.midX, y: panel.frame.midY)
        }
        let nextCenterPosition: CGPoint
        if let cp = centerPanel {
            nextCenterPosition = CGPoint(x: cp.frame.midX, y: cp.frame.midY)
        } else {
            nextCenterPosition = centerPosition
        }

        let positionsChanged = positions != widgetPositions
        let centerChanged = nextCenterPosition != centerPosition

        widgetPositions = positions
        centerPosition = nextCenterPosition

        if positionsChanged || centerChanged {
            rootSystem.rebuild(center: centerPosition, widgets: widgetPositions)
        } else {
            rootSystem.tickAnimations()
        }
    }
}
