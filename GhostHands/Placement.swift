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
    private(set) var progress: Float = 0
    private var origin: SIMD3<Float>?
    private var stableSince = 0.0
    private var armed = false
    private var pinchedSince: Double?
    var isCommitting: Bool { pinchedSince != nil }
    mutating func reset() { self = Self() }
    mutating func update(rightTip: SIMD3<Float>?, leftGap: Float?, now: Double, automatic: Bool = false) -> Bool {
        guard let tip=rightTip,tip.isFinite else {reset();return false}
        if origin == nil || simd_distance(origin!,tip)>0.012 {
            origin=tip;candidate=tip;stableSince=now;ready=false;armed=false;pinchedSince=nil
        }
        if pinchedSince == nil,let previous=candidate {candidate=previous*0.8+tip*0.2}
        progress=min(1,max(0,Float((now-stableSince)/1.8)))
        ready=now-stableSince>=0.35
        if automatic {return progress>=1}
        guard let gap=leftGap,gap.isFinite else {armed=false;pinchedSince=nil;return false}
        if gap>0.035 {armed=ready;pinchedSince=nil}
        guard ready,armed,gap<0.018 else {pinchedSince=nil;return false}
        if pinchedSince == nil {pinchedSince=now}
        if now-pinchedSince!>=0.15 {armed=false;pinchedSince=nil;return true}
        return false
    }
}

/// Reject relocalization jumps instead of rendering a workspace in a new place.
struct WorkspaceLock {
    private(set) var committed: simd_float4x4?
    private(set) var needsReplacement=false
    mutating func reset(_ transform:simd_float4x4?=nil) {committed=transform;needsReplacement=false}
    mutating func accepts(_ transform:simd_float4x4)->Bool {
        guard !needsReplacement,let original=committed else{return false}
        let values=[transform.columns.0,transform.columns.1,transform.columns.2,transform.columns.3]
        let delta=SIMD3<Float>(transform.columns.3.x-original.columns.3.x,transform.columns.3.y-original.columns.3.y,transform.columns.3.z-original.columns.3.z)
        let alignment=simd_dot(SIMD3<Float>(transform.columns.2.x,transform.columns.2.y,transform.columns.2.z),SIMD3<Float>(original.columns.2.x,original.columns.2.y,original.columns.2.z))
        guard values.allSatisfy({$0.x.isFinite && $0.y.isFinite && $0.z.isFinite && $0.w.isFinite}),simd_length(delta)<0.12,alignment>cos(Float.pi/12),transform.columns.1.y>0.96 else {needsReplacement=true;return false}
        return true
    }
}
