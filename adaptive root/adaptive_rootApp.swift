//
//  adaptive_rootApp.swift
//  adaptive root
//
//  Created by karl olma on 21/04/2026.
//

import SwiftUI

@main
struct adaptive_rootApp: App {
    var body: some Scene {
        MenuBarExtra {
            ContentView()
        } label: {
            Image(systemName: "circle.hexagongrid.fill")
        }
        .menuBarExtraStyle(.window)
    }
}
