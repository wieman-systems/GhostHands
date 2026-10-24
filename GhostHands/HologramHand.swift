import RealityKit
import UIKit
import simd

@MainActor final class HologramHand {
    let root=Entity()
    private var bones:[ModelEntity]=[]
    private var joints:[ModelEntity]=[]
    func load(side:String,opacity:Float=0.32) async throws {
        func material(_ alpha:Float)->UnlitMaterial {
            var m=UnlitMaterial(color:.white)
            m.blending = .transparent(opacity:.init(floatLiteral:alpha));return m
        }
        for _ in HandLayout.bones {
            let bone=ModelEntity(mesh:.generateCylinder(height:1,radius:0.003),materials:[material(opacity)])
            bones.append(bone);root.addChild(bone)
        }
        for _ in HandLayout.names {
            let joint=ModelEntity(mesh:.generateSphere(radius:0.004),materials:[material(0.22)])
            joints.append(joint);root.addChild(joint)
        }
        root.isEnabled=false
    }
    func update(_ pose:HandPose?) {
        guard let pose,pose.isUsable else {root.isEnabled=false;return}
        root.isEnabled=true
        for (i,joint) in joints.enumerated() {
            joint.isEnabled=pose.joints[i] != nil
            if let point=pose.joints[i] {joint.position=point}
        }
        for (i,pair) in HandLayout.bones.enumerated() {
            let bone=bones[i]
            guard let a=pose.joints[pair.0],let b=pose.joints[pair.1],simd_distance(a,b)>0.0001 else {bone.isEnabled=false;continue}
            bone.isEnabled=true;bone.position=(a+b)/2;bone.scale=[1,simd_distance(a,b),1]
            bone.orientation=simd_quatf(from:[0,1,0],to:simd_normalize(b-a))
        }
    }
}
