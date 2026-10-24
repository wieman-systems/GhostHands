import SwiftUI
import WebKit

struct VideoIntro:View {
    @Environment(\.openWindow) private var open
    var body:some View {Button("OPEN STEP VIDEO") {open(id:"video")}}
}
struct VideoReference:View {
    var embedded=false
    @State private var playerID=UUID()
    @Environment(StudioModel.self) private var model
    @Environment(\.dismissWindow) private var dismiss
    var body:some View {
        VStack(alignment:.leading,spacing:16) {
            HStack {
                VStack(alignment:.leading) {Text(model.course.title).font(.title2.bold());Text(model.course.attribution).font(.caption).foregroundStyle(.secondary)}
                Spacer();Button("CLOSE VIDEO") {model.videoClosed(owner:playerID);if embedded {model.dockedVideo=false} else {dismiss(id:"video")}}.frame(width:180)
            }
            HStack {Text("STEP \(model.step+1) / \(model.stepCount)").font(.caption.monospaced());Text(model.currentStep.title).font(.headline)}
            if model.course.hasVideo && (model.videoOwner == nil || model.videoOwner == playerID) && (embedded == model.dockedVideo) {YouTubePlayer(model:model,command:model.video.command,owner:playerID).id(model.video.playerGeneration).frame(height:360)} else {Text("This lesson uses its 3D model.").frame(height:360)}
            HStack(spacing:12) {
                Button("BACK") {model.setStep(model.step-1)}.disabled(model.step==0 || model.busyRecording || model.isAuthoring)
                Button("SHOW THAT AGAIN") {model.replayCurrent()}.disabled(model.busyRecording || model.isAuthoring)
                Button("NEXT") {model.setStep(model.step+1)}.disabled(model.step>=model.stepCount-1 || model.busyRecording || model.isAuthoring)
            }
            HStack {
                if model.video.failed {Button("RETRY VIDEO") {model.retryVideo()}.frame(width:150)}
                Text(model.video.status).font(.caption).lineLimit(2)
                Spacer()
                if let segment=model.currentStep.segment {Text("\(segment.start.formatted(.number.precision(.fractionLength(1))))–\(segment.end.formatted(.number.precision(.fractionLength(1))))s").font(.caption.monospacedDigit())}
                if let url=URL(string:model.course.videoURL),model.course.hasVideo {Link("YouTube",destination:url).buttonStyle(.plain).frame(width:75)}
            }
            Text(model.isAuthoring ? "Author mode: scrub freely, then mark Start and End in the editor." : (model.currentStep.segment == nil ? "Reference video: play manually. This lesson uses its own 3D timeline." : "The video pauses after this action. Tap Play if YouTube asks. Voice during playback: “GhostHands, next.”")).font(.caption).foregroundStyle(.secondary)
        }.padding(24).frame(width:800,height:650).background(.black).foregroundStyle(.white).buttonStyle(SquareButton()).preferredColorScheme(.dark)
            .onAppear{if model.course.hasVideo && (embedded == model.dockedVideo) {model.videoOpened(owner:playerID)}}.onDisappear{model.videoClosed(owner:playerID)}
            .onChange(of:model.dockedVideo) {_,docked in if !embedded && docked {dismiss(id:"video")}}
            #if targetEnvironment(simulator)
            .task {if ProcessInfo.processInfo.arguments.contains("--sync-preview") {await verifyLivePlayer()}}
            #endif
    }
}
#if targetEnvironment(simulator)
extension VideoReference {
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
        view.configuration.userContentController.removeScriptMessageHandler(forName:"ghostVideo")
        view.stopLoading();view.navigationDelegate=nil;coordinator.webView=nil
        view.loadHTMLString("",baseURL:nil)
    }
    @MainActor final class Coordinator:NSObject,WKNavigationDelegate,WKScriptMessageHandler {
        let model:StudioModel
        let owner:UUID
        let generation:Int
        var isCurrent:Bool {model.videoOwner==owner && model.video.playerGeneration==generation}
        weak var webView:WKWebView?
        private var pageReady=false
        private var lastSerial = -1
        init(model:StudioModel,owner:UUID){self.model=model;self.owner=owner;self.generation=model.video.playerGeneration}
        func apply(_ requested:VideoCommand? = nil) {
            guard isCurrent,pageReady,let command=requested ?? model.video.command,command.serial != lastSerial,let data=try? JSONEncoder().encode(command),let json=String(data:data,encoding:.utf8) else{return}
            lastSerial=command.serial
            webView?.evaluateJavaScript("window.ghostCommand(\(json));") { [weak self] _,error in
                guard let self,self.isCurrent else{return}
                if error != nil {self.model.video.fail("Player unavailable. Reopen the video or use YouTube.")}
            }
        }
        func webView(_ webView:WKWebView,didFinish navigation:WKNavigation!){guard isCurrent else{return};pageReady=true;apply()}
        func userContentController(_ userContentController:WKUserContentController,didReceive message:WKScriptMessage) {
            guard isCurrent else{return}
            guard let data=message.body as? [String:Any],let type=data["type"] as? String else{return}
            if type=="bootstrapError" {model.video.fail("Video could not load. Retry or close it to use the guide offline.");model.mode = .paused;return}
            if type=="ready" {model.video.ready=true;return}
            if type=="blocked" || type=="error" {
                guard let serial=data["serial"] as? Int,serial==model.video.command?.serial,let id=data["videoID"] as? String,id==model.video.command?.videoID else{return}
            }
            if type=="blocked" {model.video.waiting=false;model.video.status="Tap Play in the video to begin.";return}
            if type=="error" {model.video.fail("YouTube could not play this video (\(data["code"] ?? "unknown")). Retry or open YouTube.");model.mode = .paused;return}
            guard let serial=data["serial"] as? Int,let id=data["videoID"] as? String,let time=data["time"] as? Double,let duration=data["duration"] as? Double,let state=data["state"] as? Int else{return}
            model.acceptVideo(serial:serial,id:id,time:time,duration:duration,state:state,rate:data["rate"] as? Double ?? 1,ended:data["ended"] as? Bool ?? false)
        }
        func webView(_ webView:WKWebView,didFailProvisionalNavigation navigation:WKNavigation!,withError error:Error) {guard isCurrent,(error as NSError).code != NSURLErrorCancelled else{return};model.video.fail("Video unavailable. Check your connection or open YouTube.")}
    }
}
