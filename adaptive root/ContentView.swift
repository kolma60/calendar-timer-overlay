//
//  ContentView.swift
//  adaptive root
//

import SwiftUI

struct ContentView: View {
    @State private var showingWidgetPicker = false
    @State private var showingSettings = false
    private let debugSettings = RootDebugSettings.shared
    private let manager = WidgetManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "circle.hexagongrid.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.tint)
                Text("adaptive root")
                    .font(.headline)
            }
            .padding(.top, 20)
            .padding(.bottom, 14)

            Divider()

            // Widgets section
            VStack(spacing: 4) {
                SectionLabel("Widgets")

                MenuRowButton(label: "Add Widget", icon: "plus.rectangle.on.rectangle") {
                    showingWidgetPicker.toggle()
                }

                if showingWidgetPicker {
                    WidgetPicker()
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(.easeInOut(duration: 0.18), value: showingWidgetPicker)
            .padding(.vertical, 8)

            Divider()

            // App controls
            VStack(spacing: 4) {
                MenuRowButton(label: "Settings", icon: "gearshape") {
                    showingSettings.toggle()
                }
                if showingSettings {
                    RootSettingsPanel(settings: debugSettings)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                MenuRowButton(label: "About", icon: "info.circle") { }
            }
            .animation(.easeInOut(duration: 0.18), value: showingSettings)
            .padding(.vertical, 8)

            Divider()

            MenuRowButton(label: "Quit", icon: "power") {
                NSApplication.shared.terminate(nil)
            }
            .padding(.vertical, 8)
        }
        .frame(width: 240)
        .onChange(of: debugSettings.maxBranchAngleDegrees) { _, _ in manager.refreshRootSystem() }
        .onChange(of: debugSettings.minJunctionDistanceFactor) { _, _ in manager.refreshRootSystem() }
        .onChange(of: debugSettings.maxJunctionDistanceFactor) { _, _ in manager.refreshRootSystem() }
        .onChange(of: debugSettings.candidateAngleSweepDegrees) { _, _ in manager.refreshRootSystem() }
        .onChange(of: debugSettings.candidateDepthSweepFactor) { _, _ in manager.refreshRootSystem() }
        .onChange(of: debugSettings.siblingAngleWeight) { _, _ in manager.refreshRootSystem() }
        .onChange(of: debugSettings.edgeClearanceWeight) { _, _ in manager.refreshRootSystem() }
        .onChange(of: debugSettings.pathClearanceWeight) { _, _ in manager.refreshRootSystem() }
        .onChange(of: debugSettings.nodeClearanceWeight) { _, _ in manager.refreshRootSystem() }
    }
}

// MARK: - Widget picker (inline, expands below the "Add Widget" row)

private struct WidgetPicker: View {
    private let manager = WidgetManager.shared

    var body: some View {
        VStack(spacing: 2) {
            ForEach(WidgetType.allCases) { type in
                MenuRowButton(label: type.title, icon: type.icon, indent: true) {
                    manager.addWidget(type)
                }
            }
        }
        .padding(.top, 2)
    }
}

private struct RootSettingsPanel: View {
    @Bindable var settings: RootDebugSettings

    var body: some View {
        VStack(spacing: 8) {
            SettingsSliderRow(
                label: "Junction Angle",
                value: $settings.maxBranchAngleDegrees,
                range: 8...65,
                format: "%.0f deg"
            )
            SettingsSliderRow(
                label: "Junction Min Dist",
                value: $settings.minJunctionDistanceFactor,
                range: 0.10...0.60,
                format: "%.2f"
            )
            SettingsSliderRow(
                label: "Junction Max Dist",
                value: $settings.maxJunctionDistanceFactor,
                range: 0.35...1.10,
                format: "%.2f"
            )
            SettingsSliderRow(
                label: "Angle Sweep",
                value: $settings.candidateAngleSweepDegrees,
                range: 0...30,
                format: "%.0f deg"
            )
            SettingsSliderRow(
                label: "Depth Sweep",
                value: $settings.candidateDepthSweepFactor,
                range: 0...0.30,
                format: "%.2f"
            )
            SettingsSliderRow(
                label: "Sibling Weight",
                value: $settings.siblingAngleWeight,
                range: 0...220,
                format: "%.0f"
            )
            SettingsSliderRow(
                label: "Edge Weight",
                value: $settings.edgeClearanceWeight,
                range: 0...1.20,
                format: "%.2f"
            )
            SettingsSliderRow(
                label: "Path Weight",
                value: $settings.pathClearanceWeight,
                range: 0...1.20,
                format: "%.2f"
            )
            SettingsSliderRow(
                label: "Node Weight",
                value: $settings.nodeClearanceWeight,
                range: 0...1.20,
                format: "%.2f"
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

// MARK: - Shared sub-views

private struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        HStack {
            Text(text.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 20)
            Spacer()
        }
        .padding(.bottom, 2)
    }
}

struct MenuRowButton: View {
    let label: String
    let icon: String
    var indent: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if indent {
                    Spacer().frame(width: 8)
                }
                Image(systemName: icon)
                    .frame(width: 16)
                    .foregroundStyle(indent ? .secondary : .primary)
                Text(label)
                    .foregroundStyle(indent ? .secondary : .primary)
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isHovered ? Color.accentColor.opacity(0.15) : .clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .onHover { isHovered = $0 }
    }
}

private struct SettingsSliderRow: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let format: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: format, value))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary)
            }

            Slider(value: $value, in: range)
                .controlSize(.small)
        }
    }
}
