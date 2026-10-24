import RealityKit
import UIKit
import simd

@MainActor final class DetailedVisual {
    let root=Entity()
    private var kind:MechanicalModel?
    private var colored=false
    private var focus:LabPart?
    private var entities:[(ModelEntity,LabPart,Float)]=[]
    private var rotor=Entity(),front=Entity(),rear=Entity(),leftPad=Entity(),rightPad=Entity(),body=Entity()
    private var particles:[ModelEntity]=[]
    @discardableResult private func add(_ mesh:MeshResource,_ p:SIMD3<Float>,to parent:Entity,part:LabPart,alpha:Float=0.85,interactive:Bool=true)->ModelEntity {
        let e=ModelEntity(mesh:mesh,materials:[ModelSurface.material(colored:colored,color:ModelSurface.color(part),alpha:alpha,metal:part == .pads ? 0.05 : 0.8)])
        e.position=p;e.name="lab-part-"+part.rawValue
        if interactive && alpha>0.3 {e.generateCollisionShapes(recursive:false);e.components.set(InputTargetComponent());e.components.set(HoverEffectComponent())}
        parent.addChild(e);entities.append((e,part,alpha));return e
    }
    @discardableResult private func cylinder(_ radius:Float,_ length:Float,_ p:SIMD3<Float>,to parent:Entity,part:LabPart)->ModelEntity {
        let e=add(.generateCylinder(height:length,radius:radius),p,to:parent,part:part);e.orientation=simd_quatf(angle:.pi/2,axis:[1,0,0]);return e
    }
    private func bolts(radius:Float,z:Float,count:Int,to parent:Entity,part:LabPart) {
        for i in 0..<count {let a=Float(i)*2*Float.pi/Float(count)
            let p=SIMD3<Float>(radius*cos(a),radius*sin(a),z)
            cylinder(0.004,0.008,p,to:parent,part:part)
            // Raised socket head and a dark recessed center.
            add(ModelSurface.ring(inner:0.0017,outer:0.0038,depth:0.002),p+[0,0,0.005],to:parent,part:part)
        }
    }
    private func brake() {
        root.position.y=0.115
        for g in [rotor,front,rear,leftPad,rightPad,body] {root.addChild(g)}
        add(.generateBox(width:0.15,height:0.009,depth:0.10,cornerRadius:0.003),[0,-0.108,-0.025],to:rear,part:.bearing)
        add(.generateBox(width:0.04,height:0.10,depth:0.025,cornerRadius:0.004),[0,-0.055,-0.040],to:rear,part:.bearing)
        cylinder(0.020,0.085,[0,0,-0.025],to:rear,part:.bearing)
        for z:Float in [-0.008,0.008] {add(ModelSurface.ring(inner:0.032,outer:0.088,depth:0.005),[0,0,z],to:rotor,part:.disc)}
        for i in 0..<36 {let a=Float(i)*2*Float.pi/36
            let vane=add(.generateBox(width:0.041,height:0.002,depth:0.012),[0.059*cos(a),0.059*sin(a),0],to:rotor,part:.disc)
            vane.orientation=simd_quatf(angle:a+0.2,axis:[0,0,1])
        }
        add(ModelSurface.ring(inner:0.012,outer:0.039,depth:0.020),.zero,to:front,part:.disc)
        bolts(radius:0.024,z:0.015,count:5,to:front,part:.disc)
        // Machining rings on the braking face remain visible in monochrome.
        for r:Float in [0.040,0.057,0.075,0.085] {add(ModelSurface.ring(inner:r,outer:r+0.0005,depth:0.0006),[0,0,0.011],to:rotor,part:.disc,alpha:0.28)}
        for pad in [leftPad,rightPad] {
            add(.generateBox(width:0.036,height:0.070,depth:0.008,cornerRadius:0.006),[0.061,0,0],to:pad,part:.pads)
            add(.generateBox(width:0.043,height:0.074,depth:0.003,cornerRadius:0.004),[0.061,0,-0.004],to:pad,part:.caliper)
        }
        for z:Float in [-0.035,0.035] {
            add(.generateBox(width:0.045,height:0.085,depth:0.016,cornerRadius:0.008),[0.066,0,z],to:body,part:.caliper)
            for y:Float in [-0.022,0.022] {cylinder(0.012,0.012,[0.064,y,z*0.65],to:body,part:.caliper)}
        }
        for y:Float in [-0.038,0.038] {add(.generateBox(width:0.045,height:0.012,depth:0.075,cornerRadius:0.004),[0.068,y,0],to:body,part:.caliper)}
        for y:Float in [-0.025,0,0.025] {add(.generateBox(width:0.004,height:0.012,depth:0.085),[0.091,y,0],to:body,part:.caliper)}
    }
    private func pump() {
        root.position.y=0.115
        for g in [rotor,front,rear,leftPad,rightPad,body] {root.addChild(g)}
        add(.generateBox(width:0.19,height:0.012,depth:0.13,cornerRadius:0.004),[0,-0.105,-0.025],to:body,part:.volute)
        for x:Float in [-0.055,0.055] {add(.generateBox(width:0.018,height:0.060,depth:0.05),[x,-0.080,-0.02],to:body,part:.volute)}
        add(ModelSurface.ring(inner:0.016,outer:0.090,depth:0.008),[0,0,-0.025],to:rear,part:.volute)
        cylinder(0.014,0.075,[0,0,-0.050],to:rear,part:.bearing)
        // Increasing-radius casing wall approximates the collection passage.
        for i in 0..<48 {
            let a=Float(i)*2*Float.pi/48,r:Float=0.067+0.024*Float(i)/48
            let wall=add(.generateBox(width:0.014,height:0.013,depth:0.050,cornerRadius:0.003),[r*cos(a),r*sin(a),0],to:body,part:.volute)
            wall.orientation=simd_quatf(angle:a,axis:[0,0,1])
        }
        add(ModelSurface.ring(inner:0.013,outer:0.063,depth:0.005),[0,0,-0.013],to:rotor,part:.impeller)
        cylinder(0.018,0.023,.zero,to:rotor,part:.impeller)
        for i in 0..<7 {let base=Float(i)*2*Float.pi/7
            for j in 0..<10 {let t=Float(j)/10,a=base+t*0.7,r:Float=0.020+t*0.039
                let vane=add(.generateBox(width:0.007,height:0.003,depth:0.020,cornerRadius:0.001),[r*cos(a),r*sin(a),0],to:rotor,part:.impeller)
                vane.orientation=simd_quatf(angle:a+0.6,axis:[0,0,1])
            }
        }
        add(ModelSurface.ring(inner:0.040,outer:0.093,depth:0.006),[0,0,0.033],to:front,part:.volute,alpha:0.20)
        bolts(radius:0.084,z:0.038,count:8,to:front,part:.volute)
        // Inlet flange is open so the shaft and impeller eye remain visible.
        add(ModelSurface.ring(inner:0.019,outer:0.028,depth:0.020),[0,0,0.055],to:front,part:.outlet,interactive:false)
        let pipe=add(ModelSurface.ring(inner:0.015,outer:0.020,depth:0.095),[0.080,0.067,0],to:body,part:.outlet);pipe.orientation=simd_quatf(angle:.pi/2,axis:[1,0,0])
        let flange=add(ModelSurface.ring(inner:0.015,outer:0.031,depth:0.007),[0.080,0.115,0],to:body,part:.outlet);flange.orientation=pipe.orientation
        for i in 0..<40 {
            let e=ModelEntity(mesh:.generateSphere(radius:0.002),materials:[UnlitMaterial(color:colored ? .cyan : .white)]);root.addChild(e);particles.append(e)
            e.position=[Float(i)*0.001,0,0]
        }
    }
    func update(_ model:StudioModel) {
        let visible=model.placed && !model.adjustingPlacement && model.showGuides && [.brake,.pump].contains(model.course.mechanicalModel)
        root.isEnabled=visible;guard visible else{return}
        if kind != model.course.mechanicalModel || colored != model.coloredModels {
            root.children.removeAll();rotor=Entity();front=Entity();rear=Entity();leftPad=Entity();rightPad=Entity();body=Entity();entities=[];particles=[];focus=nil
            kind=model.course.mechanicalModel;colored=model.coloredModels
            if kind == .brake {brake()} else {pump()}
        }
        root.scale=SIMD3(repeating:model.modelScale);root.orientation=simd_quatf(angle:model.modelRotation,axis:[0,1,0])
        let spread:Float=model.explodedView ? 1 : 0
        rotor.orientation=simd_quatf(angle:model.mechanismAngle,axis:[0,0,1])
        front.position.z=spread*0.10;rear.position.z = -spread*0.07
        if kind == .brake {
            front.orientation=rotor.orientation
            leftPad.position.z = -0.025+model.mechanismBlend*0.010-spread*0.04
            rightPad.position.z = 0.025-model.mechanismBlend*0.010+spread*0.04
            body.position.x=spread*0.08
        } else {
            body.isEnabled=model.showCasing;rotor.position.z=spread*0.045
            for (i,e) in particles.enumerated() {
                e.isEnabled=model.showFlow && !model.explodedView
                let t=(Float(i)/40+model.mechanismAngle/12).truncatingRemainder(dividingBy:1)
                e.position=LabMotion.pumpFlow(t)
            }
        }
        if focus != model.labFocus {focus=model.labFocus
            for (e,part,alpha) in entities {e.model?.materials=[ModelSurface.material(colored:colored,color:ModelSurface.color(part),alpha:focus == nil || focus==part ? alpha : 0.14,metal:part == .pads ? 0.05 : 0.8)]}
        }
    }
}
