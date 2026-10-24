import XCTest
@testable import GhostHandsCore

final class LessonTests:XCTestCase {
    @MainActor func model()->StudioModel {StudioModel(storage:FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("Recordings"))}
    func testCatalogsMatchSourcesAndHaveOrderedValidSegments() {
        for course in [LessonCatalog.boat,LessonCatalog.repair] {
            XCTAssertTrue(course.isValid)
            var end=0.0
            for step in course.steps {XCTAssertNotNil(step.segment);XCTAssertGreaterThanOrEqual(step.segment!.start,end);end=step.segment!.end}
        }
        XCTAssertEqual(LessonCatalog.boat.steps[3].title,"Fold the right corner")
        XCTAssertTrue(LessonCatalog.repair.steps.allSatisfy{$0.paperIndex==nil && $0.cue?.isValid==true})
    }
    func testVoiceRequiresExactCommandsAndWakeWordDuringVideo() {
        XCTAssertEqual(VoiceCommands.parse("Next, please!"),.next)
        XCTAssertEqual(VoiceCommands.parse("slow down"),.slower)
        XCTAssertEqual(VoiceCommands.parse("show that again"),.replay)
        XCTAssertNil(VoiceCommands.parse("next door"))
        XCTAssertNil(VoiceCommands.parse("Next",videoAudible:true))
        XCTAssertEqual(VoiceCommands.parse("Ghost Hands, next step",videoAudible:true),.next)
        XCTAssertEqual(VoiceCommands.parse("GhostHands show that again",videoAudible:true),.replay)
    }
    @MainActor func testRapidNavigationRejectsOldVideoUpdates() {
        let m=model();m.immersive=true;m.placed=true;m.videoOpened();m.setStep(1)
        let old=m.video.command!;m.setStep(9);let now=m.video.command!
        m.acceptVideo(serial:old.serial,id:old.videoID,time:32,duration:264,state:1,rate:1,ended:false)
        XCTAssertNotEqual(m.video.acknowledgedSerial,old.serial);XCTAssertEqual(m.elapsed,0)
        let segment=m.currentStep.segment!
        m.acceptVideo(serial:now.serial,id:now.videoID,time:segment.start+segment.duration/2,duration:264,state:1,rate:1,ended:false)
        XCTAssertEqual(m.elapsed,m.progressDuration/2,accuracy:0.001)
        m.tick(now:100);m.tick(now:100.1);XCTAssertEqual(m.elapsed,m.progressDuration/2,accuracy:0.001)
        XCTAssertEqual(m.step,9)
    }
    @MainActor func testSegmentEndNarratesOnceAndDoesNotAdvance() {
        let m=model();m.immersive=true;m.placed=true;m.videoOpened();m.setStep(4)
        let command=m.video.command!;let revision=m.narrationRevision
        for _ in 0..<5 {m.acceptVideo(serial:command.serial,id:command.videoID,time:m.currentStep.segment!.end,duration:264,state:2,rate:1,ended:true)}
        XCTAssertEqual(m.narrationRevision,revision+1);XCTAssertEqual(m.step,4);XCTAssertEqual(m.mode,.paused);XCTAssertFalse(m.video.audioBusy)
        m.replayCurrent();XCTAssertGreaterThan(m.video.command!.serial,command.serial);XCTAssertTrue(m.video.command!.seek);XCTAssertEqual(m.video.command!.start,m.currentStep.segment!.start)
    }
    @MainActor func testVoiceNavigationClampsSpeedAndHonorsRecordingGuard() {
        let m=model();m.immersive=true;m.placed=true;m.applyVoice(.next);XCTAssertEqual(m.step,1)
        for _ in 0..<20 {m.applyVoice(.slower)};XCTAssertEqual(m.speed,0.25)
        for _ in 0..<20 {m.applyVoice(.faster)};XCTAssertEqual(m.speed,2)
        m.mode = .recording;m.applyVoice(.next);XCTAssertEqual(m.step,1)
    }
    @MainActor func testAuthoredMarkersSurviveExportAndReload() throws {
        let m=model();m.chooseLesson(LessonCatalog.repair.id);m.beginAuthoring(blank:false)
        let cue=SpatialCue(label:"My cover",from:[0.1,0.02,0],to:[0.2,0.02,0])
        m.cueOverrides[m.cueKey]=cue
        XCTAssertEqual(m.exportLesson.steps[0].cue,cue)
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:dir)}
        try LessonStorage.save(m.exportLesson,in:dir)
        XCTAssertEqual(LessonStorage.load(in:dir).first?.steps[0].cue,cue)
        m.saveDraft();XCTAssertFalse(m.isAuthoring);XCTAssertEqual(m.course.steps[0].cue,cue)
    }
    @MainActor func testAuthorNavigationSeeksPausedAndOfflineFailureReleasesNarration() {
        let m=model();m.immersive=true;m.placed=true;m.videoOpened();m.beginAuthoring(blank:false)
        m.setStep(9);XCTAssertEqual(m.mode,.paused);XCTAssertFalse(m.video.command!.play)
        XCTAssertEqual(m.video.command!.start,123);XCTAssertNil(m.video.command!.end)
        m.video.fail("Offline");XCTAssertFalse(m.video.audioBusy);XCTAssertFalse(m.linkedVideo)
        m.cancelDraft();m.setStep(1);m.replayCurrent();XCTAssertFalse(m.video.waiting);XCTAssertFalse(m.video.audioBusy);XCTAssertEqual(m.video.status,"Offline")
    }
    func testCustomRecordingSupportsHundredStepLessons() throws {
        var clip=IllustratedMotion.clip(step:0,side:LetterPaper.width)
        clip.isIllustration=false;clip.lessonID="my-lesson";clip.lessonStep=99
        XCTAssertNoThrow(try clip.validated())
        clip.lessonStep=100;XCTAssertThrowsError(try clip.validated())
    }
    func testInvalidLessonsCannotEscapeStorageOrAcceptBrokenCues() {
        var lesson=LessonCatalog.repair;lesson.id="../../escape";XCTAssertFalse(lesson.isValid)
        lesson=LessonCatalog.repair;lesson.steps[0].segment = .init(start:20,end:10);XCTAssertFalse(lesson.isValid)
        lesson=LessonCatalog.repair;lesson.steps[0].cue?.from=[1,2];XCTAssertFalse(lesson.isValid)
        lesson=LessonCatalog.repair;lesson.steps[1].id=lesson.steps[0].id;XCTAssertFalse(lesson.isValid)
    }
    @MainActor func testLegacyBoatTakeUsesReorderedLessonStep() {
        let m=model();var clip=IllustratedMotion.clip(step:8,side:LetterPaper.width);clip.isIllustration=false
        m.load(clip);XCTAssertEqual(m.currentStep.id,"boat-8");XCTAssertEqual(m.step,10);XCTAssertEqual(m.selected?.id,clip.id)
    }
}
