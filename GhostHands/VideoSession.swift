import Foundation
import Observation

struct VideoCommand: Codable, Equatable {
    var serial:Int
    var videoID:String
    var start:Double
    var end:Double?
    var seek:Bool
    var play:Bool
    var rate:Double
    var loop:Bool
}
@MainActor @Observable final class VideoSession {
    var visible=false
    var failed=false
    var playerGeneration=0
    var ready=false
    var playing=false
    var buffering=false
    var waiting=false
    var currentTime=0.0
    var duration=0.0
    var actualRate=1.0
    var status="Open the video to follow the current step."
    var command:VideoCommand?
    var acknowledgedSerial = -1
    var revision=0
    var lastUpdate=Date.distantPast
    var audioBusy:Bool {visible && (playing || buffering || waiting)}
    func request(videoID:String,segment:VideoSegment?,time:Double?=nil,seek:Bool=true,play:Bool,rate:Double,loop:Bool=false) {
        guard !failed else{return}
        revision += 1
        command = .init(serial:revision,videoID:videoID,start:time ?? segment?.start ?? 0,end:segment?.end,seek:seek,play:play,rate:rate,loop:loop)
        waiting=visible && play;status=play ? "Loading this step…" : "Paused"
    }
    @discardableResult func receive(serial:Int,videoID:String,time:Double,duration:Double,state:Int,rate:Double)->Bool {
        guard let command,serial==command.serial,videoID==command.videoID,time.isFinite,duration.isFinite,time>=0 else{return false}
        acknowledgedSerial=serial;currentTime=time;self.duration=duration;actualRate=rate.isFinite ? rate : 1;lastUpdate=Date()
        if state==1 || state==2 {failed=false;ready=true}
        playing=state==1;buffering=state==3;waiting=false
        status=playing ? "Video and guide linked" : buffering ? "Buffering…" : "Paused · take your time"
        return true
    }
    func fail(_ message:String) {failed=true;ready=false;waiting=false;playing=false;buffering=false;status=message}
    func close() {visible=false;ready=false;playing=false;buffering=false;waiting=false;status="Video closed"}
}

enum VoiceCommand:Equatable {case next,back,slower,faster,replay,pause,play,read,stopListening}
enum VoiceCommands {
    static func parse(_ text:String,videoAudible:Bool=false)->VoiceCommand? {
        var words=text.lowercased().components(separatedBy:CharacterSet.alphanumerics.inverted).filter{!$0.isEmpty}
        let wake=words.prefix(2)==["ghost","hands"] || words.first=="ghosthands"
        if videoAudible && !wake{return nil}
        if words.first=="ghosthands" {words.removeFirst()} else if words.prefix(2)==["ghost","hands"] {words.removeFirst(2)}
        if words.first=="please" {words.removeFirst()};if words.last=="please" {words.removeLast()}
        switch words.joined(separator:" ") {
        case "next","next step":return .next
        case "back","go back","previous step":return .back
        case "slow down","slower":return .slower
        case "speed up","faster":return .faster
        case "show that again","show me that again","again","replay","repeat step":return .replay
        case "pause","stop":return .pause
        case "play","resume","continue":return .play
        case "read instructions","read that","read this step":return .read
        case "stop listening","microphone off":return .stopListening
        default:return nil
        }
    }
}
