import Foundation
import simd

struct AvatarRig: Decodable {
    let names:[String]
    let restTransforms:[[[Float]]]
    var rest:[simd_float4x4] {restTransforms.map {v in simd_float4x4(columns:(SIMD4(v[0]),SIMD4(v[1]),SIMD4(v[2]),SIMD4(v[3])))}}
}

/// Hands reproduce recorded joint positions across the paper. Arm bends and
/// wrist twist are reconstructed; no claim of recorded full-body motion.
enum AvatarRetargeting {
    static func point(_ m:simd_float4x4)->SIMD3<Float> {[m.columns.3.x,m.columns.3.y,m.columns.3.z]}
    static func mirrored(_ p:SIMD3<Float>,tableHeight:Float)->SIMD3<Float> {[-p.x,p.y+tableHeight,-p.z+0.45]}
    static func canReplay(frame:MotionFrame,rig:AvatarRig,tableHeight:Float)->Bool {
        let rest=rig.rest
        for (side,pose) in [("L",frame.left),("R",frame.right)] {
            guard let pose,pose.joints.count==25,pose.joints.allSatisfy({$0?.isFinite == true}),
                  let i=rig.names.firstIndex(of:"Bip01_\(side)_UpperArm"),i<rest.count else{return false}
            let d=simd_distance(mirrored(pose.joints[0]!,tableHeight:tableHeight),point(rest[i]))
            if d<=0.01 || d>=1.5 {return false}
        }
        return true
    }
    static func matrices(frame:MotionFrame,rig:AvatarRig,tableHeight:Float)->[simd_float4x4] {
        let rest=rig.rest
        guard rest.count==rig.names.count else{return rest}
        var result=rest
        let index=Dictionary(uniqueKeysWithValues:rig.names.enumerated().map {($1,$0)})
        func bone(_ name:String)->Int? {index[name.replacingOccurrences(of:" ",with:"_")]}
        func orient(_ i:Int,from a:SIMD3<Float>,to b:SIMD3<Float>,restEnd:SIMD3<Float>) {
            let source=restEnd-point(rest[i]),target=b-a
            guard simd_length(source)>0.0001,simd_length(target)>0.0001 else{return}
            let delta=simd_quatf(from:simd_normalize(source),to:simd_normalize(target))
            var m=simd_float4x4(delta)*rest[i]
            let scale=simd_length(target)/simd_length(source)
            // Flat skeleton joints explicitly carry world-space positions.
            // Stretch along the bone axis only, preserving limb and finger thickness.
            m.columns.1 *= scale
            m.columns.3=SIMD4(a,1);result[i]=m
        }
        for (side,pose) in [("L",frame.left),("R",frame.right)] {
            guard let pose,pose.isUsable,pose.joints.allSatisfy({$0 != nil}),
                  let shoulder=bone("Bip01 \(side) UpperArm"),let elbow=bone("Bip01 \(side) Forearm"),let wrist=bone("Bip01 \(side) Hand") else {continue}
            let targets=pose.joints.map {mirrored($0!,tableHeight:tableHeight)}
            let s=point(rest[shoulder]),w=targets[0],direction=w-s,d=simd_length(direction)
            guard d>0.01,d<1.5 else {continue}
            let axis=direction/d
            var bend=SIMD3<Float>(side=="L" ? 1 : -1,-0.4,-0.2)
            bend -= axis*simd_dot(bend,axis)
            if simd_length(bend)<0.001 {bend=[0,0,1]}
            bend=simd_normalize(bend)
            let upper=simd_distance(s,point(rest[elbow])),lower=simd_distance(point(rest[elbow]),point(rest[wrist]))
            let stretch=max(1,d/max(0.01,upper+lower)*1.015),a=upper*stretch,b=lower*stretch
            let along=(a*a-b*b+d*d)/(2*d),height=sqrt(max(0,a*a-along*along))
            let e=s+axis*along+bend*height
            orient(shoulder,from:s,to:e,restEnd:point(rest[elbow]))
            orient(elbow,from:e,to:w,restEnd:point(rest[wrist]))
            if let middle=bone("Bip01 \(side) Finger2") {orient(wrist,from:w,to:targets[11],restEnd:point(rest[middle]))}
            for finger in 0..<5 {
                let joints = finger==0 ? [1,2,3,4] : [6+(finger-1)*5,7+(finger-1)*5,8+(finger-1)*5,9+(finger-1)*5]
                for segment in 0..<3 {
                    let name="Bip01 \(side) Finger\(finger)"+(segment==0 ? "" : String(segment))
                    guard let i=bone(name) else{continue}
                    let end:SIMD3<Float>
                    if segment<2,let next=bone("Bip01 \(side) Finger\(finger)\(segment+1)") {end=point(rest[next])}
                    else {
                        // Blender bone-local +Y is the bone direction; distal length
                        // comes from the actual tracked segment, without a fabricated tip joint.
                        end=point(rest[i])+simd_normalize(SIMD3(rest[i].columns.1.x,rest[i].columns.1.y,rest[i].columns.1.z))*0.02
                    }
                    orient(i,from:targets[joints[segment]],to:targets[joints[segment+1]],restEnd:end)
                }
            }
        }
        return result
    }
}
