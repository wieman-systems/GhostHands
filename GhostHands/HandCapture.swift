import ARKit
import Observation
import QuartzCore
import simd

@MainActor @Observable
final class HandCapture {
    var status = "Open the studio to connect hand tracking."
    var ready = false
    @ObservationIgnored private var session: ARKitSession?
    @ObservationIgnored private var world: WorldTrackingProvider?
    @ObservationIgnored private var tasks: [Task<Void, Never>] = []
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var left: TimedHand?
    @ObservationIgnored private var right: TimedHand?

    @ObservationIgnored var onWorkspaceAnchor:((simd_float4x4?,Bool)->Void)?
    @ObservationIgnored private var workspaceAnchorID:UUID?
    @ObservationIgnored private var anchorRequest=UUID()
    func clearWorkspaceAnchor() {
        anchorRequest=UUID()
        let old=workspaceAnchorID;workspaceAnchorID=nil
        if let old,let world {Task {try? await world.removeAnchor(forID:old)}}
    }
    func anchorWorkspace(_ transform:simd_float4x4) {
        clearWorkspaceAnchor()
        #if !targetEnvironment(simulator)
        guard let world,world.state == .running else {onWorkspaceAnchor?(nil,false);return}
        let anchor=WorldAnchor(originFromAnchorTransform:transform),ticket=anchorRequest,sessionTicket=generation
        workspaceAnchorID=anchor.id
        tasks.append(Task { [weak self] in
            do {
                try await world.addAnchor(anchor)
                guard let self,self.anchorRequest==ticket,self.generation==sessionTicket,!Task.isCancelled else {try? await world.removeAnchor(anchor);return}
            } catch {
                guard let self,self.anchorRequest==ticket,self.generation==sessionTicket else{return}
                self.onWorkspaceAnchor?(nil,false)
            }
        })
        #endif
    }

    static let jointNames: [HandSkeleton.JointName] = [.wrist, .thumbKnuckle, .thumbIntermediateBase, .thumbIntermediateTip, .thumbTip,
        .indexFingerMetacarpal, .indexFingerKnuckle, .indexFingerIntermediateBase, .indexFingerIntermediateTip, .indexFingerTip,
        .middleFingerMetacarpal, .middleFingerKnuckle, .middleFingerIntermediateBase, .middleFingerIntermediateTip, .middleFingerTip,
        .ringFingerMetacarpal, .ringFingerKnuckle, .ringFingerIntermediateBase, .ringFingerIntermediateTip, .ringFingerTip,
        .littleFingerMetacarpal, .littleFingerKnuckle, .littleFingerIntermediateBase, .littleFingerIntermediateTip, .littleFingerTip]

    func start() async {
        stop()
        let token = generation
        #if targetEnvironment(simulator)
        status = "Simulator · illustrated playback available. Real recording needs Vision Pro."
        return
        #else
        guard HandTrackingProvider.isSupported, WorldTrackingProvider.isSupported else {
            status = "Hand or world tracking is unavailable on this device."; return
        }
        let session = ARKitSession(), hands = HandTrackingProvider(), world = WorldTrackingProvider()
        self.session = session; self.world = world
        let auth = await session.requestAuthorization(for: [.handTracking, .worldSensing])
        guard token == generation, !Task.isCancelled else { return }
        guard auth.values.allSatisfy({ $0 == .allowed }) else {
            status = "Allow Hands and World Sensing in Settings, then reopen the studio."; return
        }
        do {
            try await session.run([hands, world])
            guard token == generation, !Task.isCancelled else { session.stop(); return }
            ready = true
            status = "Tracking connected · keep your hands in view."
            tasks.append(Task { [weak self] in
                for await update in hands.anchorUpdates {
                    guard let self, token == self.generation, !Task.isCancelled else { break }
                    let anchor = update.anchor
                    var snapshot: TimedHand?
                    if update.event != .removed, anchor.isTracked, let skeleton = anchor.handSkeleton {
                        let joints = Self.jointNames.map { name -> SIMD3<Float>? in
                            let joint = skeleton.joint(name)
                            guard joint.isTracked else { return nil }
                            let matrix = anchor.originFromAnchorTransform * joint.anchorFromJointTransform
                            let p = SIMD3<Float>(matrix.columns.3.x, matrix.columns.3.y, matrix.columns.3.z)
                            return p.isFinite ? p : nil
                        }
                        let pose = HandPose(joints: joints)
                        if pose.isUsable { snapshot = TimedHand(time: update.timestamp, pose: pose) }
                    }
                    if anchor.chirality == .left { self.left = snapshot } else { self.right = snapshot }
                }
            })
            tasks.append(Task { [weak self] in
                for await update in world.anchorUpdates {
                    guard let self,token==self.generation,!Task.isCancelled else{break}
                    guard update.anchor.id==self.workspaceAnchorID else{continue}
                    self.onWorkspaceAnchor?(update.anchor.originFromAnchorTransform,update.event != .removed && update.anchor.isTracked)
                }
            })
            tasks.append(Task { [weak self] in
                for await event in session.events {
                    guard let self, token == self.generation, !Task.isCancelled else { break }
                    switch event {
                    case .authorizationChanged(_, let status) where status != .allowed:
                        self.ready = false; self.clear(); self.onWorkspaceAnchor?(nil,false); self.status = "Tracking permission changed. Reopen the studio after allowing access."
                    case .dataProviderStateChanged(_, let state, let error):
                        if state == .running {
                            self.ready = hands.state == .running && world.state == .running
                            if self.ready {
                                self.status = "Tracking connected · keep your hands in view."
                                let request=self.anchorRequest
                                if let id=self.workspaceAnchorID,let anchors=await world.allAnchors,
                                   token==self.generation,request==self.anchorRequest,let anchor=anchors.first(where:{$0.id==id}) {
                                    self.onWorkspaceAnchor?(anchor.originFromAnchorTransform,anchor.isTracked)
                                }
                            }
                        } else {
                            self.ready = false; self.clear();if world.state != .running {self.onWorkspaceAnchor?(nil,false)}
                            self.status = error == nil ? "Tracking interrupted. Reopen the studio if it does not recover." : "Tracking stopped: \(error!.localizedDescription)"
                        }
                    default: break
                    }
                }
            })
        } catch { status = "Could not start tracking: \(error.localizedDescription)" }
        #endif
    }
    func snapshot(at now: Double) -> MotionFrame {
        guard ready else { return MotionFrame(time: now, left: nil, right: nil) }
        return MotionFrame(time: now, left: left?.fresh(at: now), right: right?.fresh(at: now))
    }
    func headTransform() -> simd_float4x4? {
        guard let world, world.state == .running,
              let anchor = world.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()), anchor.isTracked else { return nil }
        return anchor.originFromAnchorTransform
    }
    func clear() { left = nil; right = nil }
    func stop() {
        clearWorkspaceAnchor();generation = UUID(); tasks.forEach { $0.cancel() }; tasks.removeAll()
        session?.stop(); session = nil; world = nil; ready = false; clear()
    }
}
