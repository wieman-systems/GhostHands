import RealityKit
import Foundation

@MainActor final class HumanReplay {
    let root=Entity()
    private var rig:AvatarRig?
    private var skins:[(ModelEntity,[Int])]=[]
    private var loaded=false
    func load() async throws {
        guard !loaded else{return}
        guard let modelURL=Bundle.main.url(forResource:"HumanReplay",withExtension:"usdz",subdirectory:"AvatarResources"),
              let rigURL=Bundle.main.url(forResource:"HumanReplay",withExtension:"json",subdirectory:"AvatarResources") else {throw MotionError.invalid}
        let spec=try JSONDecoder().decode(AvatarRig.self,from:Data(contentsOf:rigURL))
        let entity=try await Entity(contentsOf:modelURL)
        try Task.checkCancellation()
        guard !loaded else{return}
        var models:[(ModelEntity,[Int])]=[]
        func visit(_ e:Entity) {
            if let m=e as? ModelEntity,!m.jointNames.isEmpty {
                let mapping=m.jointNames.compactMap {name in spec.names.firstIndex(of:String(name.split(separator:"/").last!))}
                if mapping.count==m.jointNames.count {models.append((m,mapping))}
            }
            for child in e.children {visit(child)}
        }
        visit(entity)
        guard !models.isEmpty else{throw MotionError.invalid}
        rig=spec;skins=models;root.addChild(entity);loaded=true;root.isEnabled=false
    }
    func update(frame:MotionFrame?,enabled:Bool,tableHeight:Float) {
        guard enabled,loaded,let rig,let frame,AvatarRetargeting.canReplay(frame:frame,rig:rig,tableHeight:tableHeight) else {root.isEnabled=false;return}
        root.isEnabled=true;root.position=[0,-tableHeight,-0.45]
        let matrices=AvatarRetargeting.matrices(frame:frame,rig:rig,tableHeight:tableHeight)
        for (skin,map) in skins {skin.jointTransforms=map.map {Transform(matrix:matrices[$0])}}
    }
}
