import Foundation

enum LetterPaper {
    static let width: Float = 0.2159
    static let height: Float = 0.2794
}

import simd

/// A stable pointing finger establishes the plane; the other hand commits it.
/// Lost input or movement requires a fresh release before another commitment.
struct TableCalibration {
    private(set) var candidate: SIMD3<Float>?
    private(set) var ready = false
    private var origin: SIMD3<Float>?
    private var stableSince = 0.0
    private var armed = false
    private var pinchedSince: Double?
    var isCommitting: Bool { pinchedSince != nil }
    mutating func reset() { self = Self() }
    mutating func update(rightTip: SIMD3<Float>?, leftGap: Float?, now: Double) -> Bool {
        guard let tip=rightTip,tip.isFinite else {reset();return false}
        if origin == nil || simd_distance(origin!,tip)>0.012 {
            origin=tip;candidate=tip;stableSince=now;ready=false;armed=false;pinchedSince=nil
        }
        if pinchedSince == nil,let previous=candidate {candidate=previous*0.8+tip*0.2}
        ready=now-stableSince>=0.35
        guard let gap=leftGap,gap.isFinite else {armed=false;pinchedSince=nil;return false}
        if gap>0.035 {armed=ready;pinchedSince=nil}
        guard ready,armed,gap<0.018 else {pinchedSince=nil;return false}
        if pinchedSince == nil {pinchedSince=now}
        if now-pinchedSince!>=0.15 {armed=false;pinchedSince=nil;return true}
        return false
    }
}
