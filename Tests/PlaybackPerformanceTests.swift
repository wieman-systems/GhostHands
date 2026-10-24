import XCTest
@testable import GhostHandsCore

final class PlaybackPerformanceTests:XCTestCase {
    @MainActor func testCatalogLookupTracksCustomEditsAndAuthorDraft() {
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {try? FileManager.default.removeItem(at:folder)}
        let m=StudioModel(storage:folder.appendingPathComponent("takes"))
        XCTAssertEqual(LessonCatalog.valid,LessonCatalog.all.filter(\.isValid))
        var custom=LessonCatalog.boat;custom.id="custom-boat";m.customLessons=[custom];m.activeLessonID=custom.id
        XCTAssertEqual(m.course,custom)
        m.customLessons[0].steps[0].title="Edited step"
        XCTAssertEqual(m.currentStep.title,"Edited step")
        m.draft=custom;m.isAuthoring=true;m.draft?.steps[0].title="Live draft"
        XCTAssertEqual(m.currentStep.title,"Live draft")
        m.isAuthoring=false;m.activeLessonID="missing";XCTAssertEqual(m.course,LessonCatalog.boat)
    }
    @MainActor func testVideoProjectionFillsCallbackGapsAndStopsAtBoundaries() {
        let v=VideoSession();v.visible=true
        v.request(videoID:"vNba3jbBSOw",segment:.init(start:20,end:30),play:true,rate:0.75)
        XCTAssertNil(v.projectedTime(at:100))
        XCTAssertTrue(v.receive(serial:v.command!.serial,videoID:"vNba3jbBSOw",time:22,duration:200,state:1,rate:0.75,now:100))
        XCTAssertEqual(v.projectedTime(at:100.1)!,22.075,accuracy:0.00001)
        XCTAssertEqual(v.projectedTime(at:110)!,22.225,accuracy:0.00001)
        _ = v.receive(serial:v.command!.serial,videoID:"vNba3jbBSOw",time:29.95,duration:200,state:1,rate:1,now:101)
        XCTAssertEqual(v.projectedTime(at:101.2),30)
        for state in [2,3,0] {
            _ = v.receive(serial:v.command!.serial,videoID:"vNba3jbBSOw",time:25,duration:200,state:state,rate:1,now:102)
            XCTAssertNil(v.projectedTime(at:102.1))
        }
    }
    @MainActor func testNewCommandsAndStaleCallbacksCannotAdvanceOldMotion() {
        let v=VideoSession();v.visible=true
        v.request(videoID:"vNba3jbBSOw",segment:.init(start:20,end:30),play:true,rate:1)
        let old=v.command!.serial
        _ = v.receive(serial:old,videoID:"vNba3jbBSOw",time:22,duration:200,state:1,rate:1,now:100)
        v.request(videoID:"vNba3jbBSOw",segment:.init(start:40,end:50),play:true,rate:1)
        XCTAssertNil(v.projectedTime(at:100.1))
        XCTAssertFalse(v.receive(serial:old,videoID:"vNba3jbBSOw",time:23,duration:200,state:1,rate:1,now:100.2))
        XCTAssertNil(v.projectedTime(at:100.3))
        _ = v.receive(serial:v.command!.serial,videoID:"vNba3jbBSOw",time:40,duration:200,state:1,rate:1,now:101)
        XCTAssertEqual(v.projectedTime(at:101.1)!,40.1,accuracy:0.00001)
        v.request(videoID:"vNba3jbBSOw",segment:.init(start:40,end:50),seek:false,play:false,rate:1)
        XCTAssertNil(v.projectedTime(at:101.2))
        _ = v.receive(serial:v.command!.serial,videoID:"vNba3jbBSOw",time:40.1,duration:200,state:2,rate:1,now:101.3)
        XCTAssertNil(v.projectedTime(at:101.4))
        // A native YouTube Play click is authoritative after our Pause is acknowledged.
        _ = v.receive(serial:v.command!.serial,videoID:"vNba3jbBSOw",time:40.1,duration:200,state:1,rate:1,now:102)
        XCTAssertEqual(v.projectedTime(at:102.1)!,40.2,accuracy:0.00001)
        v.close();XCTAssertNil(v.projectedTime(at:102.2))
    }
    @MainActor func testLinkedHandsAdvanceBetweenSnapshotsWithoutChangingIndependentPlayback() {
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {try? FileManager.default.removeItem(at:folder)}
        let m=StudioModel(storage:folder.appendingPathComponent("takes"));m.immersive=true;m.placed=true;m.setStep(0);m.videoOpened()
        let c=m.video.command!,start=m.currentStep.segment!.start
        m.acceptVideo(serial:c.serial,id:c.videoID,time:start+1,duration:200,state:1,rate:0.75,ended:false,now:100)
        let before=m.elapsed;m.tick(now:100.1)
        XCTAssertGreaterThan(m.elapsed,before)
        XCTAssertEqual(m.elapsed,m.currentStep.segment!.progress(at:start+1.075)*m.progressDuration,accuracy:0.00001)
        m.pauseVideo();let held=m.elapsed;m.tick(now:100.2);XCTAssertEqual(m.elapsed,held)
        m.chooseLesson(LessonCatalog.jet.id);m.mode = .playing;m.loops=true
        m.tick(now:101);let independent=m.elapsed;m.tick(now:101.016)
        XCTAssertGreaterThan(m.elapsed,independent)
    }
    @MainActor func testVideoPlayRestartsCompletedLinkedStep() {
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {try? FileManager.default.removeItem(at:folder)}
        let m=StudioModel(storage:folder.appendingPathComponent("takes"));m.immersive=true;m.placed=true;m.setStep(0);m.videoOpened()
        let c=m.video.command!,segment=m.currentStep.segment!
        m.acceptVideo(serial:c.serial,id:c.videoID,time:segment.end,duration:200,state:2,rate:1,ended:true,now:100)
        m.toggleReferencePlayback()
        XCTAssertTrue(m.video.command!.seek);XCTAssertTrue(m.video.command!.play)
        XCTAssertEqual(m.video.command!.start,segment.start);XCTAssertEqual(m.mode,.playing)
    }
    @MainActor func testDisplayClockDoesNotQuantizeRecordedHandSampling() {
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {try? FileManager.default.removeItem(at:folder)}
        let m=StudioModel(storage:folder.appendingPathComponent("takes"));m.placed=true;m.immersive=true
        var clip=IllustratedMotion.clip(step:0,side:LetterPaper.width);clip.isIllustration=false;m.load(clip)
        m.mode = .playing;m.loops=true;m.speed=1
        var previous = -1.0,displayChanges=0,rendered:[Double]=[]
        m.onRender={frame,_,_ in if let frame {rendered.append(frame.time)}}
        for i in 0..<60 {
            m.tick(now:100+Double(i)/60)
            if m.displayedElapsed != previous {displayChanges += 1;previous=m.displayedElapsed}
        }
        XCTAssertEqual(rendered.count,60);XCTAssertGreaterThan(Set(rendered).count,55)
        XCTAssertLessThanOrEqual(displayChanges,11);XCTAssertGreaterThan(displayChanges,8)
    }
}
