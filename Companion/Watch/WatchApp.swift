import SwiftUI
import WatchKit
import WatchConnectivity

final class WatchReceiver:NSObject,ObservableObject,WCSessionDelegate {
    @Published var count=0
    @Published var status="Ready for iPhone"
    private var gate=HapticPulseGate()
    override init() {super.init();WCSession.default.delegate=self;WCSession.default.activate()}
    func session(_ session:WCSession,activationDidCompleteWith activationState:WCSessionActivationState,error:Error?) {
        DispatchQueue.main.async {[weak self] in self?.status=error == nil ? "Ready for iPhone" : "Connection unavailable"}
    }
    func session(_ session:WCSession,didReceiveMessage message:[String:Any],replyHandler:@escaping([String:Any])->Void) {
        guard let data=message["pulse"] as? Data,let pulse=HapticMessage.decode(data) else {replyHandler(["played":false]);return}
        DispatchQueue.main.async {[weak self] in
            guard let self else {replyHandler(["played":false]);return}
            let available=WKApplication.shared().applicationState != .background
            let play=self.gate.accept(pulse,now:Date().timeIntervalSince1970,available:available)
            if play {WKInterfaceDevice.current().play(.click);self.count += 1;self.status="Receiving taps"}
            replyHandler(["played":play])
        }
    }
}
@main struct HapticsWatchApp:App {
    @StateObject private var receiver=WatchReceiver()
    var body:some Scene {WindowGroup {
        VStack(spacing:10) {
            Image(systemName:"hand.tap").font(.title)
            Text("GhostHands").font(.headline)
            Text(receiver.status).font(.caption)
            Text("\(receiver.count) taps").monospacedDigit()
            Button("Test tap") {WKInterfaceDevice.current().play(.click)}
            Text("Keep this app frontmost. Wear on your left wrist.").font(.footnote).multilineTextAlignment(.center)
        }
    }}
}
