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
    let paper = PaperVisual()

    func loadHands() async throws {
        try await ghostLeft.load(side:"left")
        try await ghostRight.load(side:"right")
    }
    let ghostLeft = HologramHand()
    let ghostRight = HologramHand()
    var guideKey = ""
    init() {
        root.addChild(guides)
        root.addChild(paper.root)
        root.addChild(ghostLeft.root); root.addChild(ghostRight.root)

    }
    func render(model: StudioModel, frame: MotionFrame?, live: MotionFrame) {
        root.transform = Transform(matrix: model.workspace)
        paper.update(step:model.lesson,seconds:model.elapsed,width:model.paperSide,visible:model.placed && model.showGuides && model.selected?.isIllustration == true)
        ghostLeft.update(model.placed && model.showHands ? frame?.left : nil); ghostRight.update(model.placed && model.showHands ? frame?.right : nil)
        guides.isEnabled = model.showGuides || !model.placed
        let key = "\(model.step)-\(model.paperSide)-\(model.paperHeight)-\(model.placed)-\(model.placementReady)"
        if guideKey != key { guideKey = key; drawGuide(step:model.lesson,width:model.placed ? model.paperSide : LetterPaper.width,height:model.placed ? model.paperHeight : LetterPaper.height,preview:!model.placed,ready:model.placementReady) }
        root.isEnabled = model.placed || model.placementReady
        panels.isEnabled = model.placed
        panels.transform = Transform(matrix:model.workspace)
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
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openWindow) private var openWindow
    @Environment(\.scenePhase) private var phase
    @State private var scene = StudioScene()
    var body: some View {
        RealityView { content, attachments in
            content.add(scene.root); content.add(scene.panels)
            for (id,position) in [("lesson",SIMD3<Float>(-0.30,0.002,0)),("transport",SIMD3<Float>(0,0.002,0.25)),("tools",SIMD3<Float>(0.30,0.002,0))] {
                if let panel=attachments.entity(for:id) {
                    panel.position=position;panel.scale=SIMD3(repeating:0.48)
                    panel.orientation=simd_quatf(angle:-Float.pi/2,axis:[1,0,0]);scene.panels.addChild(panel)
                }
            }
            do { try await scene.loadHands() } catch { model.error="Could not load the hand holograms: \(error.localizedDescription)" }
            model.onRender = { [scene, model] frame, live, _ in scene.render(model:model,frame:frame,live:live) }
        } attachments: {
            Attachment(id:"lesson") { LessonPanel() }
            Attachment(id:"transport") { PlaybackControls() }
            Attachment(id:"tools") { SpatialControls() }
        }
        .task {
            await model.entered()
            while !Task.isCancelled {
                model.tick()
                try? await Task.sleep(for:.milliseconds(16))
            }
        }
        .onChange(of:model.placed) { _,placed in if placed {dismissWindow(id:"home")} else if model.immersive {openWindow(id:"home")} }
        .onDisappear { model.leftStudio() }
        .onChange(of:phase) { _,phase in if phase != .active { model.suspend() } else { model.resumeInteraction() } }
    }
}
