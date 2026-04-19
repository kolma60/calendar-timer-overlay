#!/bin/bash
cd "$(dirname "$0")"
swiftc CalendarTimer.swift -o CalendarTimer -framework Cocoa -framework EventKit && ./CalendarTimer
