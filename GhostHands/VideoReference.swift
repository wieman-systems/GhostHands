import SwiftUI
import WebKit

struct VideoIntro:View {
    @Environment(StudioModel.self) private var model
    var body:some View {Button("OPEN YOUTUBE") {model.showVideo()}}
}
struct VideoReference:View {
    var embedded=false
    @State private var playerID=UUID()
    @State private var editingLink=false
    @State private var link=""
    @Environment(StudioModel.self) private var model
    @Environment(\.dismissWindow) private var dismiss
    var body:some View {
        VStack(spacing:12) {
            VStack(spacing:4) {
                Text("YOUTUBE / \(model.course.title)").font(.headline).lineLimit(1)
                Text(model.referenceTitle).font(.caption).lineLimit(1).foregroundStyle(.secondary)
            }.frame(maxWidth:.infinity).frame(height:42)
            VStack(spacing:8) {
                if editingLink {
                    TextField("Paste or dictate a YouTube video link",text:$link)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .textFieldStyle(.plain).padding(12).overlay(Rectangle().stroke(.white.opacity(0.4)))
                }
                if model.hasReferenceVideo && (model.videoOwner == nil || model.videoOwner == playerID) && (embedded == model.dockedVideo) {
                    YouTubePlayer(model:model,command:model.video.command,owner:playerID).id(model.video.playerGeneration)
                } else {
                    VStack(spacing:18) {
                        Image(systemName:"play.rectangle").font(.system(size:42))
                        Text("Watch YouTube alongside this model.").font(.title3)
                        Text("Open More → Choose Video to select a reference or enter a YouTube link.")
                            .font(.callout).multilineTextAlignment(.center)
                    }.frame(maxWidth:.infinity,maxHeight:.infinity)
                }
            }.frame(height:430)
            HStack(spacing:12) {
                Spacer(minLength:0)
                if editingLink {
                    Button("LOAD") {if model.setReferenceVideo(link) {editingLink=false}}.frame(width:150).disabled(model.busyRecording || model.isAuthoring)
                    Button("CANCEL") {editingLink=false}.frame(width:150)
                } else {
                    Button(model.video.playing ? "PAUSE" : "PLAY",systemImage:model.video.playing ? "pause.fill" : "play.fill") {model.toggleReferencePlayback()}
                        .frame(width:150).disabled(!model.hasReferenceVideo || model.busyRecording || model.isAuthoring)
                    Button("REPLAY",systemImage:"arrow.counterclockwise") {if model.linkedVideo {model.replayCurrent()} else {model.replayReference()}}
                        .frame(width:150).disabled(!model.hasReferenceVideo || model.busyRecording || model.isAuthoring)
                    videoMenu.frame(width:150)
                    Button("CLOSE",systemImage:"xmark") {model.videoClosed(owner:playerID);if embedded {model.dockedVideo=false} else {dismiss(id:"video")}}.frame(width:150)
                }
                Spacer(minLength:0)
            }.frame(height:44)
            Text(model.video.failed ? model.video.status+" · More → Retry" : model.video.status)
                .font(.caption).lineLimit(2).multilineTextAlignment(.center).frame(maxWidth:.infinity).frame(height:32)
            Text(model.isAuthoring ? "Author mode · mark Start and End in the editor" : model.linkedVideo ? "Step Sync on · video follows the current step" : "Independent playback · video and model have separate controls")
                .font(.caption).foregroundStyle(.secondary).lineLimit(1).frame(height:18)
        }.padding(16).frame(width:800,height:650).background(.black).foregroundStyle(.white).buttonStyle(SquareButton()).environment(\.compactControls,true).preferredColorScheme(.dark)
            .onAppear{link=model.referenceURL;if embedded == model.dockedVideo {model.videoOpened(owner:playerID)}}.onDisappear{model.videoClosed(owner:playerID)}
            .onChange(of:model.course.id) {_,_ in link=model.referenceURL;editingLink=false}
            .onChange(of:model.dockedVideo) {_,docked in if !embedded && docked {dismiss(id:"video")}}
            #if targetEnvironment(simulator)
            .task {if ProcessInfo.processInfo.arguments.contains("--sync-preview") {await verifyLivePlayer()};if ProcessInfo.processInfo.arguments.contains("--independent-video-preview") {await verifyIndependentPlayer()}}
            #endif
    }
    private var videoMenu:some View {
        Menu {
            Menu("Choose Video",systemImage:"play.rectangle") {
                if model.course.hasVideo || model.course.mechanicalModel == .jet {Button("Lesson reference") {model.useLessonReference()}}
                Button("Jet engine · Safran") {_ = model.setReferenceVideo(StudioModel.turbineVideo)}
                Button("Car engine · Briggs & Stratton") {_ = model.setReferenceVideo(LessonCatalog.engine.videoURL)}
                Button("Enter a YouTube link…") {model.pauseVideo();link=model.referenceURL;editingLink=true}
                Link("Find videos on YouTube",destination:model.youtubeSearchURL)
            }.disabled(model.busyRecording || model.isAuthoring)
            if model.canSyncVideo {
                Button(model.syncVideo ? "Turn Step Sync off" : "Turn Step Sync on") {model.setVideoSync(!model.syncVideo)}.disabled(model.busyRecording)
            }
            if model.linkedVideo {
                Button("Previous step") {model.setStep(model.step-1)}.disabled(model.step==0 || model.busyRecording || model.isAuthoring)
                Button("Next step") {model.setStep(model.step+1)}.disabled(model.step>=model.stepCount-1 || model.busyRecording || model.isAuthoring)
            } else {
                Button(model.mode == .playing ? "Pause model" : "Play model") {model.playPause()}.disabled(!model.placed || model.busyRecording || model.isAuthoring)
                Button(model.loops ? "Turn model looping off" : "Loop model") {model.toggleLoop()}.disabled(model.busyRecording || model.isAuthoring)
            }
            if embedded {
                Menu("Video Size",systemImage:"arrow.up.left.and.arrow.down.right") {
                    ForEach([Float(0.55),0.7,0.85],id:\.self) {scale in Button(scale==0.55 ? "Standard" : scale==0.7 ? "Large" : "Largest") {model.videoScale=scale}}
                }
            }
            if model.video.failed {Button("Retry video") {model.retryVideo()}.disabled(model.busyRecording)}
            if let url=YouTubeLink(model.referenceURL)?.watchURL {Link("Open in YouTube",destination:url)}
        } label:{Label("MORE",systemImage:"chevron.down")}
    }

}

#if targetEnvironment(simulator)
extension VideoReference {
    @MainActor func verifyIndependentPlayer() async {
        var checks:[[String:Any]]=[]
        for _ in 0..<120 {if model.video.playing {break};try? await Task.sleep(for:.milliseconds(500));if Task.isCancelled{return}}
        checks.append(["check":"turbine reference playing","passed":model.video.playing && !model.linkedVideo,"videoTime":model.video.currentTime])
        let initial=model.elapsed,videoTime=model.video.currentTime
        try? await Task.sleep(for:.seconds(1))
        checks.append(["check":"model and video advance together","passed":model.elapsed != initial && model.video.currentTime>videoTime])
        model.pauseVideo();let angle=model.elapsed
        try? await Task.sleep(for:.seconds(1))
        checks.append(["check":"video pause preserves model motion","passed":!model.video.playing && model.elapsed != angle])
        model.toggleReferencePlayback();model.mode = .paused;let frozen=model.elapsed
        try? await Task.sleep(for:.seconds(2))
        checks.append(["check":"model pause preserves video motion","passed":model.video.playing && model.elapsed==frozen])
        if let data=try? JSONSerialization.data(withJSONObject:checks,options:.prettyPrinted) {try? data.write(to:URL.documentsDirectory.appendingPathComponent("independent-video.json"))}
    }
    // Simulator integration probe observes the real embedded player's callbacks.
    @MainActor func verifyLivePlayer() async {
        var events:[[String:Any]]=[]
        func waitFor(_ label:String,_ predicate:()->Bool) async->Bool {
            for _ in 0..<120 {
                if predicate(){events.append(["check":label,"passed":true,"time":model.video.currentTime,"serial":model.video.acknowledgedSerial]);return true}
                try? await Task.sleep(for:.milliseconds(500))
                if Task.isCancelled {return false}
            }
            events.append(["check":label,"passed":false,"status":model.video.status,"time":model.video.currentTime]);return false
        }
        if await waitFor("initial playback",{model.video.playing && model.video.currentTime>=20}) {
            model.setStep(9)
            let serial=model.video.command!.serial
            if await waitFor("next seeks to diamond",{model.video.acknowledgedSerial==serial && (123...125).contains(model.video.currentTime)}) {
                _ = await waitFor("pauses at step end",{!model.video.playing && model.video.currentTime>=133.8 && model.step==9})
                model.replayCurrent();let replay=model.video.command!.serial
                _ = await waitFor("replay seeks back",{model.video.acknowledgedSerial==replay && (123...125).contains(model.video.currentTime)})
            }
        }
        model.pauseVideo()
        if let data=try? JSONSerialization.data(withJSONObject:events,options:.prettyPrinted) {try? data.write(to:URL.documentsDirectory.appendingPathComponent("video-integration.json"))}
    }
}
#endif
struct YouTubePlayer:UIViewRepresentable {
    let model:StudioModel
    let command:VideoCommand?
    let owner:UUID
    func makeCoordinator()->Coordinator {Coordinator(model:model,owner:owner)}
    func makeUIView(context:Context)->WKWebView {
        let configuration=WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback=true
        configuration.mediaTypesRequiringUserActionForPlayback=[]
        configuration.userContentController.add(context.coordinator,name:"ghostVideo")
        let view=WKWebView(frame:.zero,configuration:configuration)
        view.isOpaque=false;view.backgroundColor = .black
        view.navigationDelegate=context.coordinator
        context.coordinator.webView=view
        view.loadHTMLString(PlayerHTML.document,baseURL:URL(string:"https://com.calebwieman.ghosthands"))
        return view
    }
    func updateUIView(_ view:WKWebView,context:Context) {context.coordinator.apply(command)}
    static func dismantleUIView(_ view:WKWebView,coordinator:Coordinator) {
        coordinator.retired=true
        view.configuration.userContentController.removeScriptMessageHandler(forName:"ghostVideo")
        view.stopLoading();view.navigationDelegate=nil;coordinator.webView=nil
        view.loadHTMLString("",baseURL:nil)
    }
    @MainActor final class Coordinator:NSObject,WKNavigationDelegate,WKScriptMessageHandler {
        let model:StudioModel
        let owner:UUID
        let generation:Int
        var retired=false
        var isCurrent:Bool {!retired && model.videoOwner==owner && model.video.playerGeneration==generation}
        weak var webView:WKWebView?
        private var pageReady=false
        private var lastSerial = -1
        init(model:StudioModel,owner:UUID){self.model=model;self.owner=owner;self.generation=model.video.playerGeneration}
        func apply(_ requested:VideoCommand? = nil) {
            guard isCurrent,pageReady,let command=requested ?? model.video.command,command.serial != lastSerial,let data=try? JSONEncoder().encode(command),let json=String(data:data,encoding:.utf8) else{return}
            lastSerial=command.serial
            webView?.evaluateJavaScript("window.ghostCommand(\(json));") { [weak self] _,error in
                guard let self,self.isCurrent,self.model.video.command?.serial==command.serial else{return}
                if error != nil {self.model.failVideo("Player unavailable. Reopen the video or use YouTube.")}
            }
        }
        func webView(_ webView:WKWebView,didFinish navigation:WKNavigation!){guard isCurrent else{return};pageReady=true;apply()}
        func userContentController(_ userContentController:WKUserContentController,didReceive message:WKScriptMessage) {
            guard isCurrent else{return}
            guard let data=message.body as? [String:Any],let type=data["type"] as? String else{return}
            if type=="bootstrapError" {model.failVideo("Video could not load. Retry or close it to use the guide offline.");return}
            if type=="ready" {model.video.ready=true;return}
            if type=="blocked" || type=="error" {
                guard let serial=data["serial"] as? Int,serial==model.video.command?.serial,let id=data["videoID"] as? String,id==model.video.command?.videoID else{return}
            }
            if type=="blocked" {model.video.waiting=false;model.video.status="Tap Play in the video to begin.";return}
            if type=="error" {model.failVideo("YouTube could not play this video (\(data["code"] ?? "unknown")). Retry or open YouTube.");return}
            guard let serial=data["serial"] as? Int,let id=data["videoID"] as? String,let time=data["time"] as? Double,let duration=data["duration"] as? Double,let state=data["state"] as? Int else{return}
            model.acceptVideo(serial:serial,id:id,time:time,duration:duration,state:state,rate:data["rate"] as? Double ?? 1,ended:data["ended"] as? Bool ?? false)
        }
        func webView(_ webView:WKWebView,didFailProvisionalNavigation navigation:WKNavigation!,withError error:Error) {guard isCurrent,(error as NSError).code != NSURLErrorCancelled else{return};model.failVideo("Video unavailable. Check your connection or open YouTube.")}
    }
}
