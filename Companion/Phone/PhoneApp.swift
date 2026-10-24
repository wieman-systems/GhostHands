import SwiftUI
import WatchConnectivity

final class PhoneRelay:NSObject,ObservableObject,WCSessionDelegate {
    let link=HapticNearby(receiver:true)
    @Published var watchStatus="Open the Watch companion"
    @Published var active=false
    private var gate=HapticPulseGate()
    private var timer:Timer?
    override init() {
        super.init()
        if WCSession.isSupported() {WCSession.default.delegate=self;WCSession.default.activate()}
        link.onPulse={[weak self] message in self?.forward(message)}
        link.onConnection={[weak self] in self?.publishState()}
    }
    func start() {active=true;link.start();timer?.invalidate();timer=Timer.scheduledTimer(withTimeInterval:1,repeats:true) {[weak self] _ in self?.publishState()};publishState()}
    func stop() {active=false;timer?.invalidate();timer=nil;link.stop()}
    private var ready:Bool {active && WCSession.isSupported() && WCSession.default.activationState == .activated && WCSession.default.isReachable}
    func publishState() {
        watchStatus=ready ? "Watch ready" : "Open GhostHands Haptics on your Watch"
        link.send(HapticMessage(kind:"state",ready:ready,note:watchStatus))
    }
    private func forward(_ message:HapticMessage) {
        guard gate.accept(message,now:Date().timeIntervalSince1970,available:ready),let data=message.data else{return}
        WCSession.default.sendMessage(["pulse":data],replyHandler:{[weak self] reply in
            DispatchQueue.main.async {self?.link.send(HapticMessage(kind:"ack",id:message.id,ready:reply["played"] as? Bool,note:"Watch dropped stale or inactive tap"))}
        },errorHandler:{[weak self] _ in DispatchQueue.main.async {self?.publishState()}})
    }
    func session(_ session:WCSession,activationDidCompleteWith activationState:WCSessionActivationState,error:Error?) {DispatchQueue.main.async {[weak self] in self?.publishState()}}
    func sessionReachabilityDidChange(_ session:WCSession) {DispatchQueue.main.async {[weak self] in self?.publishState()}}
    func sessionDidBecomeInactive(_ session:WCSession) {DispatchQueue.main.async {[weak self] in self?.publishState()}}
    func sessionDidDeactivate(_ session:WCSession) {session.activate()}
}
struct PhoneView:View {
    @ObservedObject var relay:PhoneRelay
    @ObservedObject var link:HapticNearby
    @Environment(\.scenePhase) private var phase
    var body:some View {
        VStack(spacing:24) {
            Image(systemName:"applewatch.radiowaves.left.and.right").font(.system(size:52))
            Text("GhostHands Haptics").font(.largeTitle.bold())
            Text(relay.watchStatus).font(.headline)
            if relay.active {Text(link.code).font(.system(size:44,weight:.bold,design:.monospaced));Text(link.status)}
            Text("1. Open this app on Apple Watch.\n2. On Vision Pro: Settings → Watch.\n3. Enable feedback and enter this code.").frame(maxWidth:.infinity,alignment:.leading)
            Button(relay.active ? "Restart pairing" : "Start pairing") {relay.start()}.buttonStyle(.borderedProminent)
            if relay.active {Button("Stop") {relay.stop()}}
            Text("Keep this iPhone app open and the Watch app frontmost. Only short button-tap messages are shared locally; no hand recordings are sent.").font(.footnote).foregroundStyle(.secondary)
        }.padding(30).onChange(of:phase) {_,p in if p == .background {relay.stop();UIApplication.shared.isIdleTimerDisabled=false}}
        .onChange(of:relay.active) {_,value in UIApplication.shared.isIdleTimerDisabled=value}
    }
}
@main struct HapticsPhoneApp:App {
    @StateObject private var relay=PhoneRelay()
    var body:some Scene {WindowGroup {PhoneView(relay:relay,link:relay.link)}}
}
