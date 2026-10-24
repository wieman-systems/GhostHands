import XCTest
import simd
@testable import GhostHandsCore

final class MechanismAndVideoTests:XCTestCase {
    @MainActor func model()->StudioModel {
        let m=StudioModel(storage:FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("takes"))
        m.placed=true;m.immersive=true;m.dockedVideo=true;m.movingVideo=true;return m
    }
    @MainActor func testVideoFacesHeadInRotatedWorkspaceAndStaysLockedAfterDone() {
        let m=model();m.position=[0.5,0.8,-0.5];m.yaw = .pi/3
        let workspace=m.workspace;m.moveVideo(to:[-0.5,0.4,-0.7])
        let head=SIMD3<Float>(0,1.6,0.2);m.faceVideo(toward:head)
        let q=simd_quatf(angle:m.videoYaw,axis:[0,1,0])*simd_quatf(angle:m.videoPitch,axis:[1,0,0])
        let local=simd_inverse(workspace)*SIMD4(head,1)
        let expected=simd_normalize(SIMD3(local.x,local.y,local.z)-m.videoPosition)
        XCTAssertGreaterThan(simd_dot(simd_act(q,[0,0,1]),expected),0.99999)
        XCTAssertEqual(m.workspace,workspace)
        let yaw=m.videoYaw,pitch=m.videoPitch;m.movingVideo=false;m.faceVideo(toward:[2,2,2])
        XCTAssertEqual(m.videoYaw,yaw);XCTAssertEqual(m.videoPitch,pitch)
    }
    @MainActor func testVerticalFacingIsStableAndRejectsInvalidHead() {
        let m=model();m.position = .zero;m.yaw=0;m.moveVideo(to:.zero);m.videoYaw=0.8
        m.faceVideo(toward:[0.001,1,0.001]);XCTAssertEqual(m.videoYaw,0.8)
        m.faceVideo(toward:[-0.001,1,-0.001]);XCTAssertEqual(m.videoYaw,0.8)
        let pitch=m.videoPitch;m.faceVideo(toward:[.nan,0,0]);XCTAssertEqual(m.videoPitch,pitch)
        m.faceVideo(toward:[0.001,0,0]);XCTAssertEqual(m.videoPitch,pitch)
    }
    @MainActor func testPinchScaleIsBoundedAndCannotAffectWorkspace() {
        let m=model(),workspace=mWorkspaceFixture()
        m.position=workspace;m.resizeVideo(to:0.8);XCTAssertEqual(m.videoScale,0.8)
        m.resizeVideo(to:100);XCTAssertEqual(m.videoScale,1.4)
        m.resizeVideo(to:0.01);XCTAssertEqual(m.videoScale,0.35)
        m.resizeVideo(to:.nan);XCTAssertEqual(m.videoScale,0.35)
        m.movingVideo=false;m.resizeVideo(to:1);XCTAssertEqual(m.videoScale,0.35)
        XCTAssertEqual(m.position,workspace)
    }
    private func mWorkspaceFixture()->SIMD3<Float> {[0.3,0.8,-0.5]}
    func testCrankRodLengthStrokeAndCamTravel() {
        var minX=Float.infinity,maxX = -Float.infinity
        for i in 0...720 {
            let angle=Float(i)*2*Float.pi/720,state=MechanismMotion.crank(angle)
            XCTAssertEqual(simd_length(state.slider-state.pin),MechanismMotion.rodLength,accuracy:0.000001)
            XCTAssertEqual(state.slider.y,0);minX=min(minX,state.slider.x);maxX=max(maxX,state.slider.x)
            XCTAssertTrue((0.033-0.00001...0.057+0.00001).contains(MechanismMotion.camTop(angle)))
        }
        XCTAssertEqual(maxX-minX,2*MechanismMotion.crankRadius,accuracy:0.000001)
    }
    func testBeltPathIsClosedContinuousAndTangentAtStraightRuns() {
        let points=(0...1000).map{MechanismMotion.beltPoint(Float($0)/1000)}
        XCTAssertLessThan(simd_distance(points.first!,points.last!),0.000001)
        for i in 1..<points.count {XCTAssertLessThan(simd_distance(points[i-1],points[i]),0.001)}
        let a=MechanismMotion.tangentAngle,n=SIMD3<Float>(cos(a),sin(a),0)
        let small=SIMD3<Float>(-0.095,0,0)+n*MechanismMotion.smallRadius
        let large=SIMD3<Float>(0.095,0,0)+n*MechanismMotion.largeRadius
        XCTAssertEqual(simd_dot(large-small,n),0,accuracy:0.000001)
        XCTAssertEqual(2*MechanismMotion.smallRadius,MechanismMotion.largeRadius)
    }
    @MainActor func testNewLessonsHaveDistinctRelevantIndependentReferencesAndLoop() {
        let m=model();let lessons=[LessonCatalog.cam,LessonCatalog.belt,LessonCatalog.crank]
        XCTAssertEqual(Set(lessons.map(\.videoURL)).count,3)
        for lesson in lessons {
            XCTAssertTrue(lesson.isValid);XCTAssertEqual(lesson.steps.count,3)
            m.chooseLesson(lesson.id);XCTAssertTrue(m.loops);m.videoOpened()
            XCTAssertEqual(m.video.command?.videoID,YouTubeLink(lesson.videoURL)?.videoID)
            XCTAssertNil(m.video.command?.end);XCTAssertFalse(m.canSyncVideo)
        }
    }
}
