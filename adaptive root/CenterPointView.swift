//
//  CenterPointView.swift
//  adaptive root
//

import SwiftUI

struct CenterPointView: View {
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Slow outer halo
            Circle()
                .fill(Color(red: 0.88, green: 0.82, blue: 0.62).opacity(0.10))
                .scaleEffect(pulseScale)
                .animation(
                    .easeInOut(duration: 2.8).repeatForever(autoreverses: true),
                    value: pulseScale
                )

            // Mid glow ring
            Circle()
                .fill(Color(red: 0.88, green: 0.82, blue: 0.62).opacity(0.18))
                .frame(width: 18, height: 18)
                .blur(radius: 4)

            // Core orb
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0,  green: 0.97, blue: 0.82),
                            Color(red: 0.88, green: 0.80, blue: 0.55),
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 7
                    )
                )
                .frame(width: 10, height: 10)
        }
        .frame(width: 44, height: 44)
        .shadow(color: Color(red: 0.88, green: 0.82, blue: 0.62).opacity(0.55), radius: 12, x: 0, y: 0)
        .shadow(color: Color(red: 0.88, green: 0.82, blue: 0.62).opacity(0.25), radius: 24, x: 0, y: 0)
        .onAppear { pulseScale = 1.8 }
    }
}
