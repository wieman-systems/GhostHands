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
struct LeftWatchFeedback:ViewModifier {
    let pressed:Bool
    let enabled:Bool
    @Environment(\.scenePhase) private var phase
    @State private var pulse=LeftButtonPulse()
    func body(content:Content)->some View {
        content.simultaneousGesture(SpatialEventGesture().onChanged {events in
            for event in events {
                if event.phase == .cancelled {pulse.reset()}
                else if event.phase == .active {
                    if pulse.hand(event.chirality == .left,enabled:enabled) {WatchHaptics.shared.pulse()}
                }
            }
        }.onEnded {_ in pulse.reset()})
        .onChange(of:pressed) {_,value in if pulse.press(value,enabled:enabled) {WatchHaptics.shared.pulse()}}
        .onChange(of:enabled) {_,value in if !value {pulse.reset()}}
        .onChange(of:phase) {_,value in if value == .background {pulse.reset();WatchHaptics.shared.stop()}}
        .onDisappear {pulse.reset()}
    }
}
struct WatchHapticsPanel:View {
    @ObservedObject private var link=WatchHaptics.shared.link
    @ObservedObject private var haptics=WatchHaptics.shared
    var body:some View {
        VStack(alignment:.leading,spacing:10) {
            Toggle("Left-hand Watch feedback",isOn:Binding(get:{haptics.enabled},set:{haptics.setEnabled($0)}))
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
            Text("Custom GhostHands buttons only. Unknown/right-hand input stays silent. No delayed replay; timing depends on the connection.").font(.caption2).foregroundStyle(.secondary)
        }
    }
}
#endif
