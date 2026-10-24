import RealityKit
import UIKit
import simd

@MainActor final class MechanismVisual {
    let root=Entity()
    private var kind:MechanicalModel?
    private var colored=false
    private var rotor=Entity(),output=Entity(),follower=Entity()
    private var rod=ModelEntity(),pin=ModelEntity()
    private var markers:[ModelEntity]=[]
    private var pieces:[(ModelEntity,LabPart,Float)]=[]
    private var focus:LabPart?
    @discardableResult private func add(_ mesh:MeshResource,_ point:SIMD3<Float>,to parent:Entity?=nil,part:LabPart,alpha:Float=0.75)->ModelEntity {
        let e=ModelEntity(mesh:mesh,materials:[ModelSurface.material(colored:colored,color:ModelSurface.color(part),alpha:alpha)])
        e.position=point;e.name="lab-part-"+part.rawValue;e.generateCollisionShapes(recursive:false)
        e.components.set(InputTargetComponent());e.components.set(HoverEffectComponent());(parent ?? root).addChild(e);pieces.append((e,part,alpha));return e
    }
    @discardableResult private func cylinder(_ radius:Float,_ depth:Float,_ point:SIMD3<Float>,to parent:Entity?=nil,part:LabPart)->ModelEntity {
        let e=add(.generateCylinder(height:depth,radius:radius),point,to:parent,part:part);e.orientation=simd_quatf(angle:.pi/2,axis:[1,0,0]);return e
    }
    private func bar(_ a:SIMD3<Float>,_ b:SIMD3<Float>,radius:Float=0.003,part:LabPart)->ModelEntity {
        let e=add(.generateCylinder(height:1,radius:radius),.zero,part:part);positionBar(e,a,b);return e
    }
    private func positionBar(_ e:ModelEntity,_ a:SIMD3<Float>,_ b:SIMD3<Float>) {
        let d=b-a;e.position=(a+b)/2;e.scale=[1,simd_length(d),1];e.orientation=simd_quatf(from:[0,1,0],to:simd_normalize(d))
    }
    private func build(_ kind:MechanicalModel) {
        root.addChild(rotor);root.addChild(output);root.addChild(follower)
        add(.generateBox(width:0.38,height:0.008,depth:0.14),[0,0.004,0],part:.bearing,alpha:0.25)
        if kind == .cam {
            rotor.position=[0,0.075,0]
            cylinder(0.045,0.024,[0.012,0,0],to:rotor,part:.cam)
            cylinder(0.006,0.065,[0,0.075,-0.005],part:.bearing)
            cylinder(0.003,0.026,[0.012,0,0.004],to:rotor,part:.cam)
            add(.generateBox(width:0.10,height:0.008,depth:0.035),.zero,to:follower,part:.follower)
            add(.generateCylinder(height:0.10,radius:0.005),[0,0.054,0],to:follower,part:.follower)
            for x:Float in [-0.07,0.07] {add(.generateBox(width:0.012,height:0.19,depth:0.025),[x,0.10,-0.025],part:.bearing)}
            add(.generateBox(width:0.16,height:0.015,depth:0.025),[0,0.18,-0.025],part:.bearing)
            for x:Float in [-0.012,0.012] {add(.generateBox(width:0.012,height:0.035,depth:0.025),[x,0.18,0],part:.bearing)}
        } else if kind == .crank {
            rotor.position=[-0.12,0.095,0]
            cylinder(0.045,0.014,.zero,to:rotor,part:.crank)
            cylinder(0.007,0.06,[-0.12,0.095,-0.02],part:.bearing)
            pin=cylinder(0.006,0.028,[MechanismMotion.crankRadius,0,0.013],to:rotor,part:.crank)
            rod=bar([0,0,0],[0.15,0,0],radius:0.006,part:.rod)
            add(.generateBox(width:0.044,height:0.035,depth:0.045),.zero,to:follower,part:.slider)
            cylinder(0.006,0.05,.zero,to:follower,part:.slider)
            for y:Float in [0.07,0.12] {_ = bar([-0.05,y,0],[0.13,y,0],radius:0.004,part:.bearing)}
            for x:Float in [-0.05,0.13] {add(.generateBox(width:0.014,height:0.12,depth:0.10),[x,0.065,-0.045],part:.bearing,alpha:0.35)}
        } else {
            rotor.position=[-0.095,0.095,0];output.position=[0.095,0.095,0]
            for (group,radius,part) in [(rotor,MechanismMotion.smallRadius,LabPart.driver),(output,MechanismMotion.largeRadius,LabPart.driven)] {
                for z:Float in [-0.010,0.010] {add(ModelSurface.ring(inner:radius-0.008,outer:radius,depth:0.003),[0,0,z],to:group,part:part)}
                cylinder(0.012,0.028,.zero,to:group,part:part)
                for i in 0..<5 {let angle=Float(i)*2*Float.pi/5
                    let spoke=add(.generateBox(width:radius-0.008,height:0.005,depth:0.012),[cos(angle)*radius/2,sin(angle)*radius/2,0],to:group,part:part,alpha:i==0 ? 1 : 0.6);spoke.orientation=simd_quatf(angle:angle,axis:[0,0,1])}
                cylinder(0.005,0.075,group.position+[0,0,-0.02],part:.bearing)
                add(.generateBox(width:0.026,height:0.09,depth:0.025),group.position+[0,-0.045,-0.045],part:.bearing,alpha:0.4)
            }
            for i in 0..<96 {
                let a=MechanismMotion.beltPoint(Float(i)/96)+SIMD3<Float>(0,0.095,0),b=MechanismMotion.beltPoint(Float(i+1)/96)+SIMD3<Float>(0,0.095,0)
                _ = bar(a,b,radius:0.0025,part:.belt)
            }
            for _ in 0..<12 {markers.append(add(.generateSphere(radius:0.0035),.zero,part:.belt,alpha:1))}
        }
    }
    func update(_ model:StudioModel) {
        guard model.placed,!model.adjustingPlacement,model.showGuides,let next=model.course.mechanicalModel,[.cam,.belt,.crank].contains(next) else {root.isEnabled=false;return}
        root.isEnabled=true
        if kind != next || colored != model.coloredModels {
            root.children.removeAll();rotor=Entity();output=Entity();follower=Entity();markers=[];pieces=[];focus=nil
            colored=model.coloredModels;kind=next;build(next)
        }
        root.scale=SIMD3(repeating:model.modelScale);root.orientation=simd_quatf(angle:model.modelRotation,axis:[0,1,0])
        let angle=Float(model.elapsed/8)*2*Float.pi
        if next == .cam {rotor.orientation=simd_quatf(angle:angle,axis:[0,0,1]);follower.position=[0,0.075+MechanismMotion.camTop(angle)+0.004,0]}
        else if next == .crank {
            rotor.orientation=simd_quatf(angle:angle,axis:[0,0,1])
            let motion=MechanismMotion.crank(angle),offset=SIMD3<Float>(-0.12,0.095,0.020)
            follower.position=motion.slider+offset;positionBar(rod,motion.pin+offset,motion.slider+offset)
        } else {
            rotor.orientation=simd_quatf(angle:-2*angle,axis:[0,0,1]);output.orientation=simd_quatf(angle:-angle,axis:[0,0,1])
            for (i,marker) in markers.enumerated() {marker.position=MechanismMotion.beltPoint(Float(i)/12+Float(model.elapsed/8))+SIMD3(0,0.095,0.004)}
        }
        if focus != model.labFocus {focus=model.labFocus
            for (e,part,alpha) in pieces {e.model?.materials=[ModelSurface.material(colored:colored,color:ModelSurface.color(part),alpha:focus==nil || focus==part ? alpha : 0.15)]}
        }
    }
}
