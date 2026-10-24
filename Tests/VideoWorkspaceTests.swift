import XCTest
import simd
@testable import GhostHandsCore

final class VideoWorkspaceTests:XCTestCase {
    @MainActor func testVideoMovementIsIndependentGuardedAndRetainedAcrossSteps() {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {try? FileManager.default.removeItem(at:root)}
        let m=StudioModel(storage:root.appendingPathComponent("takes"));m.placed=true;m.immersive=true;m.dockedVideo=true
        let workspace=m.workspace,initial=m.videoPosition
        m.moveVideo(to:[0.4,0.7,-1]);XCTAssertEqual(m.videoPosition,initial)
        m.movingVideo=true;m.moveVideo(to:[0.4,0.7,-1]);XCTAssertEqual(m.videoPosition,[0.4,0.7,-1])
        XCTAssertEqual(m.workspace,workspace)
        m.setStep(2);XCTAssertEqual(m.videoPosition,[0.4,0.7,-1])
        m.moveVideo(to:[.nan,0,0]);m.moveVideo(to:[10,0,0]);XCTAssertEqual(m.videoPosition,[0.4,0.7,-1])
        m.interactionActive=false;m.moveVideo(to:[0,0,0]);XCTAssertEqual(m.videoPosition,[0.4,0.7,-1])
        m.resetVideoPosition();XCTAssertEqual(m.videoPosition,[0,0.30,-0.29]);XCTAssertFalse(m.movingVideo)
    }
    @MainActor func testVideoOnlyAndMoveDoNotReloadOrSeekPlayer() {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {try? FileManager.default.removeItem(at:root)}
        let m=StudioModel(storage:root.appendingPathComponent("takes"));m.placed=true;m.immersive=true;m.showVideo();m.videoOpened()
        let generation=m.video.playerGeneration,command=m.video.command
        m.toggleVideoOnly();XCTAssertTrue(m.videoOnly);XCTAssertGreaterThanOrEqual(m.videoScale,0.85)
        m.movingVideo=true;m.moveVideo(to:[0.3,0.4,-0.5]);m.toggleVideoOnly()
        XCTAssertEqual(m.video.playerGeneration,generation);XCTAssertEqual(m.video.command,command)
        m.closeReference();XCTAssertFalse(m.movingVideo);XCTAssertFalse(m.dockedVideo);XCTAssertFalse(m.video.visible)
    }
    func testContinuousPaperVerticesFitReusableBufferAcrossEveryStep() {
        for step in PaperStep.all {
            for width:Float in [0.05,LetterPaper.width,0.5] {
                for frame in 0...180 {
                    let vertices=PaperMotion.vertices(step:step,progress:Float(frame)/180,width:width)
                    XCTAssertLessThanOrEqual(vertices.count,256);XCTAssertEqual(vertices.count%3,0)
                    XCTAssertTrue(vertices.allSatisfy{$0.isFinite && abs($0.x)<=1 && abs($0.y)<=1 && abs($0.z)<=1})
                }
            }
        }
        let step=PaperStep.all[0]
        let a=PaperMotion.vertices(step:step,progress:0.501,width:LetterPaper.width)
        let b=PaperMotion.vertices(step:step,progress:0.502,width:LetterPaper.width)
        XCTAssertNotEqual(a,b)
    }
}
