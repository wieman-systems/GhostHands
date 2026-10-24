import XCTest
import simd
@testable import GhostHandsCore

final class AvatarTests:XCTestCase {
    func rig() throws ->AvatarRig {
        let url=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("GhostHands/AvatarResources/HumanReplay.json")
        return try JSONDecoder().decode(AvatarRig.self,from:Data(contentsOf:url))
    }
    func testIncompleteAndUnreachableHandsHideReplay() throws {
        let r=try rig()
        let hand=IllustratedMotion.hand(at:[0,0,0],left:false,curl:0.1)
        XCTAssertTrue(AvatarRetargeting.canReplay(frame:.init(time:0,left:hand,right:hand),rig:r,tableHeight:0.8))
        XCTAssertFalse(AvatarRetargeting.canReplay(frame:.init(time:0,left:nil,right:hand),rig:r,tableHeight:0.8))
        let far=IllustratedMotion.hand(at:[3,0,0],left:false,curl:0.1)
        XCTAssertFalse(AvatarRetargeting.canReplay(frame:.init(time:0,left:hand,right:far),rig:r,tableHeight:0.8))
    }
    func testRealAssetRigHasValidHandMappingAndMirroredWristTargets() throws {
        let r=try rig();XCTAssertEqual(r.names.count,80)
        let left=IllustratedMotion.hand(at:[-0.05,0.02,0],left:true,curl:0.12)
        let right=IllustratedMotion.hand(at:[0.05,0.02,0],left:false,curl:0.12)
        let matrices=AvatarRetargeting.matrices(frame:.init(time:0,left:left,right:right),rig:r,tableHeight:0.8)
        XCTAssertEqual(matrices.count,r.names.count)
        for m in matrices {XCTAssertTrue((0..<4).allSatisfy {i in (0..<4).allSatisfy {m[i][$0].isFinite}})}
        for (side,pose) in [("L",left),("R",right)] {
            let i=try XCTUnwrap(r.names.firstIndex(of:"Bip01_\(side)_Hand"))
            XCTAssertLessThan(simd_distance(AvatarRetargeting.point(matrices[i]),AvatarRetargeting.mirrored(pose.joints[0]!,tableHeight:0.8)),0.00001)
            for finger in 0..<5 {
                let k=try XCTUnwrap(r.names.firstIndex(of:"Bip01_\(side)_Finger\(finger)"))
                let j=finger==0 ? 1 : 6+(finger-1)*5
                XCTAssertLessThan(simd_distance(AvatarRetargeting.point(matrices[k]),AvatarRetargeting.mirrored(pose.joints[j]!,tableHeight:0.8)),0.00001)
            }
        }
    }
}
