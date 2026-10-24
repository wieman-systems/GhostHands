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
    private let keys=["1","2","3","4","5","6","7","8","9","CLEAR","0","⌫"]
    var body:some View {
        VStack(alignment:.leading,spacing:6) {
            Toggle("Connect Watch companion",isOn:Binding(get:{haptics.enabled},set:{haptics.setEnabled($0)}))
            Text(link.status).font(.caption).lineLimit(1)
            if haptics.enabled,!link.connected {
                HStack(spacing:6) {
                    ForEach(0..<6) {index in
                        Text(index<link.code.count ? String(Array(link.code)[index]) : "–")
                            .font(.system(size:22,weight:.semibold,design:.monospaced))
                            .frame(maxWidth:.infinity).frame(height:30)
                            .overlay(Rectangle().stroke(.white.opacity(0.4)))
                    }
                }.accessibilityLabel("Pairing code: \(link.code.isEmpty ? "empty" : link.code)")
                LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:6),count:3),spacing:6) {
                    ForEach(keys,id:\.self) {key in
                        Button(key) {
                            if key=="CLEAR" {link.code=""}
                            else if key=="⌫" {if !link.code.isEmpty {link.code.removeLast()}}
                            else if link.code.count<6 {link.code += key}
                        }.accessibilityLabel(key=="⌫" ? "Delete last digit" : key)
                    }
                }
                HStack(spacing:8) {
                    if link.peers.count==1 {
                        Button("PAIR IPHONE") {if let peer=link.peers.first {link.pair(peer)}}.disabled(link.code.count != 6)
                    } else {
                        Menu("PAIR IPHONE") {
                            ForEach(Array(link.peers.enumerated()),id:\.element) {index,peer in
                                Button("\(peer.displayName) \(index+1)") {link.pair(peer)}
                            }
                        }.disabled(link.code.count != 6 || link.peers.isEmpty)
                    }
                    Button("SEARCH AGAIN") {link.start()}
                }
                Text("Tap the six digits shown on your iPhone, then Pair iPhone. Keep both companion apps open.").font(.caption2).lineLimit(2)
            } else if haptics.enabled {
                Button("TEST WATCH TAP") {WatchHaptics.shared.pulse()}.disabled(!link.watchReady)
                if let ms=link.latencyMS {Text("Last acknowledgement: \(ms) ms round trip").font(.caption)}
                Button("DISCONNECT") {haptics.stop()}
            } else {
                Text("Open GhostHands Haptics on iPhone and Watch, then turn on the connection here. Wear the Watch on your left wrist.").font(.caption)
            }
            Text("Automatic button feedback is paused. Test Watch Tap checks the connection.").font(.caption2).foregroundStyle(.secondary).lineLimit(2)
        }.environment(\.compactControls,true)
        #if targetEnvironment(simulator)
        .task {if ProcessInfo.processInfo.arguments.contains("--watch-keypad-preview") {haptics.setEnabled(true)}}
        #endif
    }
}
#endif
