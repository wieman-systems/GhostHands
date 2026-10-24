import XCTest
import simd
@testable import GhostHandsCore

final class MotionTests: XCTestCase {
    func pose(_ x: Float) -> HandPose { HandPose(joints: Array(repeating: SIMD3<Float>(x,0.1,0.2), count: 25)) }
    func testCaptureAndRelocatedReplayPreservePaperRelativePosition() {
        var source = simd_float4x4(simd_quatf(angle: .pi/3, axis: [0,1,0]))
        source.columns.3 = [1,0.7,-2,1]
        var destination = simd_float4x4(simd_quatf(angle: -.pi/4, axis: [0,1,0]))
        destination.columns.3 = [-2,0.9,1,1]
        let local = pose(0.05)
        let captured = local.transformed(by: source).transformed(by: simd_inverse(source))
        let replay = captured.transformed(by: destination)
        let expected = local.transformed(by: destination)
        XCTAssertLessThan(simd_distance(replay.joints[0]!, expected.joints[0]!), 0.00001)
    }
    func testInterpolationAndIndependentHandLoss() {
        let clip = MotionClip(title:"Take", frames:[
            .init(time:0,left:pose(0),right:pose(0)),
            .init(time:0.1,left:pose(0.1),right:nil)])
        let sample = clip.sample(at:0.05)
        XCTAssertEqual(sample.left!.joints[0]!.x,0.05,accuracy:0.00001)
        XCTAssertNil(sample.right)
    }
    func testDoesNotBridgeDroppedFrameInterval() {
        let clip = MotionClip(title:"Gap", frames:[.init(time:0,left:pose(0),right:nil),.init(time:1,left:pose(1),right:nil)])
        XCTAssertNil(clip.sample(at:0.5).left)
    }
    func testFreshnessRejectsStaleAndFutureSamples() {
        let hand = TimedHand(time:1,pose:pose(0))
        XCTAssertNotNil(hand.fresh(at:1.1))
        XCTAssertNil(hand.fresh(at:1.3))
        XCTAssertNil(hand.fresh(at:0.9))
    }
    func testInvalidIndividualJointRemainsAbsent() {
        var a = pose(0), b = pose(1)
        a.joints[9] = nil; b.joints[24] = nil
        let mixed = HandPose.interpolate(a,b,fraction:0.5)!
        XCTAssertNil(mixed.joints[9]); XCTAssertNil(mixed.joints[24])
        XCTAssertNotNil(mixed.joints[0])
    }
    func testValidationRejectsBadTimestampsAndJointCounts() {
        let frame = MotionFrame(time:0,left:pose(0),right:nil)
        XCTAssertThrowsError(try MotionClip(title:"Duplicate",frames:[frame,frame]).validated())
        XCTAssertThrowsError(try MotionClip(title:"Malformed",frames:[.init(time:0,left:HandPose(joints:[]),right:nil)]).validated())
        var invalid = pose(0); invalid.joints[2] = [.nan,0,0]
        XCTAssertThrowsError(try MotionClip(title:"NaN",frames:[.init(time:0,left:invalid,right:nil)]).validated())
    }
    func testPersistenceRoundTripAndCorruptFileIsolation() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:directory) }
        let clip = MotionClip(title:"Fold 1",lessonStep:0,frames:[.init(time:0,left:pose(0),right:nil),.init(time:0.1,left:pose(0.1),right:nil)])
        try ClipStorage.save(clip,in:directory)
        try Data("not a recording".utf8).write(to:directory.appendingPathComponent("corrupt.json"))
        let result = ClipStorage.load(in:directory)
        XCTAssertEqual(result.clips,[clip]); XCTAssertEqual(result.failures,1)
    }
    func testIllustrationsUseProductionFormatAndAreLabeled() throws {
        for step in PaperStep.all {
            let clip = try IllustratedMotion.clip(step:step.id,side:0.20).validated()
            XCTAssertTrue(clip.isIllustration)
            XCTAssertEqual(clip.lessonStep,step.id)
            XCTAssertEqual(clip.duration,8)
            XCTAssertNotNil(clip.sample(at:3.45).left)
            XCTAssertNotNil(clip.sample(at:3.45).right)
        }
    }
    func testSamplingEndpointsAndZeroDuration() {
        let clip = MotionClip(title:"Single",frames:[.init(time:0,left:pose(0),right:nil)])
        XCTAssertEqual(clip.sample(at:-1).left,pose(0))
        XCTAssertEqual(clip.sample(at:5).left,pose(0))
        XCTAssertNil(clip.sample(at:.nan).left)
    }
}
