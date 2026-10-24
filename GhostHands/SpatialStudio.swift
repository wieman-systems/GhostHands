import SwiftUI
import RealityKit
import UIKit
import simd

private func ghostMaterial(_ color: UIColor) -> UnlitMaterial {
    var material = UnlitMaterial(color: color.withAlphaComponent(1))
    material.blending = .transparent(opacity: .init(floatLiteral: Float(color.cgColor.alpha)))
    return material
}

@MainActor
final class StudioScene {
    let root = Entity()
    let guides = Entity()
    let panels = Entity()
    let moveControls = Entity()
    let paper = PaperVisual()
    let mechanical = MechanicalVisual()
    let lab = LabVisual()
    let detailed = DetailedVisual()
    let videoPanel = Entity()
    let human = HumanReplay()

    func loadHands() async throws {
        try await ghostLeft.load(side:"left")
        try await ghostRight.load(side:"right")
    }
    let ghostLeft = HologramHand()
    let ghostRight = HologramHand()
    var guideKey = ""
    init() {
        root.addChild(guides);root.addChild(moveControls)
        root.addChild(paper.root);root.addChild(human.root);root.addChild(mechanical.root);root.addChild(lab.root);root.addChild(detailed.root);root.addChild(videoPanel)
        root.addChild(ghostLeft.root); root.addChild(ghostRight.root)

    }
    func render(model: StudioModel, frame: MotionFrame?, live: MotionFrame) {
        root.transform = Transform(matrix: model.workspace)
        mechanical.update(model:model);lab.update(model);detailed.update(model)
        videoPanel.position=[0,model.videoHeight,model.videoDepth];videoPanel.children.first?.scale=SIMD3(repeating:model.videoScale);videoPanel.isEnabled=model.placed && model.dockedVideo && !model.adjustingPlacement
        let avatarFrame=model.busyRecording ? MotionFrame(time:live.time,left:live.left?.transformed(by:simd_inverse(model.workspace)),right:live.right?.transformed(by:simd_inverse(model.workspace))) : frame
        human.update(frame:avatarFrame,enabled:model.avatarEnabled && model.placed && (model.busyRecording || model.selected?.isIllustration == false),tableHeight:model.avatarTableHeight)
        moveControls.isEnabled=model.placed && model.adjustingPlacement
        paper.update(step:model.lesson,seconds:model.elapsed,width:model.paperSide,visible:model.isPaperLesson && model.placed && !model.adjustingPlacement && model.showGuides && model.selected?.isIllustration == true)
        ghostLeft.update(model.placed && !model.adjustingPlacement && model.showHands && !model.avatarEnabled ? frame?.left : nil); ghostRight.update(model.placed && !model.adjustingPlacement && model.showHands && !model.avatarEnabled ? frame?.right : nil)
        guides.isEnabled = model.showGuides || !model.placed || model.adjustingPlacement
        let key = "\(model.course.id)-\(String(describing:model.spatialCue))-\(model.step)-\(model.paperSide)-\(model.paperHeight)-\(model.placed)-\(model.placementReady)-\(model.adjustingPlacement)"
        if guideKey != key { guideKey = key; if !model.isPaperLesson && model.placed && !model.adjustingPlacement {drawCue(model.spatialCue)} else {drawGuide(step:model.lesson,width:model.placed ? model.paperSide : LetterPaper.width,height:model.placed ? model.paperHeight : LetterPaper.height,preview:!model.placed || model.adjustingPlacement,ready:model.placementReady || model.placed) }}
        root.isEnabled = (model.placed || model.placementReady) && model.workspaceVisible
        panels.isEnabled = model.placed && !model.adjustingPlacement && model.workspaceVisible
        panels.transform = Transform(matrix:model.workspace)
    }
    private func drawCue(_ cue:SpatialCue?) {
        guides.children.removeAll();guard let cue,cue.isValid else{return}
        let a=SIMD3<Float>(cue.from[0],cue.from[1],cue.from[2]),b=SIMD3<Float>(cue.to[0],cue.to[1],cue.to[2])
        line(a,b,color:.white,radius:0.002)
        let d=b-a
        if simd_length(d)>0.005 {
            let direction=simd_normalize(d),axis:SIMD3<Float>=abs(direction.y)>0.9 ? [1,0,0] : [0,1,0]
            let side=simd_normalize(simd_cross(direction,axis))*0.012
            line(b,b-direction*0.025+side,color:.white,radius:0.002)
            line(b,b-direction*0.025-side,color:.white,radius:0.002)
        }
        let dot=ModelEntity(mesh:.generateSphere(radius:0.008),materials:[ghostMaterial(.white.withAlphaComponent(0.55))]);dot.position=a;guides.addChild(dot)
    }
    private func line(_ a: SIMD3<Float>, _ b: SIMD3<Float>, color: UIColor, radius: Float = 0.0012) {
        let length = simd_distance(a,b)
        guard length > 0.0001 else { return }
        let entity = ModelEntity(mesh: .generateCylinder(height: length, radius: radius), materials: [ghostMaterial(color)])
        entity.position = (a+b)/2
        entity.orientation = simd_quatf(from: [0,1,0], to: simd_normalize(b-a))
        guides.addChild(entity)
    }
    private func drawGuide(step: PaperStep, width: Float, height: Float, preview: Bool, ready: Bool) {
        guides.children.removeAll()
        func p(_ point: SIMD2<Float>, y: Float = 0.004) -> SIMD3<Float> { [point.x*width/2,y,point.y*height/2] }
        let footprint: [SIMD2<Float>] = [[-1,1],[-1,-1],[1,-1],[1,1]]
        if preview {
            let fill=ModelEntity(mesh:.generateBox(width:width,height:0.0005,depth:height),materials:[ghostMaterial(.white.withAlphaComponent(ready ? 0.16 : 0.04))])
            fill.position.y=0.002;guides.addChild(fill)
        }
        for i in 0..<4 { line(p(footprint[i]),p(footprint[(i+1)%4]),color:.white.withAlphaComponent(preview ? (ready ? 1 : 0.3) : 0.2),radius:preview ? 0.0018 : 0.0006) }
        if preview {
            // Square corner brackets reinforce the exact rectangular footprint.
            for corner in footprint {
                let c=p(corner,y:0.006)
                line(c,c+SIMD3(-corner.x*0.025,0,0),color:.white,radius:0.0025)
                line(c,c+SIMD3(0,0,-corner.y*0.025),color:.white,radius:0.0025)
            }
            line([-0.008,0.006,0],[0.008,0.006,0],color:.white)
            line([0,0.006,-0.008],[0,0.006,0.008],color:.white)
            return
        }
        for i in step.outline.indices { line(p(step.outline[i],y:0.006),p(step.outline[(i+1)%step.outline.count],y:0.006),color:.white.withAlphaComponent(0.12)) }
        let (a,b)=step.crease
        for i in 0..<12 { let t=Float(i)/12;line(p(a+(b-a)*t,y:0.008),p(a+(b-a)*(t+0.045),y:0.008),color:.white.withAlphaComponent(0.5)) }

    }

}

struct SpatialStudio: View {
    @Environment(StudioModel.self) private var model
    @Environment(VoiceCoach.self) private var voice
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openWindow) private var openWindow
    @Environment(\.scenePhase) private var phase
    @State private var scene = StudioScene()
    var body: some View {
        RealityView { content, attachments in
            content.add(scene.root); content.add(scene.panels)
            for (id,position) in [("lesson",SIMD3<Float>(-0.30,0.002,0)),("transport",SIMD3<Float>(0,0.002,-0.25)),("tools",SIMD3<Float>(0.30,0.002,0)),("tray",SIMD3<Float>(0,0.002,0.27)),("cueLabel",SIMD3<Float>(0,0.002,0.13))] {
                if let panel=attachments.entity(for:id) {
                    panel.position=position;panel.scale=SIMD3(repeating:0.48)
                    panel.orientation=simd_quatf(angle:-Float.pi/2,axis:[1,0,0]);scene.panels.addChild(panel)
                }
            }
            if let video=attachments.entity(for:"dockedVideo") {video.scale=SIMD3(repeating:model.videoScale);video.orientation=simd_quatf(angle:-0.12,axis:[1,0,0]);scene.videoPanel.addChild(video)}
            for (id,position) in [("moveLeft",SIMD3<Float>(-0.17,0.003,0)),("moveRight",SIMD3<Float>(0.17,0.003,0)),("moveAway",SIMD3<Float>(0,0.003,-0.19)),("moveNear",SIMD3<Float>(0,0.003,0.19)),("moveUp",SIMD3<Float>(0.19,0.003,-0.11)),("moveDown",SIMD3<Float>(0.19,0.003,0.11)),("moveDone",SIMD3<Float>(0,0.003,-0.25))] {
                if let control=attachments.entity(for:id) {
                    control.position=position;control.scale=SIMD3(repeating:0.5)
                    control.orientation=simd_quatf(angle:-Float.pi/2,axis:[1,0,0]);scene.moveControls.addChild(control)
                }
            }
            do { try await scene.loadHands() } catch { model.error="Could not load the hand holograms: \(error.localizedDescription)" }
            model.onRender = { [scene, model] frame, live, _ in scene.render(model:model,frame:frame,live:live) }
        } attachments: {
            Attachment(id:"dockedVideo") {
                Group {if model.dockedVideo {VideoReference(embedded:true)} else {Color.clear.frame(width:800,height:650)}}
            }
            Attachment(id:"tray") {PartsTray().opacity(model.course.trayLabels.isEmpty ? 0 : 1).allowsHitTesting(!model.course.trayLabels.isEmpty)}
            Attachment(id:"cueLabel") {Text(model.spatialCue?.label ?? "Place a marker in Place").font(.caption).padding(10).background(.black).foregroundStyle(.white).opacity(model.isPaperLesson || model.spatialCue == nil ? 0 : 1).allowsHitTesting(false)}
            Attachment(id:"lesson") { LessonPanel() }
            Attachment(id:"transport") { PlaybackControls() }
            Attachment(id:"tools") { SpatialControls() }
            Attachment(id:"moveLeft") {PaperMoveControl(label:"← LEFT",delta:[-0.01,0,0])}
            Attachment(id:"moveRight") {PaperMoveControl(label:"RIGHT →",delta:[0.01,0,0])}
            Attachment(id:"moveAway") {PaperMoveControl(label:"↑ AWAY",delta:[0,0,-0.01])}
            Attachment(id:"moveNear") {PaperMoveControl(label:"↓ CLOSER",delta:[0,0,0.01])}
            Attachment(id:"moveUp") {PaperMoveControl(label:"+ HEIGHT",delta:[0,0.002,0])}
            Attachment(id:"moveDown") {PaperMoveControl(label:"− HEIGHT",delta:[0,-0.002,0])}
            Attachment(id:"moveDone") {PaperMoveFinish()}
        }
        .gesture(SpatialTapGesture().targetedToAnyEntity().onEnded {value in
            guard model.workspaceVisible,!model.busyRecording,!model.adjustingPlacement else{return}
            if value.entity.name.hasPrefix("lab-") {model.selectLabPart(value.entity.name);return}
            guard model.course.mechanicalModel == .engine else{return}
            let prefix="engine-part-",name=value.entity.name
            if name.hasPrefix(prefix) {model.engineFocus=EnginePart(rawValue:String(name.dropFirst(prefix.count)))}
        })
        .task {
            await model.entered()
            while !Task.isCancelled {
                model.tick()
                try? await Task.sleep(for:.milliseconds(16))
            }
        }
        .task {await voice.run(model)}
        .task(id:model.avatarEnabled) {
            guard model.avatarEnabled else {model.avatarStatus="Off";return}
            model.avatarStatus="Loading human model…"
            do {try await scene.human.load();if model.avatarEnabled {model.avatarStatus="Ready · record both hands for mirrored replay"}}
            catch {if !Task.isCancelled && model.avatarEnabled {model.avatarStatus="Could not load the human model. Try toggling it again."}}
        }
        .onChange(of:model.placed) { _,placed in if placed {dismissWindow(id:"home");if model.automaticVideo && model.currentStep.segment != nil {model.showVideo()}} else if model.immersive {openWindow(id:"home")} }
        .onChange(of:model.trackingIssue) {_,issue in
            if issue != nil {openWindow(id:"home")} else if model.placed {dismissWindow(id:"home")}
        }
        .onDisappear { model.leftStudio() }
        .onChange(of:phase) { _,phase in if phase != .active { model.suspend() } else { model.resumeInteraction() } }
    }
}
