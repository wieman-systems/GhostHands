#if os(macOS)
// macOS unit-test adapter. Not compiled into either visionOS app binary.
import Foundation
import simd

@MainActor final class HandCapture {
    var onWorkspaceAnchor:((simd_float4x4?,Bool)->Void)?
    func clearWorkspaceAnchor() {}
    func anchorWorkspace(_ transform:simd_float4x4) {}
    var ready = false
    var status = "Test input"
    var left: TimedHand?
    var right: TimedHand?
    func start() async { ready = true }
    func clear() { left = nil; right = nil }
    func stop() { ready = false; clear() }
    var head:simd_float4x4?=matrix_identity_float4x4
    func headTransform() -> simd_float4x4? { head }
    func snapshot(at now: Double) -> MotionFrame {
        MotionFrame(time: now, left: ready ? left?.fresh(at: now) : nil, right: ready ? right?.fresh(at: now) : nil)
    }
}
#endif
