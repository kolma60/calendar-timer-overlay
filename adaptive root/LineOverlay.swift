//
//  LineOverlay.swift
//  adaptive root
//
//  Renders the root network on a full-screen transparent canvas.
//  TimelineView drives it at the display refresh rate; all animation is pure math on `time`.
//
//  Tuning guide:
//    Root colour / glow     →  rootColor, layers in glowStroke()
//    Oscillation            →  NetworkSegment.controlPoints()  in RootSystem.swift
//    Thickness scaling      →  thickFactor formula below
//    Branch count / shape   →  BranchSpec.generate()           in RootSystem.swift
//    Pulse rate / speed     →  EnergyPulse, nextPulseAt range  in RootSystem.swift
//

import SwiftUI
import AppKit

struct LineOverlayView: View {
    private let manager = WidgetManager.shared

    var body: some View {
        TimelineView(.animation) { tl in
            let time = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let screen = NSScreen.main?.frame
                    ?? CGRect(x: 0, y: 0, width: size.width, height: size.height)

                // Draw segments back-to-front: trunks first so branches render on top
                let sorted = manager.rootSystem.segments.values
                    .sorted { $0.weight > $1.weight }

                for seg in sorted {
                    drawSegment(seg, ctx: ctx, time: time, screen: screen)
                }
                for (_, j) in manager.rootSystem.junctions {
                    drawJunction(j, ctx: ctx, time: time, screen: screen)
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Drawing

private extension LineOverlayView {

    static let rootColor  = Color(red: 0.88, green: 0.82, blue: 0.62)
    static let pulseColor = Color(red: 1.00, green: 0.97, blue: 0.88)

    // macOS screen coords (origin bottom-left, Y up) → Canvas (top-left, Y down)
    func s2c(_ p: CGPoint, screen: CGRect) -> CGPoint {
        CGPoint(x: p.x - screen.minX, y: screen.height - (p.y - screen.minY))
    }

    // MARK: Segment

    func drawSegment(_ seg: NetworkSegment, ctx: GraphicsContext,
                     time: Double, screen: CGRect) {
        let frac = seg.drawFraction(at: time)
        guard frac > 0.004 else { return }

        let p0 = s2c(seg.fromPos, screen: screen)
        let p3 = s2c(seg.toPos,   screen: screen)
        let (cs1, cs2) = seg.controlPoints(at: time)
        let p1 = s2c(cs1, screen: screen)
        let p2 = s2c(cs2, screen: screen)

        var full = Path()
        full.move(to: p0)
        full.addCurve(to: p3, control1: p1, control2: p2)
        let trimmed = full.trimmedPath(from: 0, to: frac)

        let breath = 0.82 + 0.18 * sin(time * 1.2 + seg.seed * 6.283)
        let fadeIn  = min(1.0, frac * 5.0)
        let alpha   = fadeIn * breath

        // Thickness and brightness scale with weight (trunk = thicker + brighter)
        let tf = 1.0 + 0.85 * log2(Double(max(1, seg.weight)))   // thickness factor
        let bf = 1.0 + 0.10 * log2(Double(max(1, seg.weight)))   // brightness factor

        glowStroke(trimmed, ctx: ctx, alpha: alpha, tf: CGFloat(tf), bf: bf)

        for branch in seg.microBranches {
            drawMicroBranch(branch, p0: p0, p1: p1, p2: p2, p3: p3,
                            pFrac: frac, seg: seg, ctx: ctx, time: time, alpha: alpha)
        }

        for pulse in seg.pulses {
            if let t = pulse.t(at: time), t < frac {
                drawPulse(at: bezierPoint(t, p0, p1, p2, p3), t: t, ctx: ctx, alpha: alpha)
            }
        }
    }

    // Six-layer glow: outer halo → tight glow → body → core → spine highlight
    func glowStroke(_ path: Path, ctx: GraphicsContext,
                    alpha: Double, tf: CGFloat, bf: Double) {
        let c = Self.rootColor
        let style: [(CGFloat, Double)] = [
            (28 * tf, 0.020 * bf),
            (14 * tf, 0.045 * bf),
            ( 6 * tf, 0.095 * bf),
            (2.5 * tf, 0.220 * bf),
            (1.3 * tf, 0.580 * bf),
            (0.5,      0.190 * bf),
        ]
        for (w, o) in style {
            ctx.stroke(path, with: .color(c.opacity(o * alpha)),
                       style: StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round))
        }
    }

    // MARK: Micro-branch

    func drawMicroBranch(_ b: BranchSpec,
                         p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint,
                         pFrac: Double, seg: NetworkSegment,
                         ctx: GraphicsContext, time: Double, alpha: Double) {
        guard pFrac > b.branchT + 0.02 else { return }
        let bFrac = min(1.0, (pFrac - b.branchT) / 0.25)
        guard bFrac > 0.005 else { return }

        let origin = bezierPoint(b.branchT, p0, p1, p2, p3)
        let tang   = bezierTangent(b.branchT, p0, p1, p2, p3)
        let perp   = CGPoint(x: -tang.y, y: tang.x)
        let dist   = hypot(p3.x - p0.x, p3.y - p0.y)
        let len    = dist * b.relLength
        let osc    = sin(time * 0.65 + seg.seed * 9.1 + b.bendSeed * 5.3) * len * 0.22

        let end = CGPoint(x: origin.x + perp.x * len * b.sideSign + tang.x * len * 0.35,
                          y: origin.y + perp.y * len * b.sideSign + tang.y * len * 0.35)
        let cp  = CGPoint(x: origin.x + perp.x * len * b.sideSign * 0.55 + tang.x * len * 0.5 + perp.x * osc,
                          y: origin.y + perp.y * len * b.sideSign * 0.55 + tang.y * len * 0.5 + perp.y * osc)

        var path = Path()
        path.move(to: origin)
        path.addQuadCurve(to: end, control: cp)
        let trimmed = path.trimmedPath(from: 0, to: bFrac)
        let ba = alpha * 0.55
        let c  = Self.rootColor
        ctx.stroke(trimmed, with: .color(c.opacity(0.06 * ba)), style: StrokeStyle(lineWidth: 7,   lineCap: .round))
        ctx.stroke(trimmed, with: .color(c.opacity(0.18 * ba)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        ctx.stroke(trimmed, with: .color(c.opacity(0.52 * ba)), style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
    }

    // MARK: Energy pulse

    func drawPulse(at pos: CGPoint, t: Double, ctx: GraphicsContext, alpha: Double) {
        let peak = max(0, 1.0 - abs(t - 0.5) * 1.6) * alpha
        let c    = Self.pulseColor
        ctx.fill(Path(ellipseIn: CGRect(x: pos.x-8,   y: pos.y-8,   width: 16, height: 16)), with: .color(c.opacity(0.06 * peak)))
        ctx.fill(Path(ellipseIn: CGRect(x: pos.x-3.5, y: pos.y-3.5, width:  7, height:  7)), with: .color(c.opacity(0.38 * peak)))
        ctx.fill(Path(ellipseIn: CGRect(x: pos.x-1.5, y: pos.y-1.5, width:  3, height:  3)), with: .color(c.opacity(0.92 * peak)))
    }

    // MARK: Junction node

    func drawJunction(_ j: JunctionNode, ctx: GraphicsContext,
                      time: Double, screen: CGRect) {
        let a = j.alpha(at: time)
        guard a > 0.005 else { return }
        let pos = s2c(j.position, screen: screen)
        let c   = Self.rootColor

        switch j.kind {
        case .branch:
            // Subtle ambient node where the network branches
            ctx.fill(Path(ellipseIn: CGRect(x: pos.x-9,   y: pos.y-9,   width: 18, height: 18)), with: .color(c.opacity(0.07 * a)))
            ctx.fill(Path(ellipseIn: CGRect(x: pos.x-3,   y: pos.y-3,   width:  6, height:  6)), with: .color(c.opacity(0.28 * a)))
            ctx.fill(Path(ellipseIn: CGRect(x: pos.x-1.2, y: pos.y-1.2, width:2.4, height:2.4)), with: .color(c.opacity(0.72 * a)))

        case .crossing:
            // More prominent node where independent paths intersect
            let pulse = 0.80 + 0.20 * sin(time * 2.1 + j.seed * 6.283)
            ctx.fill(Path(ellipseIn: CGRect(x: pos.x-13, y: pos.y-13, width: 26, height: 26)), with: .color(c.opacity(0.05 * a * pulse)))
            ctx.fill(Path(ellipseIn: CGRect(x: pos.x-5,  y: pos.y-5,  width: 10, height: 10)), with: .color(c.opacity(0.18 * a)))
            ctx.fill(Path(ellipseIn: CGRect(x: pos.x-2,  y: pos.y-2,  width:  4, height:  4)), with: .color(Color.white.opacity(0.55 * a)))

        case .pathJoint:
            // Tiny knot riding along the segment — most subtle, breathes slowly
            let breathe = 0.75 + 0.25 * sin(time * 1.6 + j.seed * 6.283)
            ctx.fill(Path(ellipseIn: CGRect(x: pos.x-5,   y: pos.y-5,   width: 10,  height: 10)),  with: .color(c.opacity(0.06 * a * breathe)))
            ctx.fill(Path(ellipseIn: CGRect(x: pos.x-1.8, y: pos.y-1.8, width:  3.6, height: 3.6)), with: .color(c.opacity(0.22 * a)))
            ctx.fill(Path(ellipseIn: CGRect(x: pos.x-0.8, y: pos.y-0.8, width:  1.6, height: 1.6)), with: .color(c.opacity(0.58 * a)))
        }
    }
}
