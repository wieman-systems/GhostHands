import XCTest
@testable import GhostHandsCore

final class ReferenceVideoTests:XCTestCase {
    @MainActor func model()->StudioModel {
        let m=StudioModel(storage:FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("takes"));m.immersive=true;m.placed=true;return m
    }
    @MainActor func testEveryLessonCanOpenVideoIncludingEmptyReferences() {
        let m=model()
        for lesson in LessonCatalog.all {m.chooseLesson(lesson.id);m.showVideo();XCTAssertTrue(m.dockedVideo);m.dockedVideo=false}
        m.chooseLesson(LessonCatalog.jet.id);XCTAssertTrue(m.hasReferenceVideo);XCTAssertFalse(m.canSyncVideo)
        m.videoOpened();XCTAssertTrue(m.video.command!.play);XCTAssertNil(m.video.command!.end)
    }
    @MainActor func testCustomVideoOnBoatNeverInheritsOrigamiTimestamps() {
        let m=model();m.videoOpened();XCTAssertTrue(m.linkedVideo)
        XCTAssertTrue(m.setReferenceVideo("https://youtu.be/kz5kv0RfeUc?t=42"))
        XCTAssertFalse(m.linkedVideo);XCTAssertNil(m.video.command!.end);XCTAssertEqual(m.video.command!.start,42)
        let serial=m.video.command!.serial
        m.setStep(9);m.replayCurrent();m.seek(2);m.changeSpeed(2);m.toggleLoop()
        XCTAssertEqual(m.video.command!.serial,serial)
        m.useLessonReference();XCTAssertTrue(m.linkedVideo);XCTAssertEqual(m.video.command!.start,123);XCTAssertEqual(m.video.command!.end,134)
    }
    @MainActor func testIndependentTransportAndErrorCannotPauseModel() {
        let m=model();m.chooseLesson(LessonCatalog.jet.id);m.videoOpened();m.loops=true
        m.video.playing=true;m.pauseVideo();XCTAssertEqual(m.mode,.playing)
        m.video.playing=true;m.video.buffering=false;m.video.waiting=false
        let serial=m.video.command!.serial;m.playPause();XCTAssertEqual(m.mode,.paused);XCTAssertEqual(m.video.command!.serial,serial)
        m.mode = .playing;m.failVideo("Network interrupted");XCTAssertEqual(m.mode,.playing)
        m.videoClosed();XCTAssertEqual(m.mode,.playing)
    }
    @MainActor func testSyncToggleRemovesAndRestoresBoundary() {
        let m=model();m.videoOpened();m.video.playing=true;m.video.currentTime=25
        m.setVideoSync(false);XCTAssertNil(m.video.command!.end);XCTAssertFalse(m.video.command!.seek);XCTAssertEqual(m.video.command!.rate,1)
        m.setStep(9);m.setVideoSync(true);XCTAssertEqual(m.video.command!.start,123);XCTAssertEqual(m.video.command!.end,134)
        XCTAssertTrue(m.video.command!.seek)
    }
    @MainActor func testLeavingTimedStepClearsOldBoundaryWithoutSeeking() {
        let m=model();var lesson=LessonCatalog.boat;lesson.id="mixed-timing";lesson.steps[1].segment=nil;m.customLessons=[lesson]
        m.chooseLesson(lesson.id);m.videoOpened();m.video.playing=true;m.loops=true
        XCTAssertNotNil(m.video.command!.end);m.setStep(1)
        XCTAssertNil(m.video.command!.end);XCTAssertFalse(m.video.command!.seek);XCTAssertFalse(m.video.command!.loop);XCTAssertEqual(m.video.command!.rate,1)
    }
    @MainActor func testEmptyLessonClearsAudioActivityAndAllowsNarration() {
        let m=model();m.chooseLesson(LessonCatalog.jet.id);m.videoOpened();m.video.playing=true
        m.chooseLesson(LessonCatalog.pump.id)
        XCTAssertTrue(m.video.visible);XCTAssertNil(m.video.command);XCTAssertFalse(m.video.audioBusy);XCTAssertTrue(m.automaticNarrationAllowed)
    }
    @MainActor func testCrossLessonRecordingLoadsCorrectIndependentReference() {
        let m=model();m.chooseLesson(LessonCatalog.engine.id);m.videoOpened()
        var take=IllustratedMotion.clip(step:0,side:LetterPaper.width);take.isIllustration=false;take.lessonID=LessonCatalog.jet.id;take.lessonStep=0
        m.load(take);XCTAssertEqual(m.video.command!.videoID,"kz5kv0RfeUc");XCTAssertNil(m.video.command!.end)
    }
    @MainActor func testReferencesPersistPerLessonAndInvalidInputDoesNotReplaceThem() {
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {try? FileManager.default.removeItem(at:folder)}
        let storage=folder.appendingPathComponent("takes"),m=StudioModel(storage:storage)
        m.chooseLesson(LessonCatalog.pump.id);XCTAssertTrue(m.setReferenceVideo(StudioModel.turbineVideo))
        XCTAssertFalse(m.setReferenceVideo("https://example.com/video"));XCTAssertTrue(m.referenceURL.contains("kz5kv0RfeUc"))
        let restored=StudioModel(storage:storage);restored.chooseLesson(LessonCatalog.pump.id)
        XCTAssertEqual(restored.referenceURL,m.referenceURL);restored.chooseLesson(LessonCatalog.boat.id)
        XCTAssertEqual(restored.referenceURL,LessonCatalog.boat.videoURL)
    }
}
