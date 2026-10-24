import SwiftUI
import WatchConnectivity

final class PhoneRelay:NSObject,ObservableObject,WCSessionDelegate {
    let link=HapticNearby(receiver:true)
    @Published var watchStatus="Open the Watch companion"
    @Published var active=false
    private var gate=HapticPulseGate()
    private var timer:Timer?
    private var lastDiagnostic=""
    override init() {
        super.init()
        if WCSession.isSupported() {WCSession.default.delegate=self;WCSession.default.activate()}
        link.onPulse={[weak self] message in self?.forward(message)}
        link.onConnection={[weak self] in self?.publishState()}
    }
    func start() {active=true;link.start();timer?.invalidate();timer=Timer.scheduledTimer(withTimeInterval:1,repeats:true) {[weak self] _ in self?.publishState()};publishState()}
    func stop() {active=false;timer?.invalidate();timer=nil;link.stop();publishState()}
    private var ready:Bool {active && WCSession.isSupported() && WCSession.default.activationState == .activated && WCSession.default.isReachable}
    func publishState() {
        let session=WCSession.default
        if !WCSession.isSupported() {watchStatus="Watch connectivity is unavailable"}
        else if session.activationState != .activated {watchStatus="Connecting to Watch service…"}
        else if !session.isPaired {watchStatus="No Apple Watch is paired with this iPhone"}
        else if !session.isWatchAppInstalled {watchStatus="Watch app not installed — check the iPhone Watch app"}
        else if !session.isReachable {watchStatus="Open GhostHands Haptics on your Watch"}
        else {watchStatus="Watch ready"}
        link.send(HapticMessage(kind:"state",ready:ready,note:watchStatus))
        let diagnostic:[String:Any]=["paired":session.isPaired,"watchAppInstalled":session.isWatchAppInstalled,"watchReachable":session.isReachable,"phoneRelayActive":active,"phoneLinked":link.connected,"status":watchStatus,"build":Bundle.main.object(forInfoDictionaryKey:"CFBundleVersion") as? String ?? ""]
        if let data=try? JSONSerialization.data(withJSONObject:diagnostic,options:[.sortedKeys]),let text=String(data:data,encoding:.utf8),text != lastDiagnostic {
            lastDiagnostic=text
            var saved=diagnostic;saved["updatedAt"]=ISO8601DateFormatter().string(from:Date())
            if let output=try? JSONSerialization.data(withJSONObject:saved,options:[.sortedKeys]),let url=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask).first {try? output.write(to:url.appendingPathComponent("haptics-status.json"),options:.atomic)}
        }
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
            if relay.active {Text(link.code).font(.system(size:44,weight:.bold,design:.monospaced));Text("Choose \(link.deviceLabel) on the headset").font(.headline);Text(link.status)}
            Text("1. Open this app on Apple Watch.\n2. Inside GhostHands on the headset: enter the workspace, then Settings → Watch.\n3. Use the keypad, then choose this iPhone.").frame(maxWidth:.infinity,alignment:.leading)
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
