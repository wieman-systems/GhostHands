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
        VStack(alignment:.leading,spacing:8) {
            HStack {
                VStack(alignment:.leading) {Text("YOUTUBE / \(model.course.title)").font(.headline).lineLimit(1);Text(model.referenceTitle).font(.caption).lineLimit(1).foregroundStyle(.secondary)}
                Spacer();Button("CLOSE") {model.videoClosed(owner:playerID);if embedded {model.dockedVideo=false} else {dismiss(id:"video")}}.frame(width:100)
            }.frame(height:40)
            HStack {
                Menu {
                    if model.course.hasVideo || model.course.mechanicalModel == .jet {Button("Lesson reference") {model.useLessonReference();editingLink=false}}
                    Button("Jet engine · Safran") {_ = model.setReferenceVideo(StudioModel.turbineVideo);editingLink=false}
                    Button("Car engine · Briggs & Stratton") {_ = model.setReferenceVideo(LessonCatalog.engine.videoURL);editingLink=false}
                    Button("Enter a YouTube link…") {link=model.referenceURL;editingLink=true}
                } label:{Label("CHOOSE VIDEO",systemImage:"chevron.down")}.disabled(model.busyRecording || model.isAuthoring)
                if model.canSyncVideo {Button(model.syncVideo ? "STEP SYNC / ON" : "INDEPENDENT") {model.setVideoSync(!model.syncVideo)}.disabled(model.busyRecording)}
                else {Text("INDEPENDENT PLAYBACK").font(.caption.monospaced()).frame(maxWidth:.infinity)}
                if embedded {Menu {ForEach([Float(0.55),0.7,0.85],id:\.self) {scale in Button(scale==0.55 ? "Standard" : scale==0.7 ? "Large" : "Largest") {model.videoScale=scale}}} label:{Label("SIZE",systemImage:"arrow.up.left.and.arrow.down.right")}.frame(width:125)}
            }.frame(height:38)
            VStack(spacing:6) {
                if editingLink {
                    HStack {
                        TextField("Paste or dictate a YouTube video link",text:$link).textInputAutocapitalization(.never).autocorrectionDisabled().textFieldStyle(.plain).padding(8).overlay(Rectangle().stroke(.white.opacity(0.4)))
                        Button("LOAD") {if model.setReferenceVideo(link) {editingLink=false}}.frame(width:90)
                        Button("CANCEL") {editingLink=false}.frame(width:90)
                    }.frame(height:38)
                }
                if model.hasReferenceVideo && (model.videoOwner == nil || model.videoOwner == playerID) && (embedded == model.dockedVideo) {
                    YouTubePlayer(model:model,command:model.video.command,owner:playerID).id(model.video.playerGeneration)
                } else {
                    VStack(spacing:18) {
                        Image(systemName:"play.rectangle").font(.system(size:42))
                        Text("Watch YouTube alongside this model.").font(.title3)
                        Text("Choose a reference or load any YouTube video link. The model has its own playback controls.").font(.callout).multilineTextAlignment(.center)
                        Button("ENTER VIDEO LINK") {editingLink=true}.frame(width:250).disabled(model.busyRecording || model.isAuthoring)
                        Link("Find videos on YouTube",destination:model.youtubeSearchURL)
                    }.frame(maxWidth:.infinity,maxHeight:.infinity)
                }
            }.frame(height:340)
            HStack(spacing:8) {
                if model.linkedVideo {
                    Button("BACK") {model.setStep(model.step-1)}.disabled(model.step==0)
                    Button("SHOW THAT AGAIN") {model.replayCurrent()}
                    Button("NEXT") {model.setStep(model.step+1)}.disabled(model.step>=model.stepCount-1)
                } else {
                    Button(model.video.playing ? "PAUSE VIDEO" : "PLAY VIDEO") {model.toggleReferencePlayback()}.disabled(!model.hasReferenceVideo)
                    Button("RESTART VIDEO") {model.replayReference()}.disabled(!model.hasReferenceVideo)
                    Button(model.mode == .playing ? "PAUSE MODEL" : "PLAY MODEL") {model.playPause()}.disabled(!model.placed || model.isAuthoring)
                }
            }.frame(height:38).disabled(model.busyRecording || model.isAuthoring)
            HStack {
                if model.video.failed {Button("RETRY") {model.retryVideo()}.frame(width:90)}
                Text(model.video.status).font(.caption).lineLimit(2)
                Spacer()
                if let url=YouTubeLink(model.referenceURL)?.watchURL {Link("Open in YouTube",destination:url).font(.caption)}
            }.frame(height:28)
            Text(model.isAuthoring ? "Author mode: scrub freely, then mark Start and End in the editor." : model.linkedVideo ? "Video follows the current step. Switch Step Sync off for independent viewing." : "Video and model run separately. Use the playback panel’s Loop option to keep the model moving.").font(.caption).foregroundStyle(.secondary).lineLimit(2).frame(height:28)
        }.padding(16).frame(width:800,height:650).background(.black).foregroundStyle(.white).buttonStyle(SquareButton()).environment(\.compactControls,true).preferredColorScheme(.dark)
            .onAppear{link=model.referenceURL;if embedded == model.dockedVideo {model.videoOpened(owner:playerID)}}.onDisappear{model.videoClosed(owner:playerID)}
            .onChange(of:model.course.id) {_,_ in link=model.referenceURL;editingLink=false}
            .onChange(of:model.dockedVideo) {_,docked in if !embedded && docked {dismiss(id:"video")}}
            #if targetEnvironment(simulator)
            .task {if ProcessInfo.processInfo.arguments.contains("--sync-preview") {await verifyLivePlayer()};if ProcessInfo.processInfo.arguments.contains("--independent-video-preview") {await verifyIndependentPlayer()}}
            #endif
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
