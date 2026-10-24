import XCTest
import simd
@testable import GhostHandsCore

final class WorkspaceSafetyTests:XCTestCase {
    func testPumpFlowContinuityAtInletAndOutlet() {
        for t:Float in [0.25,0.75] {XCTAssertLessThan(simd_distance(LabMotion.pumpFlow(t-0.00001),LabMotion.pumpFlow(t+0.00001)),0.0001)}
        XCTAssertEqual(LabMotion.pumpFlow(0),[0,0,0.10])
        XCTAssertEqual(LabMotion.pumpFlow(1),[0.08,0.12,0.02])
    }
    func testAnchorLockRejectsJumpRotationAndNonfiniteUntilExplicitReset() {
        var lock=WorkspaceLock();var base=matrix_identity_float4x4;base.columns.3=[0,0.8,-0.5,1];lock.reset(base)
        var corrected=base;corrected.columns.3.x += 0.005;XCTAssertTrue(lock.accepts(corrected))
        var behind=base;behind.columns.3.z=0.6;XCTAssertFalse(lock.accepts(behind));XCTAssertFalse(lock.accepts(base))
        lock.reset(base);var rotated=simd_float4x4(simd_quatf(angle:.pi,axis:[0,1,0]));rotated.columns.3=base.columns.3;XCTAssertFalse(lock.accepts(rotated))
        lock.reset(base);var invalid=base;invalid.columns.0.x = .nan;XCTAssertFalse(lock.accepts(invalid))
        lock.reset(base);XCTAssertTrue(lock.accepts(base))
    }
    @MainActor func model()->StudioModel {StudioModel(storage:FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("takes"))}
    @MainActor func testTrackingJumpHidesWorkspaceWithoutMovingItOrAcceptingLaterUpdates() {
        let m=model();m.immersive=true;m.placed=true;m.position=[0,0.8,-0.5];m.lockWorkspace();let original=m.workspace
        var shifted=original;shifted.columns.3.z=0.6;m.receiveWorkspaceAnchor(shifted,tracked:true)
        XCTAssertFalse(m.workspaceVisible);XCTAssertNotNil(m.trackingIssue);XCTAssertEqual(m.position,[0,0.8,-0.5]);XCTAssertEqual(m.mode,.paused)
        m.receiveWorkspaceAnchor(original,tracked:true);XCTAssertFalse(m.workspaceVisible)
        m.beginPlacement();XCTAssertNil(m.trackingIssue);XCTAssertFalse(m.placed)
    }
    @MainActor func testTemporaryAnchorLossRecoversAtSameTableAndCancelsCountdown() {
        let m=model();m.immersive=true;m.placed=true;m.capture.ready=true;m.lockWorkspace();let original=m.workspace
        m.capture.right=TimedHand(time:1,pose:IllustratedMotion.hand(at:[0,0,0],left:false,curl:0))
        m.beginRecording(now:1);XCTAssertEqual(m.mode,.countdown)
        m.receiveWorkspaceAnchor(nil,tracked:false);XCTAssertFalse(m.workspaceVisible);XCTAssertEqual(m.mode,.paused)
        m.receiveWorkspaceAnchor(original,tracked:true);XCTAssertTrue(m.workspaceVisible);XCTAssertEqual(m.mode,.paused)
    }
    @MainActor func testTrackingLossPreservesPartialTake() async {
        let m=model();m.immersive=true;m.placed=true;m.capture.ready=true;m.lockWorkspace()
        let pose=IllustratedMotion.hand(at:[0,0,0],left:false,curl:0)
        m.capture.right=TimedHand(time:1,pose:pose);m.beginRecording(now:1)
        for t in [4.0,4.1,4.2] {m.capture.right=TimedHand(time:t,pose:pose);m.tick(now:t)}
        XCTAssertEqual(m.mode,.recording)
        m.receiveWorkspaceAnchor(nil,tracked:false)
        for _ in 0..<100 {if !m.saving {break};try? await Task.sleep(for:.milliseconds(10))}
        XCTAssertEqual(m.mode,.paused);XCTAssertEqual(m.clips.count,1);XCTAssertGreaterThanOrEqual(m.clips.first?.frames.count ?? 0,2)
    }
    @MainActor func testNoUnrequestedMoveOrDuplicateEntryReset() async {
        let m=model();await m.entered();m.placed=true;m.position=[0,0.8,-0.5];m.lockWorkspace()
        await m.entered();XCTAssertTrue(m.placed);XCTAssertEqual(m.position,[0,0.8,-0.5])
        m.move([0.01,0,0]);m.rotateWorkspace(.pi/36);XCTAssertEqual(m.position,[0,0.8,-0.5]);XCTAssertEqual(m.yaw,0)
        m.beginAdjustment();m.move([100,0,0]);XCTAssertEqual(m.position,[0,0.8,-0.5]);m.move([0.01,0,0]);XCTAssertEqual(m.position.x,0.01,accuracy:0.0001)
        m.finishAdjustment();XCTAssertFalse(m.adjustingPlacement);m.leftStudio()
    }
    @MainActor func testPlacementRequiresTrackedHeadAndHeadingFreezesWhileHolding() async {
        let m=model();await m.entered();m.startFingerPlacement()
        var pose=IllustratedMotion.hand(at:[0,0.7,-0.4],left:false,curl:0)
        func feed(_ time:Double,_ y:Float) {pose.joints[9]=[0,y,-0.4];pose.joints[4]=[0.05,y,-0.4];m.capture.right=TimedHand(time:time,pose:pose);m.tick(now:time)}
        m.capture.head=nil;feed(0,0.7);feed(0.2,0.64);feed(3,0.64);XCTAssertFalse(m.placed)
        m.capture.head=matrix_identity_float4x4;feed(3.1,0.64);feed(3.6,0.64);let heading=m.yaw
        var movedHead=matrix_identity_float4x4;movedHead.columns.3.x=0.3;m.capture.head=movedHead;feed(4.0,0.64)
        XCTAssertEqual(m.yaw,heading);feed(5,0.64);XCTAssertTrue(m.placed);XCTAssertEqual(m.position.y,0.642,accuracy:0.0001);m.leftStudio()
    }
    @MainActor func testColorPersistsAndMechanismsRespondOnlyWhenAvailable() {
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("takes")
        let m=StudioModel(storage:folder);m.coloredModels=true;let r=StudioModel(storage:folder)
        XCTAssertTrue(r.coloredModels)
        m.immersive=true;m.placed=true;m.chooseLesson(LessonCatalog.brake.id);XCTAssertTrue(m.loops)
        m.selectLabPart("lab-part-caliper");XCTAssertTrue(m.mechanismEngaged)
        m.tick(now:1);m.tick(now:1.1);XCTAssertGreaterThan(m.mechanismBlend,0)
        m.explodedView=true;m.operateMechanism();XCTAssertTrue(m.mechanismEngaged)
        m.chooseLesson(LessonCatalog.pump.id);XCTAssertFalse(m.mechanismEngaged)
        m.selectLabPart("lab-part-impeller");XCTAssertTrue(m.mechanismEngaged)
        m.mode = .recording;m.operateMechanism();XCTAssertTrue(m.mechanismEngaged)
    }
}
