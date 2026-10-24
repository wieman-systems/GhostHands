import RealityKit
import UIKit
import simd

@MainActor final class LabVisual {
    let root=Entity()
    private var kind:MechanicalModel?
    private var groups:[Entity]=[]
    private var rotors:[(Entity,Bool)]=[]
    private var particles:[ModelEntity]=[]
    private var flames:[ModelEntity]=[]
    private var casing=Entity()
    private var named:[LabPart:[ModelEntity]]=[:]
    private var defect:ModelEntity?
    private var defectHalo:ModelEntity?
    private var previousFocus:LabPart?
    private var lastReveal=false
    private var gearA=Entity(),gearB=Entity()
    private func mat(_ alpha:Float)->UnlitMaterial {var m=UnlitMaterial(color:.white);m.blending = .transparent(opacity:.init(floatLiteral:alpha));return m}
    @discardableResult private func add(_ mesh:MeshResource,_ position:SIMD3<Float>,to parent:Entity?=nil,alpha:Float=0.65,part:LabPart?=nil)->ModelEntity {
        let e=ModelEntity(mesh:mesh,materials:[mat(alpha)]);e.position=position;(parent ?? root).addChild(e)
        if let part {e.name="lab-part-"+part.rawValue;e.generateCollisionShapes(recursive:false);e.components.set(InputTargetComponent());e.components.set(HoverEffectComponent());named[part,default:[]].append(e)}
        return e
    }
    @discardableResult private func shaft(_ length:Float,_ radius:Float,_ position:SIMD3<Float>,to parent:Entity,part:LabPart?=nil)->ModelEntity {
        let e=add(.generateCylinder(height:length,radius:radius),position,to:parent,alpha:0.65,part:part);e.orientation=simd_quatf(angle:.pi/2,axis:[0,0,1]);return e
    }
    private func hoop(_ x:Float,_ radius:Float,to parent:Entity,cutaway:Bool=true) {
        for i in 0..<32 {
            let a=Float(i)*2*Float.pi/32,b=Float(i+1)*2*Float.pi/32
            if cutaway && sin(a)>0.25 {continue}
            let p=SIMD3<Float>(x,cos(a)*radius,sin(a)*radius),q=SIMD3<Float>(x,cos(b)*radius,sin(b)*radius),v=q-p
            let e=add(.generateCylinder(height:simd_length(v),radius:0.001), (p+q)/2,to:parent,alpha:0.28)
            e.orientation=simd_quatf(from:[0,1,0],to:simd_normalize(v))
        }
    }
    private func stage(x:Float,radius:Float,count:Int,part:LabPart,fast:Bool,spinning:Bool=true,damage:Bool=false)->Entity {
        let group=Entity();group.position=[x,0.10,0];root.addChild(group);groups.append(group)
        let disk=Entity();group.addChild(disk)
        shaft(0.012,radius*0.30,.zero,to:disk,part:part)
        for i in 0..<count {
            let a=Float(i)*2*Float.pi/Float(count)
            let isDefect=damage && i==3,span=radius*(isDefect ? 0.40 : 0.67)
            let blade=add(.generateBox(width:0.006,height:span,depth:radius*0.15),[0,cos(a)*(radius*0.3+span/2),sin(a)*(radius*0.3+span/2)],to:disk,alpha:spinning ? 0.80 : 0.30,part:part)
            blade.orientation=simd_quatf(angle:a,axis:[1,0,0])*simd_quatf(angle:spinning ? 0.35 : -0.25,axis:[0,1,0])
            if isDefect {defect=blade;blade.name="lab-defect"}
        }
        if spinning {rotors.append((disk,fast))}
        return group
    }
    private func label(_ text:String,_ p:SIMD3<Float>) {
        let mesh=MeshResource.generateText(text,extrusionDepth:0.0004,font:.systemFont(ofSize:0.006,weight:.semibold))
        let back=ModelEntity(mesh:.generateBox(width:Float(text.count)*0.004+0.006,height:0.012,depth:0.001),materials:[UnlitMaterial(color:.black)])
        back.position=p+[Float(text.count)*0.002,0.003,-0.001];root.addChild(back);add(mesh,p,alpha:1)
    }
    private func buildJet() {
        casing=Entity();casing.position.y=0.10;root.addChild(casing)
        for x:Float in [-0.14,-0.10,-0.05,0,0.05,0.10,0.15] {hoop(x,abs(x)>0.12 ? 0.062 : 0.072,to:casing)}
        _=stage(x:-0.14,radius:0.060,count:18,part:.fan,fast:false,damage:true)
        for i in 0..<3 {_=stage(x:-0.085+Float(i)*0.025,radius:0.035-Float(i)*0.003,count:16,part:.compressor,fast:true)
            _=stage(x:-0.073+Float(i)*0.025,radius:0.034-Float(i)*0.003,count:16,part:.compressor,fast:true,spinning:false)}
        let chamber=Entity();chamber.position=[0.025,0.10,0];root.addChild(chamber);groups.append(chamber)
        for i in 0..<8 {let a=Float(i)*2*Float.pi/8
            let flame=add(.generateSphere(radius:0.008),[0,cos(a)*0.023,sin(a)*0.023],to:chamber,alpha:0.8,part:.combustor);flame.scale=[2.2,0.7,0.7];flames.append(flame)}
        for x:Float in [-0.02,0.02] {hoop(x,0.034,to:chamber)}
        _=stage(x:0.078,radius:0.030,count:16,part:.turbine,fast:true)
        _=stage(x:0.11,radius:0.036,count:16,part:.turbine,fast:false)
        let nozzle=Entity();nozzle.position=[0.15,0.10,0];root.addChild(nozzle);groups.append(nozzle)
        for x:Float in [-0.012,0,0.012] {hoop(x,0.032-x*0.3,to:nozzle)}
        shaft(0.035,0.012,.zero,to:nozzle,part:.nozzle)
        shaft(0.25,0.003,[-0.012,0.10,0],to:root)
        shaft(0.16,0.006,[-0.005,0.10,0],to:root)
        for _ in 0..<84 {particles.append(add(.generateSphere(radius:0.0018),.zero,alpha:0.7))}
        // Small airframe context: wing, pylon, fuselage and tail. Engine remains the focus.
        add(.generateBox(width:0.09,height:0.004,depth:0.24),[-0.01,0.23,-0.05],alpha:0.18)
        add(.generateBox(width:0.025,height:0.06,depth:0.006),[-0.01,0.195,-0.015],alpha:0.25)
        let fuselage=add(.generateSphere(radius:0.015),[-0.01,0.245,-0.16],alpha:0.18);fuselage.scale=[9,1,1]
        add(.generateBox(width:0.035,height:0.033,depth:0.003),[0.10,0.26,-0.16],alpha:0.2)
        label("FAN",[-0.16,0.18,0.07]);label("COMPRESSOR",[-0.095,0.155,0.07]);label("COMBUSTOR",[0.005,0.155,0.07]);label("TURBINE",[0.085,0.155,0.07])
        label("CORE + BYPASS",[-0.055,0.012,0.095])
    }
    private func gear(_ count:Int,_ radius:Float,_ center:SIMD3<Float>,part:LabPart,damaged:Bool)->Entity {
        let group=Entity();group.position=center;root.addChild(group);groups.append(group)
        add(.generateCylinder(height:0.012,radius:radius-0.004),.zero,to:group,alpha:0.4,part:part)
        for i in 0..<count {let a=Float(i)*2*Float.pi/Float(count),bad=damaged && i==2
            let tooth=add(.generateBox(width:0.007,height:0.014,depth:bad ? 0.003 : 0.009),[sin(a)*radius,0,cos(a)*radius],to:group,alpha:0.85,part:part);tooth.orientation=simd_quatf(angle:a,axis:[0,1,0]);if bad {defect=tooth;tooth.name="lab-defect"}}
        add(.generateCylinder(height:0.07,radius:0.005),.zero,to:group,alpha:0.8,part:part)
        // A single brighter witness mark helps compare the gear rotation rates.
        add(.generateBox(width:0.004,height:0.002,depth:radius*0.65),[0,0.009,radius*0.34],to:group,alpha:1)
        return group
    }
    private func buildGearbox() {
        casing=Entity();root.addChild(casing)
        add(.generateBox(width:0.24,height:0.005,depth:0.18),[0,0.004,0],to:casing,alpha:0.12)
        gearA=gear(12,0.033,[-0.066,0.065,0],part:.driver,damaged:true)
        gearB=gear(24,0.066,[0.033,0.065,0],part:.driven,damaged:false)
        for x:Float in [-0.066,0.033] {
            for y:Float in [0.028,0.10] {let bearing=Entity();bearing.position=[x,y,0];root.addChild(bearing);groups.append(bearing)
                add(.generateCylinder(height:0.010,radius:0.016),.zero,to:bearing,alpha:0.45,part:.bearing)}
        }
        label("INPUT / 12 TEETH",[-0.11,0.125,0.045]);label("OUTPUT / 24 TEETH",[0.0,0.145,0.06])
    }
    func update(_ model:StudioModel) {
        let visible=model.placed && !model.adjustingPlacement && model.showGuides && [.jet,.gearbox].contains(model.course.mechanicalModel)
        root.isEnabled=visible;guard visible else{return}
        if kind != model.course.mechanicalModel {root.children.removeAll();groups=[];rotors=[];particles=[];flames=[];named=[:];defect=nil;previousFocus=nil;lastReveal=false;kind=model.course.mechanicalModel
            if kind == .jet {buildJet()} else {buildGearbox()}
            let halo=ModelEntity(mesh:.generateSphere(radius:0.014),materials:[mat(0.20)]);defect?.addChild(halo);halo.isEnabled=false;defectHalo=halo
        }
        root.scale=SIMD3(repeating:model.modelScale);root.orientation=simd_quatf(angle:model.modelRotation,axis:[0,1,0])
        let inspecting=model.currentStep.id=="inspect",seconds=inspecting ? 0 : model.elapsed
        casing.isEnabled=model.showCasing && !model.explodedView
        if kind == .jet {
            for (rotor,fast) in rotors {rotor.orientation=simd_quatf(angle:LabMotion.rotorAngle(seconds:seconds,fast:fast),axis:[1,0,0])}
            for (i,group) in groups.enumerated() {group.position.y=0.10+(model.explodedView ? Float(i%3)*0.035 : 0)}
            for (i,p) in particles.enumerated() {p.isEnabled=model.showFlow && !inspecting && !model.explodedView;p.position=LabMotion.flow(index:i,count:particles.count,progress:seconds/8,bypass:i%3 != 0)}
            for (i,f) in flames.enumerated() {f.isEnabled = !inspecting;f.scale.x=2.2+0.4*sin(Float(seconds)*8+Float(i))}
        } else {
            let angles=LabMotion.gearAngles(seconds:seconds)
            gearA.orientation=simd_quatf(angle:angles.0,axis:[0,1,0]);gearB.orientation=simd_quatf(angle:angles.1,axis:[0,1,0])
            for (i,group) in groups.enumerated() {if i<2 {group.position.y=0.065+(model.explodedView ? 0.035 : 0)} else {let upper=(i-2)%2==1;group.position.y=upper ? (model.explodedView ? 0.17 : 0.10) : 0.028}}
        }
        if previousFocus != model.labFocus || lastReveal != (model.revealDefect || model.defectFound) {
            previousFocus=model.labFocus;lastReveal=model.revealDefect || model.defectFound
            for (part,entities) in named {for e in entities {e.model?.materials=[mat(lastReveal ? 0.12 : (model.labFocus == nil || model.labFocus==part ? 0.8 : 0.12))]}}
            defectHalo?.isEnabled=lastReveal
            if lastReveal {defect?.model?.materials=[UnlitMaterial(color:.white)]}
        }
    }
}
