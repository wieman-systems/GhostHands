import RealityKit
import UIKit
import simd

@MainActor final class PaperVisual {
    let root=Entity()
    private let surface=ModelEntity()
    private var lines:[ModelEntity]=[]
    private var key=""
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
        let frame=Int(amount*45),next="\(step.id)-\(frame)-\(width)"
        guard key != next else{return};key=next
        let vertices=PaperMotion.vertices(step:step,progress:Float(frame)/45,width:width)
        var descriptor=MeshDescriptor(name:"instruction-paper")
        descriptor.positions = MeshBuffers.Positions(vertices)
        descriptor.primitives = .triangles(Array(0..<UInt32(vertices.count)))
        var material=UnlitMaterial(color:.white)
        material.faceCulling = .none;material.blending = .transparent(opacity:.init(floatLiteral:0.14))
        if let mesh=try? MeshResource.generate(from:[descriptor]) {surface.model=ModelComponent(mesh:mesh,materials:[material])}
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
