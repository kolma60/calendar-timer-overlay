//
//  WidgetView.swift
//  adaptive root
//
//  Each widget type renders its content inside the `widgetContent` switch below.
//  Replace the placeholder VStack for a given case with the real implementation.
//

import SwiftUI

struct WidgetView: View {
    let type: WidgetType
    let onClose: () -> Void
    @Bindable var state: WidgetViewState

    var body: some View {
        Group {
            if type == .calendarTimer {
                ZStack(alignment: .topTrailing) {
                    widgetContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    CloseButton(action: onClose)
                        .padding(.top, 12)
                        .padding(.trailing, 12)
                }
            } else {
                ZStack(alignment: .topTrailing) {
                    // Background
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                        )
                        .opacity(state.panelOpacity)

                    VStack(spacing: 0) {
                        // Drag handle / header
                        HStack {
                            Text(type.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Spacer()
                            CloseButton(action: onClose)
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 12)
                        .padding(.bottom, 8)

                        Divider().opacity(0.4)

                        // Widget-specific content — replace each placeholder here
                        widgetContent
                            .padding(14)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .popover(isPresented: $state.showingSettings, arrowEdge: .top) {
                    WidgetQuickSettingsPanel(
                        type: type,
                        panelOpacity: $state.panelOpacity,
                        onClose: onClose
                    )
                }
            }
        }
        .frame(width: type.defaultSize.width, height: type.defaultSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Per-widget content

    @ViewBuilder
    private var widgetContent: some View {
        switch type {
        case .clock:
            WidgetPlaceholder(icon: type.icon, label: "Clock coming soon")

        case .notes:
            WidgetPlaceholder(icon: type.icon, label: "Notes coming soon")

        case .weather:
            WidgetPlaceholder(icon: type.icon, label: "Weather coming soon")

        case .systemStats:
            WidgetPlaceholder(icon: type.icon, label: "System Stats coming soon")

        case .calendar:
            WidgetPlaceholder(icon: type.icon, label: "Calendar coming soon")

        case .calendarTimer:
            CalendarTimerWidget(showingSettings: $state.showingSettings)
        }
    }
}

@Observable
final class WidgetViewState {
    var showingSettings = false
    var panelOpacity = 1.0
}

// MARK: - Reusable placeholder (remove per widget when implementing the real thing)

private struct WidgetPlaceholder: View {
    let icon: String
    let label: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.secondary)
            Text(label)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct WidgetQuickSettingsPanel: View {
    let type: WidgetType
    @Binding var panelOpacity: Double
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("\(type.title) settings")
                .font(.system(size: 13, weight: .semibold))

            VStack(alignment: .leading, spacing: 6) {
                Text("Background transparency")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                Slider(value: $panelOpacity, in: 0.2...1.0)

                Text("\(Int((panelOpacity * 100).rounded()))% visible")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Button("Reset transparency") {
                panelOpacity = 1.0
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Divider()

            Button("Close widget", role: .destructive) {
                onClose()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(14)
        .frame(width: 240)
    }
}

// MARK: - Close button

private struct CloseButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(isHovered ? .primary : .secondary)
                .frame(width: 18, height: 18)
                .background(
                    Circle().fill(isHovered ? Color.secondary.opacity(0.25) : Color.secondary.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
