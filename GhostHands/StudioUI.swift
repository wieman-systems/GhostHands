import SwiftUI

extension Color {
    static let ghostMint = Color.white
    static let ghostLavender = Color.white.opacity(0.7)
}
struct CompactControlsKey:EnvironmentKey {static let defaultValue=false}
extension EnvironmentValues {var compactControls:Bool {get{self[CompactControlsKey.self]}set{self[CompactControlsKey.self]=newValue}}}
struct SquareButton: ButtonStyle {
    @Environment(\.compactControls) private var compact
    var selected=false
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.frame(maxWidth:.infinity,alignment:.center).multilineTextAlignment(.center).font(.system(size:compact ? 12 : 15,weight:.medium)).lineLimit(2).minimumScaleFactor(0.85)
            .padding(.horizontal,compact ? 8 : 14).padding(.vertical,compact ? 6 : 11).frame(height:compact ? 38 : 52)
            .foregroundStyle(selected ? .black : .white)
            .background(selected ? Color.white : Color.white.opacity(configuration.isPressed ? 0.24 : 0.06))
            .overlay(Rectangle().stroke(.white.opacity(selected ? 1 : 0.25),lineWidth:1))
            .contentShape(Rectangle()).opacity(enabled ? 1 : 0.35).hoverEffect(.highlight)
    }
}
struct DeskCard<Content: View>: View {
    @Environment(\.compactControls) private var compact
    let title: String
    var height:CGFloat?=nil
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment:.leading,spacing:compact ? 10 : 18) {
            HStack { Text(title).font(.system(size:12,weight:.semibold,design:.monospaced)).tracking(2); Spacer(); Image(systemName:"plus").font(.caption) }
            Rectangle().fill(.white.opacity(0.25)).frame(height:1)
            content
        }.padding(compact ? 16 : 24).frame(maxWidth:.infinity,alignment:.topLeading).frame(height:height,alignment:.top).foregroundStyle(.white).background(.black.opacity(0.96))
            .overlay(Rectangle().stroke(.white.opacity(0.45),lineWidth:1))
            .buttonStyle(SquareButton()).tint(.white).preferredColorScheme(.dark)
    }
}

struct HomeView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(StudioModel.self) private var model
    @Environment(\.openImmersiveSpace) private var open
    @Environment(\.dismissImmersiveSpace) private var dismissSpace
    @Environment(\.dismissWindow) private var dismiss
    var body: some View {
        VStack(spacing:22) {
            Text("GHOSTHANDS / GUIDED WORKSPACE").font(.system(size:14,weight:.bold,design:.monospaced)).tracking(4)
            Text(model.immersive ? "Make room to make something." : model.course.title).font(.system(size:38,weight:.medium))
            if !model.immersive {
                Picker("Lesson",selection:Binding(get:{model.activeLessonID},set:{model.chooseLesson($0)})) {ForEach(model.lessons){Text($0.title+" · "+$0.category).tag($0.id)}}.pickerStyle(.menu).frame(width:600)
            }
            HStack(alignment:.top,spacing:24) {
                setupCard("01", "Clear your table", "Find a large, clear, open spot. Leave about an arm’s width for the paper and controls.",icon:"rectangle.dashed")
                setupCard("02", "Touch the center", "Lift your right index, then rest its fingertip on the table in the center of that space.",icon:"hand.point.up.left")
                setupCard("03", "Hold still", "Keep it there for two seconds. The paper and menus will appear around that point.",icon:"timer")
            }
            if model.immersive,let issue=model.trackingIssue {
                Text(issue).font(.headline).multilineTextAlignment(.center).frame(width:650)
                Button("PLACE AGAIN") {model.beginPlacement();model.startFingerPlacement()}.buttonStyle(SquareButton(selected:true)).frame(width:360)
                Button("LEAVE WORKSPACE") {Task {await dismissSpace()}}.buttonStyle(SquareButton()).frame(width:360)
            } else if model.immersive && !model.placed {
                if model.fingerPlacement {
                    Text(model.placementHint).font(.headline).multilineTextAlignment(.center)
                    ProgressView(value:Double(model.placementProgress)).tint(.white).frame(width:400)
                    Text(model.capture.status).font(.caption).foregroundStyle(.secondary)
                } else {
                    Button("I HAVE A CLEAR SPOT") {model.startFingerPlacement()}.buttonStyle(SquareButton(selected:true)).frame(width:360)
                }
                Button("CANCEL SETUP") {Task {await dismissSpace()}}.buttonStyle(SquareButton()).frame(width:240)
            } else {
                Button(model.transitioning ? "OPENING…" : "ENTER WORKSPACE") {enter()}.buttonStyle(SquareButton(selected:true)).frame(width:360).disabled(model.transitioning || model.immersive)
                Text(model.course.object).font(.caption.monospaced()).foregroundStyle(.secondary)
                Text("Optional AI-generated narration · Audio settings control read-aloud.").font(.caption2).foregroundStyle(.secondary)
            }
        }.padding(36).frame(width:960,height:700).background(.black).foregroundStyle(.white)
            .overlay(Rectangle().stroke(.white.opacity(0.35),lineWidth:1)).preferredColorScheme(.dark)
            .alert("GhostHands",isPresented:Binding(get:{model.error != nil},set:{if !$0 {model.error=nil}})) { Button("OK") { model.error=nil } } message: { Text(model.error ?? "") }
            .task {
                #if targetEnvironment(simulator)
                if ProcessInfo.processInfo.arguments.contains("--panel-preview"),!model.previewConsumed {
                    model.previewConsumed=true;model.tab = ProcessInfo.processInfo.arguments.contains("--lessons-preview") ? .lessons : .settings
                    openWindow(id:"panel-preview");dismiss(id:"home");return
                }
                if ["--spatial-preview","--avatar-preview","--move-preview","--setup-preview","--sync-preview","--repair-preview","--author-preview","--engine-preview","--independent-video-preview","--tracking-preview","--brake-preview","--pump-preview","--jet-preview","--gear-preview","--settings-preview","--lessons-preview"].contains(where:{ProcessInfo.processInfo.arguments.contains($0)}),!model.previewConsumed {
                    model.previewConsumed=true;model.automaticVideo=ProcessInfo.processInfo.arguments.contains("--video-preview") || ProcessInfo.processInfo.arguments.contains("--sync-preview")
                    let result=await open(id:"studio")
                    if case .opened=result {
                        if ProcessInfo.processInfo.arguments.contains("--setup-preview") {return}
                        try? await Task.sleep(for:.milliseconds(700))
                        model.fingerPlacement=false; model.position=[0,1.25,-0.85]; model.placementReady=true; model.placed=true
                        model.setStep(9); model.seek(3.0)
                        if ProcessInfo.processInfo.arguments.contains("--sync-preview") {model.setStep(0)}
                        if ProcessInfo.processInfo.arguments.contains("--repair-preview") {model.chooseLesson(LessonCatalog.repair.id);model.setStep(3)}
                        if ProcessInfo.processInfo.arguments.contains("--engine-preview") {model.chooseLesson(LessonCatalog.engine.id);model.setStep(2);model.seek(3)}
                        if ProcessInfo.processInfo.arguments.contains("--jet-preview") {model.chooseLesson(LessonCatalog.jet.id);model.setStep(4);model.seek(2)}
                        if ProcessInfo.processInfo.arguments.contains("--gear-preview") {model.chooseLesson(LessonCatalog.gearbox.id);model.setStep(1);model.seek(2)}
                        if ProcessInfo.processInfo.arguments.contains("--independent-video-preview") {model.chooseLesson(LessonCatalog.jet.id);model.loops=true;model.showVideo()}
                        if ProcessInfo.processInfo.arguments.contains("--color-preview") {model.coloredModels=true}
                        if ProcessInfo.processInfo.arguments.contains("--video-only-preview") {model.showVideo();model.toggleVideoOnly();model.movingVideo=true;model.moveVideo(to:[0.12,0.42,-0.4]);model.movingVideo=false}
                        if ProcessInfo.processInfo.arguments.contains("--brake-preview") {model.chooseLesson(LessonCatalog.brake.id);model.loops=true}
                        if ProcessInfo.processInfo.arguments.contains("--pump-preview") {model.chooseLesson(LessonCatalog.pump.id);model.loops=true}
                        if ProcessInfo.processInfo.arguments.contains("--settings-preview") {model.tab = .settings}
                        if ProcessInfo.processInfo.arguments.contains("--lessons-preview") {model.tab = .lessons}
                        if ProcessInfo.processInfo.arguments.contains("--author-preview") {model.beginAuthoring(blank:false);openWindow(id:"author")}
                        if ProcessInfo.processInfo.arguments.contains("--avatar-preview") {
                            var fixture=IllustratedMotion.clip(step:2,side:LetterPaper.width)
                            fixture.isIllustration=false;fixture.title="Simulator hand fixture"
                            model.load(fixture);model.seek(3);model.avatarEnabled=true;model.avatarTableHeight=0.8;model.tab = .settings
                        }
                        if ProcessInfo.processInfo.arguments.contains("--move-preview") {model.beginAdjustment()}
                        dismiss(id:"home")
                        if ProcessInfo.processInfo.arguments.contains("--tracking-preview") {
                            model.lockWorkspace();var shifted=model.workspace;shifted.columns.3.z += 2
                            try? await Task.sleep(for:.milliseconds(600));model.receiveWorkspaceAnchor(shifted,tracked:true)
                        }
                        if ProcessInfo.processInfo.arguments.contains("--inspect-preview") {model.explodedView=true;model.mode = .paused}
                    }
                }
                #endif
            }
    }
    private func setupCard(_ number:String,_ title:String,_ text:String,icon:String)->some View {
        VStack(spacing:16) {
            Text(number).font(.caption.monospaced()).foregroundStyle(.secondary)
            Image(systemName:icon).font(.system(size:38))
            Text(title).font(.title3.bold())
            Text(text).font(.body).multilineTextAlignment(.center).fixedSize(horizontal:false,vertical:true)
        }.frame(maxWidth:.infinity).padding(18).frame(height:230).overlay(Rectangle().stroke(.white.opacity(0.3)))
    }
    private func enter() {
        guard !model.transitioning else {return}; model.transitioning=true
        Task {
            switch await open(id:"studio") {
            case .opened: break
            case .userCancelled: model.status="Opening cancelled."
            default: model.error="Could not open the workspace. Close another immersive app and try again."
            }
            model.transitioning=false
        }
    }
}

struct LessonPanel: View {
    @Environment(StudioModel.self) private var model
    var body: some View {
        DeskCard(title:"01 / LEARN",height:820) {
            HStack { Text(model.course.title).font(.title2.bold()).lineLimit(1); Spacer(); Text(String(format:"%02d / %02d",model.step+1,model.stepCount)).font(.title3.monospacedDigit()) }
            if model.isPaperLesson {
            HStack(alignment:.top) {
                VStack(alignment:.leading,spacing:6) {Text("START SHAPE").font(.caption2.monospaced());PaperFinishDiagram(step:model.lesson,progress:model.currentStep.staticPaper ? 1 : 0).frame(height:110)}
                VStack(alignment:.leading,spacing:6) {Text("FINISH SHAPE").font(.caption2.monospaced());PaperFinishDiagram(step:model.lesson).frame(height:110)}
            }.frame(height:130)
            } else {
                VStack(spacing:10) {Image(systemName:model.course.mechanicalModel == .jet ? "airplane" : "wrench.and.screwdriver").font(.system(size:38));Text(model.course.object).font(.caption);Text(model.course.mechanicalModel == .jet ? "TURBOFAN INSPECTION LAB" : model.course.mechanicalModel == .gearbox ? "GEAR DRIVE LAB" : model.course.mechanicalModel == .engine ? "ANIMATED ENGINE CUTAWAY" : [.brake,.pump].contains(model.course.mechanicalModel) ? "INTERACTIVE MECHANISM" : "MANUAL SPATIAL GUIDANCE").font(.caption2.monospaced())}.frame(maxWidth:.infinity).frame(height:130)
            }
            // Reserve a fixed reading area so the tabletop touch targets never move.
            ScrollView {
                VStack(alignment:.leading,spacing:14) {
                    Text(model.currentStep.segment.map{"VIDEO \(Int($0.start))–\(Int($0.end))s"} ?? "FOLLOW THIS ACTION").font(.caption.monospaced()).padding(8).overlay(Rectangle().stroke(.white.opacity(0.3)))
                    Text(model.currentStep.title).font(.title3.bold())
                    Text(model.currentStep.instruction).font(.system(size:17)).fixedSize(horizontal:false,vertical:true)
                    Text(model.currentStep.check).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
                }.frame(maxWidth:.infinity,alignment:.leading)
            }.frame(height:250).id(model.step)
            HStack(spacing:12) {
                Button {model.setStep(model.step-1)} label:{Image(systemName:"arrow.left")}
                    .frame(width:76).disabled(model.step==0 || model.busyRecording)
                Button(model.step==model.stepCount-1 ? "FINISHED" : "NEXT STEP") {model.setStep(model.step+1)}
                    .frame(maxWidth:.infinity).disabled(model.step==model.stepCount-1 || model.busyRecording)
            }.frame(height:52)
            HStack {
                Button("SHOW START") {model.seek(0)}
                Button("SHOW FINISH") {model.seek(model.progressDuration)}
            }.disabled(model.busyRecording)
            Text(model.currentStep.id=="inspect" ? (model.defectFound ? "FINDING MARKED · Compare the damaged part with its neighbors." : "Find the short blade or tooth and tap it. Inspect has a hint.") : "Watch this action, then try it. Say “next” to continue.").font(.system(size:11)).foregroundStyle(.secondary)
        }.frame(width:470,height:820)
    }
}

struct PlaybackControls: View {
    @Environment(StudioModel.self) private var model
    @Environment(\.dismissImmersiveSpace) private var dismiss
    @Environment(\.openWindow) private var open
    var body: some View {
        DeskCard(title:"GHOSTHANDS / PLAYBACK") {
            HStack {
                Text(model.sourceLabel).font(.caption).lineLimit(1)
                Spacer();Text("\(model.displayedElapsed,specifier:"%.1f") / \(model.progressDuration,specifier:"%.1f")s").font(.caption.monospacedDigit())
            }
            Slider(value:Binding(get:{min(model.displayedElapsed,model.progressDuration)},set:{model.seek($0)}),in:0...max(model.progressDuration,0.01))
                .disabled(model.busyRecording).accessibilityLabel("Playback position")
            HStack(spacing:10) {
                Button(model.mode == .playing ? "PAUSE" : "PLAY",systemImage:model.mode == .playing ? "pause.fill" : "play.fill") {model.playPause()}
                    .buttonStyle(SquareButton(selected:true)).disabled(!model.placed || model.busyRecording)
                Menu {
                    ForEach([0.25,0.5,0.75,1,1.5,2.0],id:\.self) {speed in
                        Button {model.changeSpeed(speed)} label:{Label("\(speed.formatted())×",systemImage:model.speed==speed ? "checkmark" : "speedometer")}
                    }
                } label:{Label("\(model.speed.formatted())×",systemImage:"chevron.down")}.disabled(model.busyRecording)
                Menu {
                    Button("Show that again",systemImage:"arrow.counterclockwise") {model.replayCurrent()}.disabled(model.busyRecording)
                    Button(model.loops ? "Turn looping off" : "Loop this action",systemImage:"repeat") {model.toggleLoop()}.disabled(model.busyRecording)
                    Button("Show start") {model.seek(0)}.disabled(model.busyRecording)
                    Button("Show finish") {model.seek(model.progressDuration)}.disabled(model.busyRecording)
                    Button("Open YouTube",systemImage:"play.rectangle") {model.showVideo()}
                    Divider()
                    Button("Home",systemImage:"house") {
                        guard !model.transitioning else{return};model.transitioning=true
                        Task {open(id:"home");await dismiss();model.transitioning=false}
                    }.disabled(model.transitioning)
                } label:{Label("MORE",systemImage:"chevron.down")}
            }
            HStack(spacing:10) {
                Menu {
                    Button("All parts") {model.engineFocus=nil;model.labFocus=nil}
                    if model.course.mechanicalModel == .engine {ForEach(EnginePart.allCases){part in Button(part.title){model.engineFocus=part}}}
                    ForEach(LabPart.available(for:model.course.mechanicalModel)){part in Button(part.title){model.labFocus=part}}
                } label:{Label("PARTS",systemImage:"chevron.down")}.disabled(model.course.mechanicalModel == nil || model.course.mechanicalModel == .cabinFilter)
                Menu {
                    if [.jet,.gearbox,.brake,.pump].contains(model.course.mechanicalModel) {Button(model.explodedView ? "Assemble" : "Exploded view"){model.explodedView.toggle()}}
                    if [.brake,.pump].contains(model.course.mechanicalModel) {Button(model.mechanismAction) {model.operateMechanism()}.disabled(model.explodedView)}
                    Button("Rotate left"){model.modelRotation -= .pi/8}
                    Button("Rotate right"){model.modelRotation += .pi/8}
                    Button(model.modelScale>1 ? "Normal size" : "Enlarge"){model.modelScale=model.modelScale>1 ? 1 : 1.15}
                    if [.engine,.jet,.pump].contains(model.course.mechanicalModel) {Button(model.showFlow ? "Hide flow" : "Show flow"){model.showFlow.toggle()}}
                    if [.jet,.gearbox,.pump].contains(model.course.mechanicalModel) {Button(model.showCasing ? "Hide casing" : "Show casing"){model.showCasing.toggle()}}
                    if model.currentStep.id=="inspect" {Button(model.revealDefect ? "Hide hint" : "Reveal defect"){model.revealDefect.toggle()}}
                    Button("Reset view"){model.modelRotation=0;model.modelScale=1;model.explodedView=false;model.engineFocus=nil;model.labFocus=nil;model.revealDefect=false}
                } label:{Label("INSPECT",systemImage:"chevron.down")}.disabled(model.course.mechanicalModel == nil || model.busyRecording)
                Text(model.labFocus?.detail ?? model.engineFocus?.detail ?? "Tap a model part to inspect it.").font(.caption2).lineLimit(3).frame(width:200,height:44,alignment:.leading)
            }.frame(height:46)

        }.frame(width:570,height:310).environment(\.compactControls,true)
    }
}

struct SpatialControls: View {
    @Environment(StudioModel.self) private var model
    var body: some View {
        DeskCard(title:"02 / WORKSPACE",height:590) {
            HStack(spacing:4) {
                ForEach([StudioTab.lessons,.record,.library,.placement,.settings],id:\.self) {tab in
                    Button(tab == .placement ? "Place" : tab.rawValue) {model.tab=tab}.buttonStyle(SquareButton(selected:model.tab==tab || (tab == .record && model.tab == .learn))).frame(maxWidth:.infinity)
                }
            }.frame(width:422,height:38).disabled(model.busyRecording)
            Group {
                switch model.tab {
                case .lessons:LessonLibraryPanel()
                case .learn,.record:RecordPanel()
                case .library:LibraryPanel()
                case .placement:PlacementPanel()
                case .video:VideoIntro()
                case .settings:SettingsPanel()
                }
            }.frame(width:422,height:390,alignment:.topLeading)
            Text(model.status).font(.system(size:11)).foregroundStyle(.secondary).lineLimit(3).frame(width:422,height:40,alignment:.leading)
        }.frame(width:470,height:590).environment(\.compactControls,true)
            .alert("GhostHands",isPresented:Binding(get:{model.error != nil},set:{if !$0 {model.error=nil}})) {Button("OK"){model.error=nil}} message:{Text(model.error ?? "")}
    }
}

struct RecordPanel: View {
    @Environment(StudioModel.self) private var model
    var body: some View {
        @Bindable var model=model
        VStack(alignment:.leading,spacing:15) {
            Text("Teach this step.").font(.title2.bold())
            Text(model.currentStep.title).foregroundStyle(.secondary).lineLimit(2)
            TextField("Name your take",text:$model.recordingName).textFieldStyle(.plain).padding(12).overlay(Rectangle().stroke(.white.opacity(0.4))).disabled(model.busyRecording)
            HStack {
                ForEach([15.0,30,60],id:\.self) {seconds in Button("\(Int(seconds))s") {model.secondsToRecord=seconds}.buttonStyle(SquareButton(selected:model.secondsToRecord==seconds)).disabled(model.busyRecording)}
            }
            if model.busyRecording {
                Text(model.mode == .countdown ? "STARTING IN \(model.countdown)" : "REC / \(model.displayedElapsed,specifier:"%.1f")s").font(.title2.monospacedDigit())
                Button(model.mode == .countdown ? "CANCEL" : "STOP + SAVE") {if model.mode == .countdown {model.cancelCountdown()} else {model.finishRecording()}}
            } else {
                Button("RECORD HANDS",systemImage:"record.circle") {model.beginRecording()}.buttonStyle(SquareButton(selected:true)).disabled(!model.placed || !model.capture.ready || model.saving || model.hasUnsaved)
            }
            if model.hasUnsaved {Button("RETRY SAVE") {model.savePending()}.disabled(model.saving)}
            Text(model.savedMessage.isEmpty ? model.capture.status : model.savedMessage).font(.caption).foregroundStyle(.secondary)
        }
    }
}
struct LibraryPanel: View {
    @Environment(StudioModel.self) private var model
    @State private var page=0
    private var pages:Int {max(1,(model.clips.count+3)/4)}
    var body:some View {
        VStack(alignment:.leading,spacing:10) {
            Text("Recorded demonstrations").font(.headline)
            Button("LESSON DEMO") {model.setStep(model.step)}
            if model.clips.isEmpty {Text("Record an action to add it here.").font(.caption)}
            ForEach(Array(model.clips.dropFirst(min(page,pages-1)*4).prefix(4))) {clip in
                Button {model.load(clip)} label:{HStack {Text(clip.title).lineLimit(1);Spacer();Text("\(Int(clip.duration))s").monospacedDigit()}}
            }
            Spacer(minLength:0)
            HStack {Button("BACK") {page=max(0,page-1)}.disabled(page==0);Text("\(min(page,pages-1)+1) / \(pages)").font(.caption).frame(width:65);Button("MORE") {page=min(pages-1,page+1)}.disabled(page>=pages-1)}
        }.frame(width:422,height:390,alignment:.topLeading)
    }
}

struct PlacementPanel: View {
    @Environment(StudioModel.self) private var model
    var body:some View {
        VStack(alignment:.leading,spacing:10) {
            Text("Align the workspace").font(.headline)
            Text("Reposition reveals arrows. Move 1 cm or adjust height by 2 mm per tap.").font(.caption).lineLimit(2)
            HStack {Button(model.adjustingPlacement ? "DONE" : "REPOSITION") {if model.adjustingPlacement {model.finishAdjustment()} else {model.beginAdjustment()}};Button("NEW SPOT") {model.beginPlacement()}}
            if model.dockedVideo {
                Text("VIDEO POSITION").font(.caption.monospaced())
                HStack {Button("LOWER") {model.videoHeight=max(0.24,model.videoHeight-0.025)};Button("HIGHER") {model.videoHeight=min(0.55,model.videoHeight+0.025)}}
                HStack {Button("CLOSER") {model.videoDepth=min(-0.18,model.videoDepth+0.025)};Button("FARTHER") {model.videoDepth=max(-0.5,model.videoDepth-0.025)}}
                Button("RESET VIDEO POSITION") {model.resetVideoPosition()}
            }
            if model.spatialCue != nil {
                Text("Place arrows with your right fingertip.").font(.caption)
                HStack {Button("ARROW START") {model.beginCuePlacement("start")};Button("ARROW END") {model.beginCuePlacement("end")}}
                if model.cuePlacement != nil {Button("CANCEL MARKER") {model.cuePlacement=nil}}
            }
        }.frame(width:422,alignment:.leading).disabled(model.busyRecording)
    }
}

struct SettingsPanel: View {
    @Environment(StudioModel.self) private var model
    @Environment(VoiceCoach.self) private var voice
    @State private var section=ProcessInfo.processInfo.arguments.contains("--models-preview") ? 2 : 0
    var body:some View {
        VStack(alignment:.leading,spacing:9) {
            HStack {Button("AUDIO") {section=0}.buttonStyle(SquareButton(selected:section==0));Button("SCENE") {section=1}.buttonStyle(SquareButton(selected:section==1));Button("MODELS") {section=2}.buttonStyle(SquareButton(selected:section==2))}
            if section==0 {
                Toggle("Auto-read steps",isOn:Binding(get:{model.narrationEnabled},set:{model.narrationEnabled=$0;model.narrationRevision += 1;if !$0 {voice.cancelNarration()}}))
                Toggle("Repeat after video",isOn:Binding(get:{model.repeatNarrationAfterVideo},set:{model.repeatNarrationAfterVideo=$0;if !$0 {voice.cancelNarration()}}))
                Text("Off: video + written steps, without automatic spoken repetition.").font(.caption).lineLimit(2)
                HStack {
                    Menu {Button("Natural studio voice") {model.naturalNarration=true};Button("Device voice") {model.naturalNarration=false}} label:{Label(model.naturalNarration ? "STUDIO VOICE" : "DEVICE VOICE",systemImage:"chevron.down")}
                    Button("READ NOW") {model.requestNarration()}
                }
                Text("AI-generated narration · bundled for offline playback.").font(.caption2).foregroundStyle(.secondary)
                Divider()
                Button(voice.listening ? "VOICE COMMANDS / ON" : "VOICE COMMANDS / OFF") {voice.toggle()}
                Text(voice.status).font(.caption).lineLimit(2)
                Text("Next · Back · Slow down · Show that again. During video, say “GhostHands” first.").font(.caption).lineLimit(3)
            } else if section==2 {
                Toggle("Colored models",isOn:Binding(get:{model.coloredModels},set:{model.coloredModels=$0}))
                Text("Color adds metallic surfaces and distinct parts. Menus and hand guides stay black and white.").font(.caption)
                Text("INTERACTIVE LABS").font(.caption.monospaced())
                Text("Tap the brake caliper to clamp or release the rotor. Tap the pump impeller to start or stop it. Use Inspect for exploded views and rotation.").font(.system(size:14))
                Button("DISC BRAKE LAB") {model.chooseLesson(LessonCatalog.brake.id)}
                Button("WATER PUMP LAB") {model.chooseLesson(LessonCatalog.pump.id)}
            } else {
                Toggle("Human replay",isOn:Binding(get:{model.avatarEnabled},set:{model.avatarEnabled=$0}))
                Text("Record both hands for a mirrored person across the table.").font(.caption).lineLimit(2)
                Text("Table height: \(Int(model.avatarTableHeight*100)) cm").font(.caption)
                Slider(value:Binding(get:{Double(model.avatarTableHeight)},set:{model.avatarTableHeight=Float($0)}),in:0.6...1)
                Toggle("Ghost hands",isOn:Binding(get:{model.showHands},set:{model.showHands=$0}))
                Toggle("Guide model",isOn:Binding(get:{model.showGuides},set:{model.showGuides=$0}))
                if model.canSyncVideo {Toggle("Sync with video",isOn:Binding(get:{model.syncVideo},set:{model.setVideoSync($0)}))}
                Button("OPEN YOUTUBE") {model.showVideo()}
            }
        }.font(.system(size:14)).toggleStyle(.switch).frame(width:422,height:390,alignment:.topLeading)
    }
}

struct PaperMoveControl: View {
    @Environment(StudioModel.self) private var model
    let label:String
    let delta:SIMD3<Float>
    var body:some View {
        Button(label) {model.move(delta)}.buttonStyle(SquareButton(selected:true)).frame(width:95,height:65)
    }
}
struct PaperMoveFinish: View {
    @Environment(StudioModel.self) private var model
    var body:some View {
        HStack {Button("↶") {model.rotateWorkspace(-.pi/36)};Button("DONE") {model.finishAdjustment()};Button("↷") {model.rotateWorkspace(.pi/36)}}
            .buttonStyle(SquareButton()).padding(10).frame(width:270).background(.black)
    }
}
struct PaperFinishDiagram: View {
    let step: PaperStep
    var progress: Float = 1
    var body: some View {
        Canvas {context,size in
            let vertices=PaperMotion.vertices(step:step,progress:progress,width:LetterPaper.width)
            let scale=min(size.width/0.26,size.height/0.32)
            func p(_ v:SIMD3<Float>)->CGPoint {CGPoint(x:size.width/2+CGFloat(v.x)*scale,y:size.height/2+CGFloat(v.z-v.y*0.5)*scale)}
            for i in stride(from:0,to:vertices.count,by:3) {
                var path=Path();path.move(to:p(vertices[i]));path.addLine(to:p(vertices[i+1]));path.addLine(to:p(vertices[i+2]));path.closeSubpath()
                context.fill(path,with:.color(.white.opacity(0.08)));context.stroke(path,with:.color(.white),lineWidth:1.2)
            }
        }.accessibilityLabel(step.check)
    }
}
struct PaperDiagram: View {
    let step: PaperStep
    var body: some View {
        Canvas {context,size in
            let h=min(size.height*0.8,size.width/0.773*0.8),w=h*0.773
            func p(_ v:SIMD2<Float>)->CGPoint {CGPoint(x:size.width/2+CGFloat(v.x)*w/2,y:size.height/2+CGFloat(v.y)*h/2)}
            var outline=Path();outline.move(to:p(step.outline[0]));for v in step.outline.dropFirst(){outline.addLine(to:p(v))};outline.closeSubpath()
            context.fill(outline,with:.color(.white.opacity(0.09)));context.stroke(outline,with:.color(.white),lineWidth:2)
            var crease=Path();crease.move(to:p(step.crease.0));crease.addLine(to:p(step.crease.1));context.stroke(crease,with:.color(.white.opacity(0.6)),style:StrokeStyle(lineWidth:1,dash:[5,4]))
            let a=p(step.from),b=p(step.to);var arrow=Path();arrow.move(to:a);arrow.addQuadCurve(to:b,control:CGPoint(x:(a.x+b.x)/2+20,y:(a.y+b.y)/2-20));context.stroke(arrow,with:.color(.white),lineWidth:2)
            context.fill(Path(ellipseIn:CGRect(x:b.x-3,y:b.y-3,width:6,height:6)),with:.color(.white))
        }.accessibilityLabel("Step \(step.id+1). \(step.instruction)")
    }
}
