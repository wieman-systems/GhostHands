import XCTest
import simd
@testable import GhostHandsCore

final class PlacementTests: XCTestCase {
    func hand(gap: Float) -> HandPose {
        var pose=IllustratedMotion.hand(at:[0,0,0],left:false,curl:0)
        pose.joints[4]=[gap,0,0];pose.joints[9]=[0,0,0];return pose
    }
    @MainActor func testManualPreviewStartsWithoutSurfaceDetection() async {
        let model=StudioModel(storage:FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        await model.entered()
        XCTAssertFalse(model.placed);XCTAssertFalse(model.placementReady)
        XCTAssertFalse(model.fingerPlacement)
        model.startFingerPlacement()
        var right=hand(gap:0.05);right.joints[9]=[0.2,0.7,-0.4]
        func feed(_ time:Double,_ gap:Float) {
            model.capture.right=TimedHand(time:time,pose:right)
            model.capture.left=TimedHand(time:time,pose:hand(gap:gap))
            model.tick(now:time)
        }
        feed(0.8,0.05)
        right.joints[9]=[0.2,0.64,-0.4]
        feed(1,0.05)
        XCTAssertFalse(model.placementReady);XCTAssertFalse(model.placed)
        feed(1.4,0.05)
        XCTAssertTrue(model.placementReady)
        XCTAssertEqual(model.position.y,0.632,accuracy:0.0001)
        feed(1.45,0.01);XCTAssertFalse(model.placed)
        feed(1.61,0.01);XCTAssertFalse(model.placed)
        feed(2.81,0.05)
        XCTAssertTrue(model.placed);XCTAssertEqual(model.mode,.playing)
        let locked=model.position
        right.joints[9]=[0,1.4,0];feed(2.9,0.01)
        XCTAssertEqual(model.position,locked)
        model.leftStudio()
    }
    @MainActor func testEveryNextStepAutoplaysButDoesNotAutoadvance() {
        let model=StudioModel(storage:FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        model.immersive=true;model.placed=true
        for step in PaperStep.all {
            model.setStep(step.id);XCTAssertEqual(model.mode,.playing);XCTAssertEqual(model.elapsed,model.currentStep.staticPaper ? model.progressDuration : 0)
        }
        XCTAssertFalse(model.loops)
        model.elapsed=7.99;model.tick(now:100);model.tick(now:100.1)
        XCTAssertEqual(model.mode,.paused);XCTAssertEqual(model.step,PaperStep.all.count-1)
    }
    func testFoldingPaperEndsAtReflectedContactAndStaysFinite() {
        for step in PaperStep.all {
            for frame in 0...30 {
                let mesh=PaperMotion.vertices(step:step,progress:Float(frame)/30,width:LetterPaper.width)
                XCTAssertFalse(mesh.isEmpty);XCTAssertEqual(mesh.count % 3,0)
                XCTAssertTrue(mesh.allSatisfy {$0.isFinite && simd_length($0)<0.4})
            }
        }
        let fold=PaperStep.all[0]
        let end=PaperMotion.contact(step:fold,progress:1,width:LetterPaper.width)
        XCTAssertEqual(end.x,LetterPaper.width/2,accuracy:0.0001)
        XCTAssertEqual(end.y,0,accuracy:0.0001)
        let lift=PaperMotion.contact(step:fold,progress:0.5,width:LetterPaper.width)
        XCTAssertGreaterThan(lift.y,0.10)
    }
    func testPocketAnimationContinuity() {
        for pair in [(9,10),(14,15)] {
            let opened=PaperMotion.vertices(step:PaperStep.all[pair.0],progress:1,width:LetterPaper.width)
            let flattenStart=PaperMotion.vertices(step:PaperStep.all[pair.1],progress:0,width:LetterPaper.width)
            XCTAssertEqual(opened,flattenStart)
            let flat=PaperMotion.vertices(step:PaperStep.all[pair.1],progress:1,width:LetterPaper.width)
            XCTAssertTrue(flat.allSatisfy {abs($0.y)<0.00001})
        }
    }
    func testCalibrationRejectsMovingFingerAndHeldPinchOnReacquisition() {
        var c=TableCalibration()
        XCTAssertFalse(c.update(rightTip:[0,0.7,0],leftGap:0.05,now:0))
        XCTAssertFalse(c.update(rightTip:[0.02,0.7,0],leftGap:0.01,now:0.4))
        XCTAssertFalse(c.ready)
        XCTAssertFalse(c.update(rightTip:[0.02,0.7,0],leftGap:0.01,now:0.8))
        XCTAssertFalse(c.update(rightTip:nil,leftGap:nil,now:0.9))
        XCTAssertFalse(c.update(rightTip:[0.02,0.7,0],leftGap:0.01,now:1))
        XCTAssertFalse(c.update(rightTip:[0.02,0.7,0],leftGap:0.01,now:1.4))
        XCTAssertFalse(c.update(rightTip:[0.02,0.7,0],leftGap:0.05,now:1.5))
        XCTAssertFalse(c.update(rightTip:[0.02,0.7,0],leftGap:0.01,now:1.6))
        XCTAssertTrue(c.update(rightTip:[0.02,0.7,0],leftGap:0.01,now:1.8))
        XCTAssertFalse(c.update(rightTip:[0.02,0.7,0],leftGap:0.01,now:2))
    }
    @MainActor func testReplayPreservesSelectedRecordingAndPausedSetupCannotCommit() {
        let model=StudioModel(storage:FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        model.immersive=true;model.placed=true
        var clip=IllustratedMotion.clip(step:0,side:0.2);clip.isIllustration=false
        model.load(clip);model.seek(3);model.replayCurrent()
        XCTAssertEqual(model.selected?.id,clip.id);XCTAssertEqual(model.elapsed,0);XCTAssertEqual(model.mode,.playing)
        model.beginPlacement();model.suspend()
        model.capture.ready=true
        model.capture.right=TimedHand(time:10,pose:hand(gap:0.05))
        model.capture.left=TimedHand(time:10,pose:hand(gap:0.01))
        model.tick(now:10)
        XCTAssertFalse(model.placed);XCTAssertFalse(model.placementReady)
    }
    func testAutomaticPlacementNeedsStableFingerAndResetsOnLoss() {
        var c=TableCalibration()
        XCTAssertFalse(c.update(rightTip:[0,0.8,0],leftGap:nil,now:0,automatic:true))
        XCTAssertFalse(c.update(rightTip:[0,0.8,0],leftGap:nil,now:1.7,automatic:true))
        XCTAssertFalse(c.update(rightTip:nil,leftGap:nil,now:1.75,automatic:true))
        XCTAssertEqual(c.progress,0)
        XCTAssertFalse(c.update(rightTip:[0,0.8,0],leftGap:nil,now:2,automatic:true))
        XCTAssertTrue(c.update(rightTip:[0,0.8,0],leftGap:nil,now:3.81,automatic:true))
    }
    @MainActor func testAdjustmentMovesAllWorkspaceAxesAndPausesPlayback() {
        let m=StudioModel(storage:FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        m.immersive=true;m.placed=true;m.setStep(2);m.beginAdjustment()
        XCTAssertTrue(m.adjustingPlacement);XCTAssertEqual(m.mode,.paused)
        m.position = .zero;m.yaw = .pi/2;m.move([0,0.002,-0.01])
        XCTAssertEqual(m.position.x,-0.01,accuracy:0.00001);XCTAssertEqual(m.position.y,0.002,accuracy:0.00001)
        m.beginPlacement();XCTAssertFalse(m.adjustingPlacement);XCTAssertFalse(m.fingerPlacement)
    }
    func testLegacySquareClipRemainsDecodable() throws {
        let original=MotionClip(title:"Old take",paperSide:0.20,frames:[.init(time:0,left:hand(gap:0.04),right:nil)])
        let data=try JSONEncoder().encode(original)
        var object=try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any])
        object.removeValue(forKey:"paperHeight");object.removeValue(forKey:"lessonID")
        let decoded=try JSONDecoder().decode(MotionClip.self,from:JSONSerialization.data(withJSONObject:object))
        XCTAssertNil(decoded.paperHeight);XCTAssertEqual(decoded.paperSide,0.20)
        XCTAssertNoThrow(try decoded.validated())
    }
    func testSkinRetargetingPreservesJointPositionsAndRejectsMissingFingers() throws {
        let folder=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("GhostHands/HandResources")
        for side in ["left","right"] {
            let spec=try JSONDecoder().decode(HandRigSpec.self,from:Data(contentsOf:folder.appendingPathComponent("reference_\(side).json")))
            let pose=IllustratedMotion.hand(at:[0.08,0.03,-0.04],left:side=="left",curl:0.65)
            let matrices=try XCTUnwrap(HandRetargeting.matrices(pose:pose,rest:spec.rest))
            XCTAssertEqual(matrices.count,27)
            for i in 0..<25 { XCTAssertLessThan(simd_distance(HandRetargeting.point(matrices[i]),pose.joints[i]!),0.00001) }
            var missing=pose;missing.joints[9]=nil
            XCTAssertNil(HandRetargeting.matrices(pose:missing,rest:spec.rest))
        }
    }
    @MainActor func testPlacementLocksUntilExplicitReposition() {
        let model=StudioModel(storage:FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        model.immersive=true;model.capture.ready=true;model.placementReady=true
        model.position=[0,0.7,-0.5];model.confirmPlacement()
        let fixed=model.position
        model.tick(now:100)
        XCTAssertEqual(model.position,fixed);XCTAssertTrue(model.placed)
        XCTAssertEqual(model.paperSide,LetterPaper.width);XCTAssertEqual(model.paperHeight,LetterPaper.height)
        XCTAssertEqual(model.speed,0.75)
    }
}
