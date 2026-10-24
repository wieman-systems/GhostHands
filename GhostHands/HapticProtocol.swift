import Foundation

// Only ephemeral UI pulses cross the link. No recording or hand coordinates leave Vision Pro.
struct HapticMessage:Codable {
    var kind:String
    var id:String=UUID().uuidString
    var sentAt:TimeInterval=Date().timeIntervalSince1970
    var ready:Bool?=nil
    var note:String?=nil
    static func decode(_ data:Data)->HapticMessage? {
        guard data.count<=2048,let value=try? JSONDecoder().decode(Self.self,from:data),
              ["tap","state","ack"].contains(value.kind),UUID(uuidString:value.id) != nil,
              value.sentAt.isFinite,(value.note?.count ?? 0)<=120 else{return nil}
        return value
    }
    var data:Data? {try? JSONEncoder().encode(self)}
}
struct HapticPulseGate {
    private var recent:[String]=[]
    private var lastPulse:TimeInterval = -.infinity
    mutating func accept(_ message:HapticMessage,now:TimeInterval,available:Bool)->Bool {
        // Drop stale, duplicated, background and burst inputs. Never replay them later.
        guard message.kind=="tap",message.sentAt.isFinite,now.isFinite,
              UUID(uuidString:message.id) != nil,
              !recent.contains(message.id) else{return false}
        recent.append(message.id);if recent.count>128 {recent.removeFirst()}
        guard available,now-message.sentAt >= -0.1,now-message.sentAt<=0.6,
              now-lastPulse>=0.09 else{return false}
        lastPulse=now;return true
    }
}
struct LeftButtonPulse {
    private var left=false
    private var pressed=false
    private var emitted=false
    mutating func hand(_ isLeft:Bool,enabled:Bool)->Bool {left=isLeft;return consume(enabled)}
    mutating func press(_ value:Bool,enabled:Bool)->Bool {
        pressed=value
        if !value {reset();return false}
        return consume(enabled)
    }
    mutating func reset() {left=false;pressed=false;emitted=false}
    private mutating func consume(_ enabled:Bool)->Bool {
        guard enabled,pressed,left,!emitted else{return false};emitted=true;return true
    }
}
