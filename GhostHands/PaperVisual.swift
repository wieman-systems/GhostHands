import RealityKit
import UIKit
import simd

@MainActor final class PaperVisual {
    let root=Entity()
    private let surface=ModelEntity()
    private var lines:[ModelEntity]=[]
    private var lastStep = -1
    private var lastWidth:Float = -1
    private var lastAmount:Float = -1
    private var mesh:LowLevelMesh?
    private var vertexCount=0
    private let capacity=256
    init() {
        root.addChild(surface)
        for _ in 0..<60 {
            var m=UnlitMaterial(color:.white);m.blending = .transparent(opacity:.init(floatLiteral:0.7))
            let line=ModelEntity(mesh:.generateCylinder(height:1,radius:0.0007),materials:[m]);line.isEnabled=false
            lines.append(line);root.addChild(line)
        }
        root.position.y=0.006
    }
    func update(step:PaperStep,seconds:Double,width:Float,visible:Bool) {
        root.isEnabled=visible;guard visible else{return}
        let amount=IllustratedMotion.progress(at:seconds)
        guard lastStep != step.id || lastWidth != width || lastAmount != amount else{return}
        lastStep=step.id;lastWidth=width;lastAmount=amount
        let vertices=PaperMotion.vertices(step:step,progress:amount,width:width)
        guard vertices.count<=capacity else{return}
        if mesh==nil {
            do {
                let descriptor=LowLevelMesh.Descriptor(vertexCapacity:capacity,
                    vertexAttributes:[.init(semantic:.position,format:.float3,offset:0)],
                    vertexLayouts:[.init(bufferIndex:0,bufferStride:MemoryLayout<SIMD3<Float>>.stride)],
                    indexCapacity:capacity,indexType:.uint32)
                let buffer=try LowLevelMesh(descriptor:descriptor)
                buffer.withUnsafeMutableIndices {raw in
                    let indices=raw.bindMemory(to:UInt32.self)
                    for i in 0..<capacity {indices[i]=UInt32(i)}
                }
                var material=UnlitMaterial(color:.white)
                material.faceCulling = .none;material.blending = .transparent(opacity:.init(floatLiteral:0.14))
                surface.model=ModelComponent(mesh:try MeshResource(from:buffer),materials:[material]);mesh=buffer
            } catch {return}
        }
        guard let mesh else{return}
        mesh.withUnsafeMutableBytes(bufferIndex:0) {raw in
            let positions=raw.bindMemory(to:SIMD3<Float>.self)
            for (i,point) in vertices.enumerated() {positions[i]=point}
        }
        if vertexCount != vertices.count {
            vertexCount=vertices.count
            mesh.parts.replaceAll([.init(indexCount:vertexCount,bounds:BoundingBox(min:[-1,-1,-1],max:[1,1,1]))])
        }
        var edge=0
        for triangle in stride(from:0,to:vertices.count,by:3) {
            for i in 0..<3 where edge<lines.count {
                let a=vertices[triangle+i],b=vertices[triangle+(i+1)%3],length=simd_distance(a,b),line=lines[edge];edge+=1
                line.isEnabled=length>0.0001
                if line.isEnabled {line.position=(a+b)/2;line.scale=[1,length,1];line.orientation=simd_quatf(from:[0,1,0],to:simd_normalize(b-a))}
            }
        }
        for i in edge..<lines.count {lines[i].isEnabled=false}
    }
}
