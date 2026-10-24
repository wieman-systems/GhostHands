#if os(visionOS)
import SwiftUI

final class WatchHaptics:ObservableObject {
    static let shared=WatchHaptics()
    let link=HapticNearby(receiver:false)
    @Published private(set) var enabled=false
    private var gate=HapticPulseGate()
    func pulse() {
        if gate.accept(HapticMessage(kind:"tap"),now:Date().timeIntervalSince1970,available:enabled) {link.pulse()}
    }
    func setEnabled(_ value:Bool) {if value {enabled=true;link.start()} else {stop()}}
    func stop() {enabled=false;link.stop()}
}
struct WatchHapticsPanel:View {
    @ObservedObject private var link=WatchHaptics.shared.link
    @ObservedObject private var haptics=WatchHaptics.shared
    var body:some View {
        VStack(alignment:.leading,spacing:10) {
            Toggle("Connect Watch companion",isOn:Binding(get:{haptics.enabled},set:{haptics.setEnabled($0)}))
            Text(link.status).font(.headline).lineLimit(2)
            if haptics.enabled,!link.connected {
                TextField("6-digit iPhone code",text:$link.code).textFieldStyle(.roundedBorder).keyboardType(.numberPad)
                ForEach(link.peers,id:\.self) {peer in Button("PAIR WITH IPHONE") {link.pair(peer)}}
                Button("SEARCH AGAIN") {link.start()}
            }
            if haptics.enabled,link.connected {
                Button("TEST WATCH TAP") {WatchHaptics.shared.pulse()}.disabled(!link.watchReady)
                if let ms=link.latencyMS {Text("Last acknowledgement: \(ms) ms round trip").font(.caption)}
                Button("DISCONNECT") {haptics.stop()}
            }
            Text("Open GhostHands Haptics on iPhone and Watch. Keep the iPhone app open and Watch app frontmost. Wear the Watch on your left wrist.").font(.caption)
            Text("Automatic button feedback is paused while input handling is repaired. Use Test Watch Tap to check the connection.").font(.caption2).foregroundStyle(.secondary)
        }
    }
}
#endif
