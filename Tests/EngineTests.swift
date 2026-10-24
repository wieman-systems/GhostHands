import XCTest
import simd
@testable import GhostHandsCore

final class EngineTests:XCTestCase {
    func testRodLengthAndCrankConnectionRemainExactAcrossCycle() {
        for i in 0...400 {
            let pose=EngineCycle.pose(stepID:"parts",progress:Double(i)/400)
            XCTAssertEqual(simd_distance(pose.pin,pose.piston),EngineCycle.rodLength,accuracy:0.000001)
            XCTAssertEqual(simd_distance(pose.pin,[0,EngineCycle.crankHeight,0]),EngineCycle.radius,accuracy:0.000001)
            XCTAssertEqual(pose.piston.x,0)
            XCTAssertTrue(pose.piston.y.isFinite)
        }
    }
    func testFourStrokesHaveCorrectMotionAndValves() {
        for (id,down) in [("intake",true),("compression",false),("power",true),("exhaust",false)] {
            let start=EngineCycle.pose(stepID:id,progress:0),end=EngineCycle.pose(stepID:id,progress:1),mid=EngineCycle.pose(stepID:id,progress:0.5)
            XCTAssertEqual(end.piston.y<start.piston.y,down)
            XCTAssertEqual(mid.inletOpen,id=="intake");XCTAssertEqual(mid.exhaustOpen,id=="exhaust")
            XCTAssertEqual(start.spark,id=="power")
        }
    }
    @MainActor func testEngineHasIndependentTimelineAndResumesWithoutRestarting() {
        let m=StudioModel(storage:FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("takes"))
        XCTAssertTrue(LessonCatalog.engine.isValid);XCTAssertTrue(LessonCatalog.engine.steps.allSatisfy{$0.segment==nil})
        m.immersive=true;m.placed=true;m.chooseLesson(LessonCatalog.engine.id);m.setStep(2)
        XCTAssertNil(m.selected);XCTAssertEqual(m.mode,.playing);XCTAssertFalse(m.video.command!.play)
        m.tick(now:100);m.tick(now:100.1);XCTAssertGreaterThan(m.elapsed,0)
        m.seek(3);m.playPause();XCTAssertEqual(m.elapsed,3);XCTAssertEqual(m.mode,.playing)
        m.elapsed=7.99;m.tick(now:100.2);XCTAssertEqual(m.mode,.paused);XCTAssertEqual(m.step,2)
        m.replayCurrent();XCTAssertEqual(m.elapsed,0);XCTAssertEqual(m.mode,.playing)
    }
    @MainActor func testReferenceVideoDoesNotDriveEngineTransportAndRecordingsKeepModel() {
        let m=StudioModel(storage:FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("takes"))
        m.immersive=true;m.placed=true;m.chooseLesson(LessonCatalog.engine.id);m.videoOpened()
        m.video.playing=true;let serial=m.video.command!.serial
        m.setStep(1);m.changeSpeed(1.5);m.toggleLoop();XCTAssertEqual(m.video.command!.serial,serial)
        m.seek(3);m.playPause();XCTAssertEqual(m.mode,.playing);XCTAssertEqual(m.elapsed,3)
        m.videoClosed();XCTAssertEqual(m.mode,.playing)
        var clip=IllustratedMotion.clip(step:0,side:LetterPaper.width);clip.isIllustration=false;clip.lessonID=LessonCatalog.engine.id;clip.lessonStep=1
        m.load(clip);XCTAssertTrue(m.showGuides);XCTAssertEqual(m.course.mechanicalModel,.engine)
        m.beginAuthoring(blank:true);XCTAssertNil(m.course.mechanicalModel)
    }
    func testMechanicalLessonsRoundTripAndOldLessonDecodes() throws {
        let e=JSONEncoder(),d=JSONDecoder()
        XCTAssertEqual(try d.decode(LessonDefinition.self,from:e.encode(LessonCatalog.engine)),LessonCatalog.engine)
        var json=try XCTUnwrap(JSONSerialization.jsonObject(with:e.encode(LessonCatalog.repair)) as? [String:Any]);json.removeValue(forKey:"mechanicalModel")
        XCTAssertNil(try d.decode(LessonDefinition.self,from:JSONSerialization.data(withJSONObject:json)).mechanicalModel)
    }
}
