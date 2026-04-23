//
//  WidgetType.swift
//  adaptive root
//
//  To add a new widget: add a case here and a matching case in WidgetView.swift.
//

import Foundation
import CoreGraphics

enum WidgetType: String, CaseIterable, Identifiable {
    case clock
    case notes
    case weather
    case systemStats
    case calendar
    case calendarTimer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clock:       "Clock"
        case .notes:       "Notes"
        case .weather:     "Weather"
        case .systemStats: "System Stats"
        case .calendar:    "Calendar"
        case .calendarTimer: "CalendarTimer"
        }
    }

    var icon: String {
        switch self {
        case .clock:       "clock"
        case .notes:       "note.text"
        case .weather:     "cloud.sun"
        case .systemStats: "cpu"
        case .calendar:    "calendar"
        case .calendarTimer: "timer"
        }
    }

    var defaultSize: CGSize {
        switch self {
        case .clock:       CGSize(width: 200, height: 200)
        case .notes:       CGSize(width: 280, height: 320)
        case .weather:     CGSize(width: 240, height: 260)
        case .systemStats: CGSize(width: 220, height: 260)
        case .calendar:    CGSize(width: 280, height: 300)
        case .calendarTimer: CGSize(width: 300, height: 130)
        }
    }
}
