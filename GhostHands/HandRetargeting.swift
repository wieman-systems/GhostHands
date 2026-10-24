import Foundation
import simd

struct HandRigSpec: Decodable {
    let names: [String]
    let restTransforms: [[[Double]]]
    var rest: [simd_float4x4] { restTransforms.map { rows in
        simd_float4x4(columns: (SIMD4(rows[0].map(Float.init)),SIMD4(rows[1].map(Float.init)),SIMD4(rows[2].map(Float.init)),SIMD4(rows[3].map(Float.init))))
    }}
}

enum HandRetargeting {
    static func point(_ m: simd_float4x4) -> SIMD3<Float> { [m.columns.3.x,m.columns.3.y,m.columns.3.z] }
    static func basis(_ points: [SIMD3<Float>]) -> simd_float3x3? {
        guard points.count >= 25 else { return nil }
        let forward = points[11]-points[0], across = points[6]-points[21]
        guard simd_length(forward)>0.025, simd_length(across)>0.025 else { return nil }
        let x=simd_normalize(forward), normal=simd_cross(x,across)
        guard simd_length(normal)>0.01 else { return nil }
        let y=simd_normalize(normal), z=simd_normalize(simd_cross(x,y))
        return simd_float3x3(columns:(x,y,z))
    }
    static func matrices(pose: HandPose, rest: [simd_float4x4]) -> [simd_float4x4]? {
        // A continuous skin cannot safely bridge missing fingers. Hide this hand
        // until all recorded joints are valid instead of inventing a finger pose.
        guard pose.isUsable, rest.count==27, pose.joints.allSatisfy({$0 != nil}) else { return nil }
        let target=pose.joints.map {$0!}, source=rest.map(point)
        guard let from=basis(source), let to=basis(target) else { return nil }
        let palm=simd_quatf(to * from.transpose)
        let width=simd_distance(target[6],target[21])/simd_distance(source[6],source[21])
        guard width.isFinite, (0.4...2).contains(width) else { return nil }
        let nexts=[0:11,1:2,2:3,3:4,5:6,6:7,7:8,8:9,10:11,11:12,12:13,13:14,15:16,16:17,17:18,18:19,20:21,21:22,22:23,23:24]
        var result=[simd_float4x4]()
        for i in 0..<27 {
            var rotation=palm * simd_quatf(rest[i])
            var scale=SIMD3<Float>(repeating:width)
            var position=i<25 ? target[i] : target[0]+simd_act(palm,source[i])*width
            if i==25 { position=target[0] }
            if let n=nexts[i], i != 0 {
                let a=source[n]-source[i], b=target[n]-target[i]
                guard simd_length(a)>0.001, simd_length(b)>0.001 else { return nil }
                rotation=simd_quatf(from:simd_normalize(simd_act(palm,a)),to:simd_normalize(b))*rotation
                // These imported ARKit joints extend along their local X axis.
                scale.x=min(2,max(0.4,simd_length(b)/simd_length(a)))
            } else if [4,9,14,19,24].contains(i), let parent=result.last {
                rotation=simd_quatf(simd_float3x3(columns:(simd_normalize(SIMD3(parent.columns.0.x,parent.columns.0.y,parent.columns.0.z)),simd_normalize(SIMD3(parent.columns.1.x,parent.columns.1.y,parent.columns.1.z)),simd_normalize(SIMD3(parent.columns.2.x,parent.columns.2.y,parent.columns.2.z)))))
            }
            var m=simd_float4x4(rotation)
            m.columns.0 *= scale.x; m.columns.1 *= scale.y; m.columns.2 *= scale.z
            m.columns.3=SIMD4(position,1); result.append(m)
        }
        return result
    }
}
