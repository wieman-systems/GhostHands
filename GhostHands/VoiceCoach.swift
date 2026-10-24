import SwiftUI
import Speech
import AVFoundation
import Observation

@MainActor @Observable final class VoiceCoach:NSObject,AVSpeechSynthesizerDelegate,AVAudioPlayerDelegate {
    var listening=false
    var status="Voice off"
    var lastCommand=""
    private let engine=AVAudioEngine()
    private let speaker=AVSpeechSynthesizer()
    private var player:AVAudioPlayer?
    private var activeUtterance:AVSpeechUtterance?
    var narratorName="Studio voice · AI-generated"
    private var pendingManual=false
    private var pendingStepKey=""
    private var seenManual=0
    private let recognizer=SFSpeechRecognizer(locale:Locale(identifier:"en-US"))
    private var request:SFSpeechAudioBufferRecognitionRequest?
    private var recognition:SFSpeechRecognitionTask?
    private var pendingCommand:Task<Void,Never>?
    private var restart:Task<Void,Never>?
    private var generation=0
    private var hasTap=false
    private var latestText=""
    private var consumedUtterance=false
    private var pendingNarration:String?
    private var seenNarration = -1
    private var quietSince=Date()
    private var speaking=false
    private var recognitionAfter=Date.distantPast
    private weak var model:StudioModel?
    override init(){super.init();speaker.delegate=self}
    func run(_ model:StudioModel) async {
        self.model=model;seenNarration = -1;seenManual=model.manualNarrationRevision
        while !Task.isCancelled {
            let active=model.immersive && model.interactionActive && model.workspaceVisible && model.placed && !model.busyRecording && !model.isAuthoring
            if !active {pendingNarration=nil;stopSpeaking();if listening {stopListening()}}
            else {
                if seenNarration != model.narrationRevision {seenNarration=model.narrationRevision;if !pendingManual || pendingStepKey != model.cueKey {pendingManual=false;pendingStepKey=model.cueKey;pendingNarration=model.automaticNarrationAllowed ? model.instructionToRead : nil;stopSpeaking();quietSince=Date()}}
                if seenManual != model.manualNarrationRevision {seenManual=model.manualNarrationRevision;pendingManual=true;pendingStepKey=model.cueKey;pendingNarration=model.instructionToRead;stopSpeaking();quietSince=Date()}
                if !model.automaticNarrationAllowed && !pendingManual {pendingNarration=nil;stopSpeaking()}
                if model.video.audioBusy {stopSpeaking();quietSince=Date()}
                else if let text=pendingNarration,(model.automaticNarrationAllowed || pendingManual),!speaking,Date().timeIntervalSince(quietSince)>0.8 {
                    pendingNarration=nil;speaking=true
                    speak(text,natural:model.naturalNarration)
                }
            }
            try? await Task.sleep(for:.milliseconds(100))
        }
        stopListening();stopSpeaking();pendingNarration=nil;self.model=nil
    }
    private func speak(_ text:String,natural:Bool) {
        if natural,let url=Bundle.main.url(forResource:NarrationPolicy.assetName(for:text),withExtension:"mp3",subdirectory:"NarrationResources"),let audio=try? AVAudioPlayer(contentsOf:url) {
            player=audio;audio.delegate=self;audio.prepareToPlay()
            if audio.play() {narratorName="Studio voice · AI-generated";return}
            player=nil
        }
        let available=AVSpeechSynthesisVoice.speechVoices().filter{$0.language=="en-US"}.sorted{$0.quality.rawValue>$1.quality.rawValue}
        let utterance=AVSpeechUtterance(string:text);utterance.voice=available.first ?? AVSpeechSynthesisVoice(language:"en-US")
        utterance.rate=0.47;utterance.pitchMultiplier=1;utterance.postUtteranceDelay=0.15
        narratorName=(utterance.voice?.name ?? "System voice")+" · device voice";activeUtterance=utterance;speaker.speak(utterance)
    }
    func cancelNarration() {pendingNarration=nil;pendingManual=false;stopSpeaking()}
    nonisolated func audioPlayerDidFinishPlaying(_ player:AVAudioPlayer,successfully flag:Bool) {Task{@MainActor in
        guard self.player === player else{return};self.player=nil;self.speaking=false;self.pendingManual=false;self.recognitionAfter=Date().addingTimeInterval(0.7)
        if self.listening {self.scheduleRestart(ticket:self.generation)}
    }}
    func toggle() {if listening {stopListening()} else {Task{await startListening()}}}
    private func startListening() async {
        guard model?.immersive==true,model?.placed==true,model?.busyRecording==false else{status="Place the workspace before enabling voice.";return}
        generation += 1;consumedUtterance=false;let ticket=generation;status="Requesting microphone access…"
        let authorized=await withCheckedContinuation { continuation in SFSpeechRecognizer.requestAuthorization {continuation.resume(returning:$0 == .authorized)} }
        let microphone=await AVAudioApplication.requestRecordPermission()
        guard ticket==generation,model?.immersive==true else{return}
        guard authorized,microphone else{status="Allow microphone and speech access in Settings to use voice.";return}
        guard let recognizer,recognizer.isAvailable,recognizer.supportsOnDeviceRecognition else{status="On-device English recognition is unavailable. Buttons still work.";return}
        do {
            let session=AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord,mode:.default,options:[.mixWithOthers])
            try session.setActive(true)
            let input=engine.inputNode
            // Echo cancellation reduces tutorial audio entering the recognizer.
            try? input.setVoiceProcessingEnabled(true)
            let format=input.outputFormat(forBus:0)
            guard format.sampleRate>0,format.channelCount>0 else{throw VoiceError.noInput}
            let request=SFSpeechAudioBufferRecognitionRequest();request.requiresOnDeviceRecognition=true;request.shouldReportPartialResults=true
            self.request=request
            input.installTap(onBus:0,bufferSize:1024,format:format){buffer,_ in request.append(buffer)};hasTap=true
            engine.prepare();try engine.start();listening=true;status="Listening · Next / Slow down / Show that again"
            recognition=recognizer.recognitionTask(with:request){[weak self] result,error in
                let text=result?.bestTranscription.formattedString
                let final=result?.isFinal ?? false
                Task{@MainActor in
                    guard let self,self.listening,self.generation==ticket else{return}
                    if let text {self.heard(text,ticket:ticket)}
                    if error != nil || final {self.scheduleRestart(ticket:ticket)}
                }
            }
        } catch {stopListening();status="Microphone unavailable. Try Voice again."}
    }
    private func heard(_ text:String,ticket:Int) {
        guard !consumedUtterance,!speaking,Date()>recognitionAfter,let model else{return}
        latestText=text;pendingCommand?.cancel()
        guard let command=VoiceCommands.parse(text,videoAudible:model.video.audioBusy) else{return}
        pendingCommand=Task{[weak self] in
            try? await Task.sleep(for:.milliseconds(450))
            guard !Task.isCancelled,let self,self.generation==ticket,self.latestText==text,!self.speaking,VoiceCommands.parse(text,videoAudible:model.video.audioBusy)==command else{return}
            self.consumedUtterance=true;self.lastCommand=text
            if command == .stopListening {self.stopListening();return}
            model.applyVoice(command);self.scheduleRestart(ticket:ticket)
        }
    }
    private func scheduleRestart(ticket:Int) {
        guard generation==ticket,listening,restart==nil else{return}
        restart=Task{[weak self] in
            try? await Task.sleep(for:.milliseconds(650))
            guard !Task.isCancelled,let self,self.generation==ticket,self.listening else{return}
            self.stopListening();self.restart=nil;await self.startListening()
        }
    }
    func stopListening() {
        generation += 1;listening=false;pendingCommand?.cancel();pendingCommand=nil;restart?.cancel();restart=nil
        engine.stop();if hasTap {engine.inputNode.removeTap(onBus:0);hasTap=false}
        request?.endAudio();recognition?.cancel();recognition=nil;request=nil;latestText="";status="Voice off"
    }
    private func stopSpeaking(){player?.stop();player=nil;activeUtterance=nil;if speaker.isSpeaking {speaker.stopSpeaking(at:.immediate)};speaking=false}
    nonisolated func speechSynthesizer(_ synthesizer:AVSpeechSynthesizer,didFinish utterance:AVSpeechUtterance){Task{@MainActor in guard self.activeUtterance === utterance else{return};self.activeUtterance=nil;self.pendingManual=false;self.speaking=false;self.quietSince=Date();self.recognitionAfter=Date().addingTimeInterval(0.7);if self.listening {self.scheduleRestart(ticket:self.generation)}}}
    nonisolated func speechSynthesizer(_ synthesizer:AVSpeechSynthesizer,didCancel utterance:AVSpeechUtterance){Task{@MainActor in guard self.activeUtterance === utterance else{return};self.activeUtterance=nil;self.pendingManual=false;self.speaking=false;self.quietSince=Date();self.recognitionAfter=Date().addingTimeInterval(0.7)}}
    enum VoiceError:Error {case noInput}
}
