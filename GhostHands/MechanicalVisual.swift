import RealityKit
import UIKit
import simd

/// Native teaching geometry. No third-party model or car-fit claim.
@MainActor final class MechanicalVisual {
    let root=Entity()
    private var kind:MechanicalModel?
    private var focus:EnginePart?
    private var parts:[EnginePart:[ModelEntity]]=[:]
    private let piston=Entity(),rod=Entity(),crank=Entity(),inlet=Entity(),exhaust=Entity()
    private var spark:ModelEntity?
    private var flow:[ModelEntity]=[]
    private var lid=Entity(),filter=Entity()
    private func material(_ alpha:Float)->UnlitMaterial {
        var m=UnlitMaterial(color:.white);m.blending = .transparent(opacity:.init(floatLiteral:alpha));return m
    }
    @discardableResult private func add(_ mesh:MeshResource,at p:SIMD3<Float>,to parent:Entity?=nil,alpha:Float=0.65,part:EnginePart?=nil)->ModelEntity {
        let entity=ModelEntity(mesh:mesh,materials:[material(alpha)]);entity.position=p
        (parent ?? root).addChild(entity)
        if let part {
            entity.name="engine-part-"+part.rawValue
            entity.generateCollisionShapes(recursive:false)
            entity.components.set(InputTargetComponent());entity.components.set(HoverEffectComponent())
            parts[part,default:[]].append(entity)
        }
        return entity
    }
    private func beam(_ a:SIMD3<Float>,_ b:SIMD3<Float>,radius:Float=0.0015,alpha:Float=0.4,to parent:Entity?=nil,part:EnginePart?=nil) {
        let v=b-a;guard simd_length(v)>0.0001 else{return}
        let entity=add(.generateCylinder(height:simd_length(v),radius:radius),at:(a+b)/2,to:parent,alpha:alpha,part:part)
        entity.orientation=simd_quatf(from:[0,1,0],to:simd_normalize(v))
    }
    private func ring(y:Float,radius:Float,to parent:Entity?=nil,part:EnginePart?=nil) {
        for i in 0..<24 {let a=Float(i)*2*Float.pi/24,b=Float(i+1)*2*Float.pi/24
            beam([radius*cos(a),y,radius*sin(a)],[radius*cos(b),y,radius*sin(b)],alpha:0.45,to:parent,part:part)
        }
    }
    private func buildEngine() {
        // Open front half leaves piston/rod readable; rear rails describe the bore.
        for y:Float in [0.09,0.17] {ring(y:y,radius:0.040)}
        for i in 0...6 {let a=Float.pi+Float(i)*Float.pi/6
            beam([0.04*cos(a),0.09,0.04*sin(a)],[0.04*cos(a),0.17,0.04*sin(a)],alpha:0.22)
        }
        add(.generateBox(width:0.125,height:0.007,depth:0.10),at:[0,0.004,0],alpha:0.16)
        root.addChild(piston);root.addChild(rod);root.addChild(crank);root.addChild(inlet);root.addChild(exhaust)
        add(.generateCylinder(height:0.020,radius:0.033),at:.zero,to:piston,part:.piston)
        for y:Float in [-0.005,0.002,0.008] {ring(y:y,radius:0.034,to:piston)}
        add(.generateCylinder(height:EngineCycle.rodLength,radius:0.006),at:.zero,to:rod,part:.rod)
        crank.position=[0,EngineCycle.crankHeight,0]
        beam([0,0,-0.055],[0,0,0.055],radius:0.008,to:crank,part:.crank)
        beam([0,0,-0.014],[0,EngineCycle.radius,-0.014],radius:0.009,to:crank,part:.crank)
        beam([0,EngineCycle.radius,-0.014],[0,EngineCycle.radius,0.014],radius:0.007,to:crank,part:.crank)
        beam([0,EngineCycle.radius,0.014],[0,0,0.014],radius:0.009,to:crank,part:.crank)
        for (group,part,x) in [(inlet,EnginePart.inlet,Float(-0.021)),(exhaust,EnginePart.exhaust,Float(0.021))] {
            group.position=[x,0.177,0]
            add(.generateCylinder(height:0.005,radius:0.012),at:.zero,to:group,part:part)
            add(.generateCylinder(height:0.037,radius:0.003),at:[0,0.020,0],to:group,part:part)
        }
        add(.generateCylinder(height:0.028,radius:0.006),at:[0,0.198,0.012],part:.plug)
        beam([0,0.177,0.012],[0,0.185,0.012],radius:0.002,alpha:1,part:.plug)
        spark=add(.generateSphere(radius:0.008),at:[0,0.174,0.012],alpha:1)
        beam([-0.08,0.19,0],[-0.045,0.19,0],radius:0.013,alpha:0.22)
        beam([0.045,0.19,0],[0.08,0.19,0],radius:0.013,alpha:0.22)
        for _ in 0..<16 {flow.append(add(.generateSphere(radius:0.0025),at:.zero,alpha:0.7))}
        label("INLET",at:[-0.09,0.218,0]);label("EXHAUST",at:[0.045,0.218,0]);label("SPARK",at:[-0.014,0.237,0.012])
        label("PISTON",at:[0.052,0.135,0.025]);label("ROD",at:[0.052,0.09,0.025]);label("CRANK",at:[0.052,0.04,0.025])
    }
    private func label(_ text:String,at position:SIMD3<Float>) {
        let mesh=MeshResource.generateText(text,extrusionDepth:0.0004,font:.systemFont(ofSize:0.007,weight:.medium))
        let backing=ModelEntity(mesh:.generateBox(width:Float(text.count)*0.0048+0.006,height:0.013,depth:0.0006),materials:[UnlitMaterial(color:.black)])
        backing.position=position+SIMD3<Float>(Float(text.count)*0.0024,0.003,-0.001);root.addChild(backing)
        add(mesh,at:position,alpha:0.9)
    }
    private func buildFilter() {
        // An open housing with a separate front cover and pleated element.
        add(.generateBox(width:0.16,height:0.008,depth:0.10),at:[0,0.008,0],alpha:0.22)
        add(.generateBox(width:0.16,height:0.045,depth:0.004),at:[0,0.030,-0.05],alpha:0.25)
        for x:Float in [-0.08,0.08] {add(.generateBox(width:0.004,height:0.045,depth:0.10),at:[x,0.03,0],alpha:0.3)}
        root.addChild(lid);root.addChild(filter)
        add(.generateBox(width:0.164,height:0.045,depth:0.006),at:[0,0.03,0.053],to:lid,alpha:0.55)
        for i in 0..<18 {add(.generateBox(width:0.002,height:0.022,depth:0.085),at:[Float(i)*0.008-0.068,0.027,0],to:filter,alpha:0.55)}
        for z:Float in [-0.045,0.045] {add(.generateBox(width:0.146,height:0.025,depth:0.003),at:[0,0.027,z],to:filter,alpha:0.8)}
        label("FILTER HOUSING",at:[-0.057,0.07,-0.02]);label("ILLUSTRATION",at:[-0.042,0.003,0.15])
    }
    func update(model:StudioModel) {
        let visible=model.placed && !model.adjustingPlacement && model.showGuides && [.engine,.cabinFilter].contains(model.course.mechanicalModel)
        root.isEnabled=visible;guard visible else{return}
        root.scale=SIMD3(repeating:model.modelScale);root.orientation=simd_quatf(angle:model.modelRotation,axis:[0,1,0])
        if kind != model.course.mechanicalModel {
            root.children.removeAll();for group in [piston,rod,crank,inlet,exhaust,lid,filter] {group.children.removeAll()}
            parts=[:];flow=[];spark=nil;focus=nil;kind=model.course.mechanicalModel
            if kind == .engine {buildEngine()} else {buildFilter()}
        }
        let progress=model.elapsed/max(0.01,model.progressDuration)
        if kind == .engine {
            let pose=EngineCycle.pose(stepID:model.currentStep.id,progress:progress)
            piston.position=pose.piston;rod.position=(pose.piston+pose.pin)/2
            rod.orientation=simd_quatf(from:[0,1,0],to:simd_normalize(pose.piston-pose.pin))
            crank.orientation=simd_quatf(angle:-pose.angle,axis:[0,0,1])
            inlet.position.y=pose.inletOpen ? 0.168 : 0.177;exhaust.position.y=pose.exhaustOpen ? 0.168 : 0.177
            spark?.isEnabled=pose.spark
            for (i,dot) in flow.enumerated() {
                dot.isEnabled=model.showFlow
                let t=(Float(i)/Float(flow.count)+pose.progress).truncatingRemainder(dividingBy:1)
                if pose.stroke==0 {dot.position=[-0.075+t*0.075,0.19-t*0.04,Float(i%3-1)*0.008]}
                else if pose.stroke==3 {dot.position=[t*0.075,0.155+t*0.035,Float(i%3-1)*0.008]}
                else {dot.position=[Float(i%4-2)*0.009,pose.piston.y+0.015+(0.165-pose.piston.y-0.015)*Float(i/4+1)/5,Float(i%3-1)*0.008]}
            }
            if focus != model.engineFocus {focus=model.engineFocus;for (part,entities) in parts {for entity in entities {entity.model?.materials=[material(focus == nil || focus==part ? 0.90 : 0.18)]}}}
        } else {
            let p=Float(min(1,max(0,progress))),id=model.currentStep.id
            let coverOut:Float=["remove","compare","insert"].contains(id) ? 1 : id=="cover" ? p : id=="replace-cover" ? 1-p : 0
            let filterOut:Float=id=="remove" ? p : id=="compare" ? 1 : id=="insert" ? 1-p : 0
            lid.position=[0.07*coverOut,0,0.075*coverOut];lid.orientation=simd_quatf(angle:Float.pi/2*coverOut,axis:[0,1,0]);filter.position=[0,0,0.12*filterOut]
        }
    }
}
