import XCTest
import simd
@testable import GhostHandsCore

final class TutorialGeometryTests: XCTestCase {
    let width=LetterPaper.width
    func mesh(_ step:Int,_ t:Float)->[SIMD3<Float>] {PaperMotion.vertices(step:PaperStep.all[step],progress:t,width:width)}
    func testFlipNeverPassesThroughTableAndStartsFromPreviousFold() {
        for step in [6,12] {
            XCTAssertEqual(mesh(step,0),mesh(step-1,1))
            for i in 0...60 {
                XCTAssertTrue(mesh(step,Float(i)/60).allSatisfy {$0.y >= -0.00001},"Flip \(step), frame \(i) went below table")
            }
        }
    }
    func testFrontOnlyFoldRetainsUnfoldedBackTip() {
        for (step,z) in [(5,Float(1)),(11,Float(0.65))] {
            let end=mesh(step,1)
            XCTAssertTrue(end.contains {abs($0.z-z*LetterPaper.height/2)<0.00001 && abs($0.y)<0.00001})
            XCTAssertGreaterThan(end.count,3)
        }
    }
    func testPocketStartsWithPreviousShapeAndEndsAtFlattenStart() {
        for step in [9,14] {
            XCTAssertEqual(mesh(step,0),mesh(step-1,1))
            XCTAssertEqual(mesh(step,1),mesh(step+1,0))
            XCTAssertNotEqual(mesh(step,0),mesh(step,1))
        }
    }
    func testWrapAndHullActuallyAnimateAndHullStartsAtBoat() {
        XCTAssertNotEqual(mesh(8,0),mesh(8,1))
        XCTAssertEqual(mesh(17,0),mesh(16,1))
        XCTAssertNotEqual(mesh(17,0),mesh(17,1))
        XCTAssertGreaterThan(mesh(17,1).map {abs($0.z)}.max()!,mesh(17,0).map {abs($0.z)}.max()!)
    }
    func testFlattenHandsNeverConvergeOnOneContact() throws {
        for step in [10,15] {
            for i in 0...30 {
                let contacts=try XCTUnwrap(PaperMotion.handContacts(step:PaperStep.all[step],progress:Float(i)/30,width:width))
                XCTAssertGreaterThanOrEqual(simd_distance(contacts.0,contacts.1),0.035)
            }
        }
    }
}
