#if os(macOS)
// macOS unit-test adapter. Not compiled into either visionOS app binary.
import Foundation
import simd

@MainActor final class HandCapture {
    var ready = false
    var status = "Test input"
    var left: TimedHand?
    var right: TimedHand?
    func start() async { ready = true }
    func clear() { left = nil; right = nil }
    func stop() { ready = false; clear() }
    func headTransform() -> simd_float4x4? { nil }
    func snapshot(at now: Double) -> MotionFrame {
        MotionFrame(time: now, left: ready ? left?.fresh(at: now) : nil, right: ready ? right?.fresh(at: now) : nil)
    }
}
#endif
