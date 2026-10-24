import XCTest
import simd
@testable import GhostHandsCore

final class StudioTests: XCTestCase {
    @MainActor func prepare(_ directory: URL) -> StudioModel {
        let model = StudioModel(storage:directory)
        model.immersive = true; model.placed = true; model.capture.ready = true
        feed(model,at:100)
        return model
    }
    @MainActor func feed(_ model: StudioModel, at time: Double) {
        let local = IllustratedMotion.hand(at:[0,0.02,0],left:true,curl:0)
        model.capture.left = TimedHand(time:time,pose:local.transformed(by:model.workspace))
    }
    @MainActor func waitForSave(_ model: StudioModel) async throws {
        for _ in 0..<100 where model.saving { try await Task.sleep(for:.milliseconds(10)) }
        XCTAssertFalse(model.saving)
        XCTAssertFalse(model.hasUnsaved,model.error ?? "Unsaved recording")
    }
    @MainActor func testCountdownCaptureTrackingGapAndSavedReplay() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:directory) }
        let model = prepare(directory)
        model.beginRecording(now:100)
        XCTAssertTrue(model.mode == .countdown)
        model.tick(now:102)
        XCTAssertEqual(model.countdown,1)
        feed(model,at:103); model.tick(now:103)
        XCTAssertTrue(model.mode == .recording)
        model.tick(now:103.3) // stale pose creates an explicit gap
        feed(model,at:103.4); model.tick(now:103.4)
        model.finishRecording()
        try await waitForSave(model)
        XCTAssertEqual(model.clips.count,1)
        let clip = try XCTUnwrap(model.clips.first)
        XCTAssertFalse(clip.isIllustration)
        XCTAssertNotNil(clip.frames.first?.left)
        XCTAssertNil(clip.frames[1].left)
        XCTAssertNil(clip.frames[1].right)
        let expected = IllustratedMotion.hand(at:[0,0.02,0],left:true,curl:0)
        XCTAssertLessThan(simd_distance(clip.frames[0].left!.joints[0]!,expected.joints[0]!),0.0001)
        let reloaded = StudioModel(storage:directory)
        XCTAssertEqual(reloaded.clips,[clip])
    }
    @MainActor func testCancelCountdownDoesNotSaveAndBlocksRepositionWhileArmed() {
        let model = prepare(FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let original = model.position
        model.beginRecording(now:100)
        model.move([1,1,1]); XCTAssertEqual(model.position,original)
        model.cancelCountdown(); model.tick(now:104)
        XCTAssertTrue(model.mode == .idle)
        XCTAssertTrue(model.clips.isEmpty)
    }
    @MainActor func testTrackingInterruptionKeepsPartialTakeOnce() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:directory) }
        let model = prepare(directory)
        model.beginRecording(now:100)
        feed(model,at:103); model.tick(now:103)
        feed(model,at:103.1); model.tick(now:103.1)
        model.capture.ready = false; model.tick(now:103.2)
        model.leftStudio(); model.finishRecording()
        try await waitForSave(model)
        XCTAssertEqual(model.clips.count,1)
        XCTAssertFalse(model.immersive)
        XCTAssertTrue(model.mode == .paused)
    }
    @MainActor func testPlaybackSpeedSeekLoopAndPause() {
        let model = prepare(FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        model.load(IllustratedMotion.clip(step:0,side:0.2))
        model.speed = 0.5; model.loops = true
        XCTAssertEqual(model.mode, .playing)
        model.tick(now:100); model.tick(now:100.1)
        XCTAssertEqual(model.elapsed,0.05,accuracy:0.001)
        model.playPause(); model.tick(now:100.2)
        XCTAssertEqual(model.elapsed,0.05,accuracy:0.001)
        model.seek(7.99); model.playPause(); model.tick(now:100.3)
        XCTAssertLessThan(model.elapsed,0.1)
        model.loops = false; model.seek(7.99); model.playPause(); model.tick(now:100.4)
        XCTAssertEqual(model.elapsed,8)
        XCTAssertTrue(model.mode == .paused)
    }
}
