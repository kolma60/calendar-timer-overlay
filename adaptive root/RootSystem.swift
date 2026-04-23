//
//  RootSystem.swift
//  adaptive root
//
//  Topology (recomputed every tick — dragging rewires the tree live):
//    • Widgets that are closer to each other than to the centre cluster together
//      (transitive union-find).
//    • Each cluster grows a binary branching tree — one trunk from centre to the
//      first split, then each node splits into two sub-branches, each sub-branch
//      splits again, and so on until every terminal reaches one widget.
//      This mirrors natural root / tree branching (thick trunk → progressively
//      thinner forks → fine terminal roots).
//    • Every split-node is placed along the angle-bisector of its sub-group's
//      widgets from the parent split, at a stable random depth (30–70 %).
//    • Segment diffing keeps animation state for unchanged edges.
//    • Path-joint knots slide along every segment.
//

import Foundation
import CoreGraphics

// MARK: - Geometry utilities (shared with LineOverlay)

func bezierPoint(_ t: Double, _ p0: CGPoint, _ p1: CGPoint,
                 _ p2: CGPoint, _ p3: CGPoint) -> CGPoint {
    let u = 1 - t
    return CGPoint(
        x: u*u*u*p0.x + 3*u*u*t*p1.x + 3*u*t*t*p2.x + t*t*t*p3.x,
        y: u*u*u*p0.y + 3*u*u*t*p1.y + 3*u*t*t*p2.y + t*t*t*p3.y
    )
}

func bezierTangent(_ t: Double, _ p0: CGPoint, _ p1: CGPoint,
                   _ p2: CGPoint, _ p3: CGPoint) -> CGPoint {
    let u  = 1 - t
    let dx = 3*(u*u*(p1.x-p0.x) + 2*u*t*(p2.x-p1.x) + t*t*(p3.x-p2.x))
    let dy = 3*(u*u*(p1.y-p0.y) + 2*u*t*(p2.y-p1.y) + t*t*(p3.y-p2.y))
    let L  = max(1e-6, hypot(dx, dy))
    return CGPoint(x: dx/L, y: dy/L)
}

// MARK: - Energy pulse

struct EnergyPulse: Identifiable {
    let id = UUID()
    let startTime: TimeInterval
    let speed: Double

    func t(at time: TimeInterval) -> Double? {
        let v = (time - startTime) * speed
        return v < 1.0 ? v : nil
    }
}

// MARK: - Micro-branch decoration on terminal segments

struct BranchSpec {
    let branchT: Double
    let sideSign: Double
    let relLength: Double
    let bendSeed: Double

    static func generate(seed: Double, weight: Int) -> [BranchSpec] {
        guard weight <= 2 else { return [] }
        func h(_ x: Double) -> Double { x.truncatingRemainder(dividingBy: 1.0) }
        var out: [BranchSpec] = []
        let s1 = h(seed * 73.13)
        out.append(BranchSpec(branchT: 0.28 + s1 * 0.30, sideSign: s1 < 0.5 ? 1 : -1,
                              relLength: 0.08 + h(seed * 37.19) * 0.16, bendSeed: h(seed * 19.71)))
        if weight == 1 && seed > 0.42 {
            let s2 = h(seed * 53.91)
            out.append(BranchSpec(branchT: 0.56 + s2 * 0.20, sideSign: s2 < 0.5 ? -1 : 1,
                                  relLength: 0.05 + h(seed * 41.37) * 0.10, bendSeed: h(seed * 29.53)))
        }
        if weight == 1 && seed > 0.72 {
            let s3 = h(seed * 61.77)
            out.append(BranchSpec(branchT: 0.74 + s3 * 0.14, sideSign: s3 < 0.5 ? 1 : -1,
                                  relLength: 0.04 + h(seed * 23.43) * 0.07, bendSeed: h(seed * 47.11)))
        }
        return out
    }
}

// MARK: - Network segment

struct NetworkSegment: Identifiable {
    let id: UUID
    let fromNodeID: UUID
    let toNodeID: UUID
    var isMainPath: Bool
    var fromPos: CGPoint
    var toPos: CGPoint
    var weight: Int
    let seed: Double
    let createdAt: TimeInterval
    var retractStartedAt: TimeInterval? = nil
    var pulses: [EnergyPulse] = []
    var nextPulseAt: TimeInterval
    let microBranches: [BranchSpec]

    func drawFraction(at time: TimeInterval) -> Double {
        let raw = min(1.0, max(0, (time - createdAt) / 1.4))
        let grow = raw < 0.5 ? 2*raw*raw : 1 - pow(-2*raw + 2, 2) / 2
        guard let rs = retractStartedAt else { return grow }
        let rawR = min(1.0, max(0, (time - rs) / 0.55))
        return grow * (1.0 - rawR * rawR)
    }

    func controlPoints(at time: TimeInterval) -> (CGPoint, CGPoint) {
        let dx   = toPos.x - fromPos.x
        let dy   = toPos.y - fromPos.y
        let dist = max(1.0, hypot(dx, dy))
        if isMainPath {
            return (
                CGPoint(x: fromPos.x + dx * 0.33, y: fromPos.y + dy * 0.33),
                CGPoint(x: fromPos.x + dx * 0.67, y: fromPos.y + dy * 0.67)
            )
        }
        let nx   = -dy / dist
        let ny   =  dx / dist
        let wf   = log2(Double(max(1, weight)))

        let baseDisp = dist * 0.22 * (1.0 + 0.38 * wf)
        let oscAmp   = baseDisp / (1.0 + 0.45 * wf) * 0.5
        let oscSpeed = 0.55 / (1.0 + 0.28 * wf)

        let osc1 = oscAmp * sin(time * oscSpeed        + seed * 6.283)
        let osc2 = oscAmp * sin(time * oscSpeed * 0.73 + seed * 4.712 + 1.1)
        let sk1  = dist * 0.07 * sin(seed * 11.1)
        let sk2  = dist * 0.06 * cos(seed *  9.3)

        return (
            CGPoint(x: fromPos.x + dx * 0.31 + nx * (osc1 + sk1),
                    y: fromPos.y + dy * 0.31 + ny * (osc1 + sk1)),
            CGPoint(x: fromPos.x + dx * 0.69 + nx * (osc2 + sk2),
                    y: fromPos.y + dy * 0.69 + ny * (osc2 + sk2))
        )
    }
}

// MARK: - Junction node

struct JunctionNode: Identifiable {
    enum Kind { case branch, crossing, pathJoint }
    let id: UUID
    var position: CGPoint
    let kind: Kind
    let seed: Double
    let createdAt: TimeInterval
    var retractStartedAt: TimeInterval? = nil

    func alpha(at time: TimeInterval) -> Double {
        let fadeIn = min(1.0, (time - createdAt) / 0.5)
        guard let rs = retractStartedAt else { return fadeIn }
        return fadeIn * max(0, 1.0 - min(1.0, (time - rs) / 0.4))
    }
}

// MARK: - Observable root system

@Observable
final class RootSystem {
    private struct TreeNodeKey: Hashable {
        let ids: [UUID]

        init(_ ids: [UUID]) {
            self.ids = ids.sorted { $0.uuidString < $1.uuidString }
        }
    }

    private struct PlannedEdge {
        let fromNodeID: UUID
        let toNodeID: UUID
        let fromPos: CGPoint
        let toPos: CGPoint
    }

    private let debugSettings = RootDebugSettings.shared

    let centerNodeID = UUID()

    var segments:  [UUID: NetworkSegment] = [:]
    var junctions: [UUID: JunctionNode]   = [:]

    // Stable UUID per sorted widget-subset — same widgets always → same node UUID
    private var treeNodeIDs:          [TreeNodeKey: UUID] = [:]
    private var activeJunctionNodeIDs: Set<UUID>     = []

    private struct PathJointLink {
        let junctionID: UUID
        let segmentID:  UUID
        let t: Double
    }
    private var pathJointLinks: [PathJointLink] = []

    // MARK: - Public API

    func rebuild(center: CGPoint, widgets: [UUID: CGPoint]) {
        syncTopology(center: center, widgets: widgets,
                     time: Date().timeIntervalSinceReferenceDate)
    }

    func retractAll() {
        let t = Date().timeIntervalSinceReferenceDate
        for id in segments.keys  { segments[id]?.retractStartedAt  = t }
        for id in junctions.keys { junctions[id]?.retractStartedAt = t }
        pathJointLinks        = []
        activeJunctionNodeIDs = []
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            self?.segments  = [:]
            self?.junctions = [:]
        }
    }

    func tick(positions: [UUID: CGPoint], center: CGPoint) {
        guard !positions.isEmpty else { return }
        let time = Date().timeIntervalSinceReferenceDate
        syncTopology(center: center, widgets: positions, time: time)
        tickPulses(time: time)
    }

    func tickAnimations() {
        guard !segments.isEmpty else { return }
        tickPulses(time: Date().timeIntervalSinceReferenceDate)
    }

    // MARK: - Core sync

    private func syncTopology(center: CGPoint, widgets: [UUID: CGPoint],
                               time: TimeInterval) {
        let groups = computeGroups(center: center, widgets: widgets)

        // Build node positions and segment specs together via the recursive tree
        var nodePos: [UUID: CGPoint] = [centerNodeID: center]
        nodePos.merge(widgets) { _, w in w }
        var specs: [Spec] = []
        var plannedEdges: [PlannedEdge] = []
        var outgoingDirections: [UUID: [CGPoint]] = [:]

        for group in groups {
            let groupTrunkWidgetID = furthestWidgetID(from: center, ids: group, widgets: widgets)
            if group.count == 1 {
                specs.append(Spec(fromID: centerNodeID, toID: group[0],
                                  weight: 1, level: 0, isMainPath: true))
                registerPlannedEdge(
                    fromNodeID: centerNodeID,
                    toNodeID: group[0],
                    nodePos: nodePos,
                    plannedEdges: &plannedEdges,
                    outgoingDirections: &outgoingDirections
                )
            } else {
                // Root split node for this cluster
                let jid  = treeNodeID(for: group)
                let jPos = splitNodePos(from: center, widgetIDs: group, widgets: widgets,
                                        center: center,
                                        trunkWidgetID: groupTrunkWidgetID,
                                        lockToSpine: true,
                                        spine: nil, parentNodeID: centerNodeID,
                                        occupiedNodes: nodePos,
                                        plannedEdges: plannedEdges,
                                        outgoingDirections: outgoingDirections)
                nodePos[jid] = jPos
                specs.append(Spec(fromID: centerNodeID, toID: jid,
                                  weight: group.count, level: 0, isMainPath: true))
                registerPlannedEdge(
                    fromNodeID: centerNodeID,
                    toNodeID: jid,
                    nodePos: nodePos,
                    plannedEdges: &plannedEdges,
                    outgoingDirections: &outgoingDirections
                )
                // Initial spine direction: centre → cluster root
                let sdx = jPos.x - center.x, sdy = jPos.y - center.y
                let sdl = max(1e-6, hypot(sdx, sdy))
                let spineDir = CGPoint(x: sdx / sdl, y: sdy / sdl)
                buildSubTree(parentID: jid, parentPos: jPos,
                             widgetIDs: group, widgets: widgets,
                             center: center,
                             trunkWidgetID: groupTrunkWidgetID,
                             spineDir: spineDir,
                             level: 1, nodePos: &nodePos, specs: &specs,
                             plannedEdges: &plannedEdges,
                             outgoingDirections: &outgoingDirections)
            }
        }

        // All UUIDs in nodePos that aren't the centre or a widget → junction nodes
        let widgetSet    = Set(widgets.keys)
        let junctionIDs  = Set(nodePos.keys).subtracting([centerNodeID]).subtracting(widgetSet)

        let newSegIDs = syncSegments(specs: specs, nodePos: nodePos, time: time)
        syncJunctions(ids: junctionIDs, nodePos: nodePos, time: time)

        for id in Array(segments.keys) {
            guard let seg = segments[id] else { continue }
            segments[id]?.fromPos = nodePos[seg.fromNodeID] ?? seg.fromPos
            segments[id]?.toPos   = nodePos[seg.toNodeID]   ?? seg.toPos
        }

        if !newSegIDs.isEmpty { addPathJoints(for: newSegIDs, time: time) }
        updatePathJoints(time: time)
    }

    // MARK: - Clustering

    private func computeGroups(center: CGPoint,
                                widgets: [UUID: CGPoint]) -> [[UUID]] {
        let ids = Array(widgets.keys)
        guard ids.count > 1 else { return ids.map { [$0] } }

        var parent = Dictionary(uniqueKeysWithValues: ids.map { ($0, $0) })
        func find(_ x: UUID) -> UUID {
            guard parent[x] != x else { return x }
            parent[x] = find(parent[x]!)
            return parent[x]!
        }

        for i in 0..<ids.count {
            let a = ids[i]; let pa = widgets[a]!
            let da = hypot(pa.x - center.x, pa.y - center.y)
            for j in (i+1)..<ids.count {
                let b = ids[j]; let pb = widgets[b]!
                let db  = hypot(pb.x - center.x, pb.y - center.y)
                let dab = hypot(pa.x - pb.x, pa.y - pb.y)
                if dab < da && dab < db {
                    let ra = find(a), rb = find(b)
                    if ra != rb { parent[ra] = rb }
                }
            }
        }

        var map: [UUID: [UUID]] = [:]
        for id in ids { map[find(id), default: []].append(id) }
        return Array(map.values)
    }

    // MARK: - Binary tree builder

    /// Recursively split `widgetIDs` in half, clamping each branch direction to
    /// at most `maxBranchAngle` away from `spineDir` so forks stay sharp.
    private func buildSubTree(parentID: UUID, parentPos: CGPoint,
                               widgetIDs: [UUID], widgets: [UUID: CGPoint],
                               center: CGPoint,
                               trunkWidgetID: UUID?,
                               spineDir: CGPoint,
                               level: Int,
                               nodePos: inout [UUID: CGPoint],
                               specs: inout [Spec],
                               plannedEdges: inout [PlannedEdge],
                               outgoingDirections: inout [UUID: [CGPoint]]) {
        guard !widgetIDs.isEmpty else { return }

        if widgetIDs.count == 1 {
            specs.append(Spec(fromID: parentID, toID: widgetIDs[0],
                              weight: 1, level: level, isMainPath: widgetIDs[0] == trunkWidgetID))
            return
        }

        // Sort by angle from parent so the two halves fan to opposite sides
        let sorted = widgetIDs.sorted {
            let pa = widgets[$0]!, pb = widgets[$1]!
            return atan2(Double(pa.y - parentPos.y), Double(pa.x - parentPos.x)) <
                   atan2(Double(pb.y - parentPos.y), Double(pb.x - parentPos.x))
        }

        let mid    = sorted.count / 2
        let anchorWidgetID = trunkWidgetID ?? furthestWidgetID(from: center, ids: widgetIDs, widgets: widgets)
        let rawHalves = [Array(sorted[..<mid]), Array(sorted[mid...])]
        let halves = rawHalves.sorted { lhs, rhs in
            let lhsContainsMain = anchorWidgetID.map(lhs.contains) ?? false
            let rhsContainsMain = anchorWidgetID.map(rhs.contains) ?? false
            if lhsContainsMain == rhsContainsMain { return false }
            return lhsContainsMain && !rhsContainsMain
        }

        for (index, half) in halves.enumerated() where !half.isEmpty {
            // Natural bisector direction from parent toward this half's widgets
            let naturalDir = bisectorDir(from: parentPos, ids: half, widgets: widgets)
            let isPrimaryHalf = index == 0 && (anchorWidgetID.map(half.contains) ?? false)
            let branchDir = isPrimaryHalf
                ? mainPathDirection(from: parentPos, center: center, anchorWidgetID: anchorWidgetID, widgets: widgets)
                : clampAngle(naturalDir, to: spineDir, max: maxBranchAngle)
            let childTrunkWidgetID = isPrimaryHalf ? anchorWidgetID : furthestWidgetID(from: center, ids: half, widgets: widgets)

            if half.count == 1 {
                specs.append(Spec(fromID: parentID, toID: half[0],
                                  weight: 1, level: level, isMainPath: isPrimaryHalf))
                registerPlannedEdge(
                    fromNodeID: parentID,
                    toNodeID: half[0],
                    nodePos: nodePos,
                    plannedEdges: &plannedEdges,
                    outgoingDirections: &outgoingDirections
                )
            } else {
                let jid  = treeNodeID(for: half)
                let jPos = splitNodePos(from: parentPos, widgetIDs: half,
                                        widgets: widgets, center: center,
                                        trunkWidgetID: childTrunkWidgetID,
                                        lockToSpine: isPrimaryHalf,
                                        spine: branchDir,
                                        parentNodeID: parentID,
                                        occupiedNodes: nodePos,
                                        plannedEdges: plannedEdges,
                                        outgoingDirections: outgoingDirections)
                nodePos[jid] = jPos
                specs.append(Spec(fromID: parentID, toID: jid,
                                  weight: half.count, level: level, isMainPath: isPrimaryHalf))
                registerPlannedEdge(
                    fromNodeID: parentID,
                    toNodeID: jid,
                    nodePos: nodePos,
                    plannedEdges: &plannedEdges,
                    outgoingDirections: &outgoingDirections
                )
                // Pass the clamped direction as the spine for the next level
                buildSubTree(parentID: jid, parentPos: jPos,
                             widgetIDs: half, widgets: widgets,
                             center: center,
                             trunkWidgetID: childTrunkWidgetID,
                             spineDir: branchDir,
                             level: level + 1, nodePos: &nodePos, specs: &specs,
                             plannedEdges: &plannedEdges,
                             outgoingDirections: &outgoingDirections)
            }
        }
    }

    // MARK: - Split node positioning & angle helpers

    /// Place a split node along `spine` (or the natural bisector if no spine),
    /// at a stable random depth [30 %–70 %] of the average widget distance.
    private func splitNodePos(from parent: CGPoint, widgetIDs: [UUID],
                               widgets: [UUID: CGPoint],
                               center: CGPoint,
                               trunkWidgetID: UUID?,
                               lockToSpine: Bool,
                               spine: CGPoint?,
                               parentNodeID: UUID,
                               occupiedNodes: [UUID: CGPoint],
                               plannedEdges: [PlannedEdge],
                               outgoingDirections: [UUID: [CGPoint]]) -> CGPoint {
        let pts = widgetIDs.compactMap { widgets[$0] }
        guard !pts.isEmpty else { return parent }

        var totalDist: CGFloat = 0
        for pt in pts { totalDist += hypot(pt.x - parent.x, pt.y - parent.y) }
        let avgDist = totalDist / CGFloat(pts.count)

        let anchorDir = mainPathDirection(from: parent, center: center,
                                          anchorWidgetID: trunkWidgetID ?? furthestWidgetID(from: center, ids: widgetIDs, widgets: widgets),
                                          widgets: widgets)
        // Use supplied spine direction for side branches, or let the furthest widget define the trunk.
        let baseDir = spine ?? anchorDir

        let nid      = treeNodeID(for: widgetIDs)
        let baseFraction = CGFloat(abs(nid.hashValue % 10_000)) / 10_000.0 * 0.40 + 0.30
        let parentDirs = outgoingDirections[parentNodeID] ?? []
        let angleSweep = debugSettings.candidateAngleSweepDegrees * .pi / 180
        let depthSweep = CGFloat(debugSettings.candidateDepthSweepFactor)
        let angleOffsets: [Double] = lockToSpine ? [0] : [-angleSweep, -angleSweep * 0.5, 0, angleSweep * 0.5, angleSweep]
        let depthOffsets: [CGFloat] = [-depthSweep, -depthSweep * 0.5, 0, depthSweep * 0.5, depthSweep]

        var bestPosition = CGPoint(x: parent.x + baseDir.x * avgDist * baseFraction,
                                   y: parent.y + baseDir.y * avgDist * baseFraction)
        var bestScore = -Double.infinity

        for angleOffset in angleOffsets {
            let candidateDir = normalized(rotate(baseDir, by: angleOffset))
            for depthOffset in depthOffsets {
                let fraction = min(maxJunctionDistanceFactor, max(minJunctionDistanceFactor, baseFraction + depthOffset))
                let candidate = CGPoint(
                    x: parent.x + candidateDir.x * avgDist * fraction,
                    y: parent.y + candidateDir.y * avgDist * fraction
                )
                let score = placementScore(
                    candidate: candidate,
                    parent: parent,
                    candidateDir: candidateDir,
                    parentNodeID: parentNodeID,
                    occupiedNodes: occupiedNodes,
                    plannedEdges: plannedEdges,
                    parentDirections: parentDirs
                )
                if score > bestScore {
                    bestScore = score
                    bestPosition = candidate
                }
            }
        }

        return bestPosition
    }

    /// Normalised average direction from `parent` toward each widget in `ids`.
    private func bisectorDir(from parent: CGPoint, ids: [UUID],
                              widgets: [UUID: CGPoint]) -> CGPoint {
        var bx: CGFloat = 0, by: CGFloat = 0
        for id in ids {
            guard let pt = widgets[id] else { continue }
            let dx = pt.x - parent.x, dy = pt.y - parent.y
            let d  = max(1, hypot(dx, dy))
            bx += dx / d;  by += dy / d
        }
        let len = max(1e-6, hypot(bx, by))
        return CGPoint(x: bx / len, y: by / len)
    }

    private func furthestWidgetID(from center: CGPoint, ids: [UUID],
                                  widgets: [UUID: CGPoint]) -> UUID? {
        ids.max { lhs, rhs in
            let lhsDistance = widgets[lhs].map { distance($0, center) } ?? 0
            let rhsDistance = widgets[rhs].map { distance($0, center) } ?? 0
            return lhsDistance < rhsDistance
        }
    }

    private func mainPathDirection(from parent: CGPoint, center: CGPoint,
                                   anchorWidgetID: UUID?,
                                   widgets: [UUID: CGPoint]) -> CGPoint {
        guard let anchorID = anchorWidgetID,
              let anchor = widgets[anchorID] else {
            return normalized(CGPoint(x: center.x - parent.x, y: center.y - parent.y))
        }
        return normalized(CGPoint(x: anchor.x - parent.x, y: anchor.y - parent.y))
    }

    /// Rotate `dir` toward `spine` until the angle between them is ≤ `max` radians.
    private func clampAngle(_ dir: CGPoint, to spine: CGPoint, max maxA: Double) -> CGPoint {
        let dot   = Double(dir.x * spine.x + dir.y * spine.y)
        let cross = Double(spine.x * dir.y - spine.y * dir.x)
        let angle = atan2(cross, dot)           // signed angle from spine to dir
        guard abs(angle) > maxA else { return dir }

        let clamped = maxA * (angle < 0 ? -1 : 1)
        let c = CGFloat(cos(clamped)), s = CGFloat(sin(clamped))
        // Rotate spine by the clamped angle
        return CGPoint(x: spine.x * c - spine.y * s,
                       y: spine.x * s + spine.y * c)
    }

    private func rotate(_ dir: CGPoint, by angle: Double) -> CGPoint {
        let c = CGFloat(cos(angle))
        let s = CGFloat(sin(angle))
        return CGPoint(x: dir.x * c - dir.y * s,
                       y: dir.x * s + dir.y * c)
    }

    private func normalized(_ point: CGPoint) -> CGPoint {
        let length = max(1e-6, hypot(point.x, point.y))
        return CGPoint(x: point.x / length, y: point.y / length)
    }

    private func placementScore(candidate: CGPoint,
                                parent: CGPoint,
                                candidateDir: CGPoint,
                                parentNodeID: UUID,
                                occupiedNodes: [UUID: CGPoint],
                                plannedEdges: [PlannedEdge],
                                parentDirections: [CGPoint]) -> Double {
        let nearbyNodeClearance = occupiedNodes
            .filter { $0.key != parentNodeID }
            .map { distance(candidate, $0.value) }
            .min() ?? 200

        let edgeClearance = plannedEdges
            .filter { $0.fromNodeID != parentNodeID && $0.toNodeID != parentNodeID }
            .map { distanceFromPoint(candidate, toSegmentFrom: $0.fromPos, to: $0.toPos) }
            .min() ?? 200

            let siblingAngleClearance = parentDirections
            .map { abs(signedAngle(from: $0, to: candidateDir)) }
            .min() ?? (.pi / 2)

        let pathClearance = plannedEdges
            .filter { $0.fromNodeID != parentNodeID && $0.toNodeID != parentNodeID }
            .map { distanceBetweenSegments(parent, candidate, $0.fromPos, $0.toPos) }
            .min() ?? 200

        return Double(nearbyNodeClearance) * debugSettings.nodeClearanceWeight
            + Double(edgeClearance) * debugSettings.edgeClearanceWeight
            + siblingAngleClearance * debugSettings.siblingAngleWeight
            + Double(pathClearance) * debugSettings.pathClearanceWeight
    }

    private func registerPlannedEdge(fromNodeID: UUID,
                                     toNodeID: UUID,
                                     nodePos: [UUID: CGPoint],
                                     plannedEdges: inout [PlannedEdge],
                                     outgoingDirections: inout [UUID: [CGPoint]]) {
        guard let fromPos = nodePos[fromNodeID], let toPos = nodePos[toNodeID] else { return }
        plannedEdges.append(PlannedEdge(fromNodeID: fromNodeID, toNodeID: toNodeID,
                                        fromPos: fromPos, toPos: toPos))
        let dir = normalized(CGPoint(x: toPos.x - fromPos.x, y: toPos.y - fromPos.y))
        outgoingDirections[fromNodeID, default: []].append(dir)
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    private func distanceFromPoint(_ point: CGPoint, toSegmentFrom start: CGPoint, to end: CGPoint) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 1e-6 else { return distance(point, start) }
        let t = max(0, min(1, ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared))
        let projection = CGPoint(x: start.x + dx * t, y: start.y + dy * t)
        return distance(point, projection)
    }

    private func distanceBetweenSegments(_ a0: CGPoint, _ a1: CGPoint,
                                         _ b0: CGPoint, _ b1: CGPoint) -> CGFloat {
        if segmentsIntersect(a0, a1, b0, b1) { return 0 }
        return min(
            distanceFromPoint(a0, toSegmentFrom: b0, to: b1),
            distanceFromPoint(a1, toSegmentFrom: b0, to: b1),
            distanceFromPoint(b0, toSegmentFrom: a0, to: a1),
            distanceFromPoint(b1, toSegmentFrom: a0, to: a1)
        )
    }

    private func segmentsIntersect(_ p1: CGPoint, _ p2: CGPoint,
                                   _ q1: CGPoint, _ q2: CGPoint) -> Bool {
        let o1 = orientation(p1, p2, q1)
        let o2 = orientation(p1, p2, q2)
        let o3 = orientation(q1, q2, p1)
        let o4 = orientation(q1, q2, p2)
        return o1 * o2 < 0 && o3 * o4 < 0
    }

    private func orientation(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> CGFloat {
        (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
    }

    private func signedAngle(from lhs: CGPoint, to rhs: CGPoint) -> Double {
        atan2(Double(lhs.x * rhs.y - lhs.y * rhs.x),
              Double(lhs.x * rhs.x + lhs.y * rhs.y))
    }

    private var maxBranchAngle: Double {
        debugSettings.maxBranchAngleDegrees * .pi / 180
    }

    private var minJunctionDistanceFactor: CGFloat {
        CGFloat(min(debugSettings.minJunctionDistanceFactor, debugSettings.maxJunctionDistanceFactor))
    }

    private var maxJunctionDistanceFactor: CGFloat {
        CGFloat(max(debugSettings.minJunctionDistanceFactor, debugSettings.maxJunctionDistanceFactor))
    }

    // MARK: - Stable tree node IDs

    private func treeNodeKey(_ ids: [UUID]) -> TreeNodeKey {
        TreeNodeKey(ids)
    }

    private func treeNodeID(for ids: [UUID]) -> UUID {
        let k = treeNodeKey(ids)
        if let existing = treeNodeIDs[k] { return existing }
        let new = UUID(); treeNodeIDs[k] = new; return new
    }

    // MARK: - Segment diff

    private struct Spec {
        let fromID: UUID
        let toID: UUID
        let weight: Int
        let level: Int
        let isMainPath: Bool
    }

    private func edgeKey(_ a: UUID, _ b: UUID) -> String {
        a.uuidString < b.uuidString ? "\(a)|\(b)" : "\(b)|\(a)"
    }

    @discardableResult
    private func syncSegments(specs: [Spec], nodePos: [UUID: CGPoint],
                               time: TimeInterval) -> [UUID] {
        let newByKey = Dictionary(uniqueKeysWithValues:
            specs.map { (edgeKey($0.fromID, $0.toID), $0) })
        var existKey = [String: UUID]()
        for (sid, seg) in segments {
            existKey[edgeKey(seg.fromNodeID, seg.toNodeID)] = sid
        }

        for (k, sid) in existKey where newByKey[k] == nil {
            guard segments[sid]?.retractStartedAt == nil else { continue }
            segments[sid]?.retractStartedAt = time
            let cap = sid
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) { [weak self] in
                self?.segments.removeValue(forKey: cap)
            }
        }

        var newIDs: [UUID] = []
        for (k, spec) in newByKey {
            if let sid = existKey[k] {
                segments[sid]?.weight          = spec.weight
                segments[sid]?.isMainPath      = spec.isMainPath
                segments[sid]?.retractStartedAt = nil
            } else {
                let delay = Double(spec.level) * 0.18
                let seed  = Double.random(in: 0...1)
                let seg   = NetworkSegment(
                    id: UUID(), fromNodeID: spec.fromID, toNodeID: spec.toID,
                    isMainPath: spec.isMainPath,
                    fromPos: nodePos[spec.fromID] ?? .zero,
                    toPos:   nodePos[spec.toID]   ?? .zero,
                    weight:  spec.weight, seed: seed,
                    createdAt:   time + delay,
                    nextPulseAt: time + delay + .random(in: 2.0...5.0),
                    microBranches: BranchSpec.generate(seed: seed, weight: spec.weight)
                )
                segments[seg.id] = seg
                newIDs.append(seg.id)
            }
        }
        return newIDs
    }

    // MARK: - Junction node sync

    private func syncJunctions(ids: Set<UUID>, nodePos: [UUID: CGPoint],
                                time: TimeInterval) {
        for nid in activeJunctionNodeIDs where !ids.contains(nid) {
            junctions[nid]?.retractStartedAt = time
            let cap = nid
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.junctions.removeValue(forKey: cap)
            }
        }
        for nid in ids {
            let pos = nodePos[nid] ?? .zero
            if junctions[nid] != nil {
                junctions[nid]?.position         = pos
                junctions[nid]?.retractStartedAt = nil
            } else {
                let seed = Double(abs(nid.hashValue % 10_000)) / 10_000.0
                junctions[nid] = JunctionNode(id: nid, position: pos, kind: .branch,
                                               seed: seed, createdAt: time)
            }
        }
        activeJunctionNodeIDs = ids
    }

    // MARK: - Path joints

    private func addPathJoints(for segmentIDs: [UUID], time: TimeInterval) {
        for sid in segmentIDs {
            guard let seg = segments[sid], seg.retractStartedAt == nil else { continue }
            let tValues: [Double] = seg.fromNodeID == centerNodeID
                ? [0.20, 0.48, 0.74]
                : [0.38, 0.70]
            let (cp1, cp2) = seg.controlPoints(at: time)
            for t in tValues {
                let pos = bezierPoint(t, seg.fromPos, cp1, cp2, seg.toPos)
                let j   = JunctionNode(id: UUID(), position: pos, kind: .pathJoint,
                                       seed: .random(in: 0...1),
                                       createdAt: seg.createdAt + t * 1.4)
                junctions[j.id] = j
                pathJointLinks.append(PathJointLink(junctionID: j.id, segmentID: sid, t: t))
            }
        }
    }

    private func updatePathJoints(time: TimeInterval) {
        var dead: [Int] = []
        for (idx, link) in pathJointLinks.enumerated() {
            guard let seg = segments[link.segmentID] else {
                junctions.removeValue(forKey: link.junctionID)
                dead.append(idx)
                continue
            }
            if let rs = seg.retractStartedAt {
                junctions[link.junctionID]?.retractStartedAt = rs
            }
            let (cp1, cp2) = seg.controlPoints(at: time)
            junctions[link.junctionID]?.position =
                bezierPoint(link.t, seg.fromPos, cp1, cp2, seg.toPos)
        }
        for idx in dead.reversed() { pathJointLinks.remove(at: idx) }
    }

    // MARK: - Pulse lifecycle

    private func tickPulses(time: TimeInterval) {
        for id in Array(segments.keys) {
            guard var seg = segments[id] else { continue }
            seg.pulses = seg.pulses.filter { $0.t(at: time) != nil }
            if time >= seg.nextPulseAt, seg.retractStartedAt == nil,
               seg.drawFraction(at: time) > 0.8 {
                seg.pulses.append(EnergyPulse(startTime: time,
                                               speed: .random(in: 0.25...0.45)))
                seg.nextPulseAt = time + .random(in: 3.5...8.0)
            }
            segments[id] = seg
        }
    }
}
