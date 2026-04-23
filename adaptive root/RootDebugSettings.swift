//
//  RootDebugSettings.swift
//  adaptive root
//

import Foundation

@Observable
final class RootDebugSettings {
    static let shared = RootDebugSettings()

    var maxBranchAngleDegrees: Double = 30
    var minJunctionDistanceFactor: Double = 0.24
    var maxJunctionDistanceFactor: Double = 0.82
    var candidateAngleSweepDegrees: Double = 14
    var candidateDepthSweepFactor: Double = 0.12
    var siblingAngleWeight: Double = 120
    var edgeClearanceWeight: Double = 0.35
    var pathClearanceWeight: Double = 0.40
    var nodeClearanceWeight: Double = 0.45

    private init() { }
}
