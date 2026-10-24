import XCTest
import simd
@testable import GhostHandsCore

final class LabTests:XCTestCase {
    @MainActor func testValidPlaybackRecoversFromTransientVideoFailure() {
        let video=VideoSession();video.visible=true
        video.request(videoID:"vNba3jbBSOw",segment:nil,play:true,rate:1)
        let serial=video.command!.serial
        video.fail("Temporary player error")
        XCTAssertFalse(video.receive(serial:serial-1,videoID:"vNba3jbBSOw",time:20,duration:200,state:1,rate:1))
        XCTAssertTrue(video.failed)
        XCTAssertTrue(video.receive(serial:serial,videoID:"vNba3jbBSOw",time:20,duration:200,state:1,rate:1))
        XCTAssertFalse(video.failed);XCTAssertTrue(video.ready)
        video.request(videoID:"vNba3jbBSOw",segment:nil,play:false,rate:1)
        XCTAssertGreaterThan(video.command!.serial,serial)
    }

    func testLabLessonsAreValidAndNeverInventVideoTiming() {
        for lesson in [LessonCatalog.jet,LessonCatalog.gearbox] {
            XCTAssertTrue(lesson.isValid);XCTAssertFalse(lesson.hasVideo)
            XCTAssertTrue(lesson.steps.allSatisfy{$0.segment==nil && $0.paperIndex==nil})
        }
        var invalid=LessonCatalog.jet;invalid.steps[0].segment = .init(start:0,end:10);XCTAssertFalse(invalid.isValid)
    }
    func testFlowPathsAndGearRatio() {
        for i in 0..<84 {for t in stride(from:0.0,through:8,by:0.1) {
            let core=LabMotion.flow(index:i,count:84,progress:t,bypass:false),bypass=LabMotion.flow(index:i,count:84,progress:t,bypass:true)
            XCTAssertTrue(core.x.isFinite);XCTAssertGreaterThanOrEqual(core.x,-0.161);XCTAssertLessThanOrEqual(core.x,0.201)
            XCTAssertLessThan(simd_length(SIMD2(core.y-0.10,core.z)),0.02)
            XCTAssertGreaterThan(simd_length(SIMD2(bypass.y-0.10,bypass.z)),0.05)
        }}
        let start=LabMotion.gearAngles(seconds:0),end=LabMotion.gearAngles(seconds:2)
        XCTAssertEqual(end.0-start.0,-2*(end.1-start.1),accuracy:0.0001)
    }
    func testNarrationPolicySeparatesManualVideoAndAutomatic() {
        XCTAssertFalse(NarrationPolicy.allows(automatic:true,hasVideo:true,repeatAfterVideo:false,manual:false))
        XCTAssertTrue(NarrationPolicy.allows(automatic:true,hasVideo:true,repeatAfterVideo:true,manual:false))
        XCTAssertTrue(NarrationPolicy.allows(automatic:true,hasVideo:false,repeatAfterVideo:false,manual:false))
        XCTAssertFalse(NarrationPolicy.allows(automatic:false,hasVideo:false,repeatAfterVideo:true,manual:false))
        XCTAssertTrue(NarrationPolicy.allows(automatic:false,hasVideo:true,repeatAfterVideo:false,manual:true))
    }
    @MainActor func testAudioPreferencesPersistAndFailureAllowsOfflineRead() throws {
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:folder)}
        let storage=folder.appendingPathComponent("takes")
        let m=StudioModel(storage:storage);m.narrationEnabled=false;m.repeatNarrationAfterVideo=true;m.naturalNarration=false
        let restored=StudioModel(storage:storage)
        XCTAssertFalse(restored.narrationEnabled);XCTAssertTrue(restored.repeatNarrationAfterVideo);XCTAssertFalse(restored.naturalNarration)
        restored.narrationEnabled=true;restored.repeatNarrationAfterVideo=false;restored.videoOpened();XCTAssertFalse(restored.automaticNarrationAllowed)
        restored.video.fail("Offline");XCTAssertTrue(restored.automaticNarrationAllowed)
    }
    @MainActor func testOldPlayerCannotCloseNewPlayerOrRetryLoseOwnership() {
        let m=StudioModel(storage:FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("takes"))
        let first=UUID(),second=UUID();m.videoOpened(owner:first);m.videoOpened(owner:second);m.videoClosed(owner:first)
        XCTAssertTrue(m.video.visible);XCTAssertEqual(m.videoOwner,second)
        m.retryVideo();XCTAssertEqual(m.videoOwner,second)
        m.videoClosed(owner:second);XCTAssertFalse(m.video.visible)
    }
    @MainActor func testInspectionOnlyAcceptsDefectInInspectionStep() {
        let m=StudioModel(storage:FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("takes"))
        m.immersive=true;m.placed=true;m.chooseLesson(LessonCatalog.jet.id)
        m.selectLabPart("lab-defect");XCTAssertFalse(m.defectFound)
        m.setStep(m.stepCount-1);m.selectLabPart("lab-defect");XCTAssertTrue(m.defectFound)
        m.setStep(0);XCTAssertFalse(m.defectFound)
    }
    func testEveryBuiltInInstructionHasMatchingNarrationAsset() throws {
        let folder=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("GhostHands/NarrationResources")
        for lesson in LessonCatalog.all {for step in lesson.steps {
            let file=folder.appendingPathComponent(NarrationPolicy.assetName(for:NarrationPolicy.text(for:step))+".mp3")
            let data=try Data(contentsOf:file);XCTAssertGreaterThan(data.count,1000)
        }}
    }
}
