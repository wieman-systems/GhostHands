import SwiftUI

extension Color {
    static let ghostMint = Color.white
    static let ghostLavender = Color.white.opacity(0.7)
}
struct SquareButton: ButtonStyle {
    var selected=false
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.frame(maxWidth:.infinity,alignment:.center).multilineTextAlignment(.center).font(.system(size:15,weight:.medium))
            .padding(.horizontal,14).padding(.vertical,11).frame(minHeight:52)
            .foregroundStyle(selected ? .black : .white)
            .background(selected ? Color.white : Color.white.opacity(configuration.isPressed ? 0.24 : 0.06))
            .overlay(Rectangle().stroke(.white.opacity(selected ? 1 : 0.25),lineWidth:1))
            .contentShape(Rectangle()).opacity(enabled ? 1 : 0.35).hoverEffect(.highlight)
    }
}
struct DeskCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment:.leading,spacing:18) {
            HStack { Text(title).font(.system(size:12,weight:.semibold,design:.monospaced)).tracking(2); Spacer(); Image(systemName:"plus").font(.caption) }
            Rectangle().fill(.white.opacity(0.25)).frame(height:1)
            content
        }.padding(24).foregroundStyle(.white).background(.black.opacity(0.96))
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
            if model.immersive && !model.placed {
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
            }
        }.padding(36).frame(width:960,height:700).background(.black).foregroundStyle(.white)
            .overlay(Rectangle().stroke(.white.opacity(0.35),lineWidth:1)).preferredColorScheme(.dark)
            .alert("GhostHands",isPresented:Binding(get:{model.error != nil},set:{if !$0 {model.error=nil}})) { Button("OK") { model.error=nil } } message: { Text(model.error ?? "") }
            .task {
                #if targetEnvironment(simulator)
                if ["--spatial-preview","--avatar-preview","--move-preview","--setup-preview","--sync-preview","--repair-preview","--author-preview"].contains(where:{ProcessInfo.processInfo.arguments.contains($0)}),!model.previewConsumed {
                    model.previewConsumed=true;model.automaticVideo=ProcessInfo.processInfo.arguments.contains("--video-preview") || ProcessInfo.processInfo.arguments.contains("--sync-preview")
                    let result=await open(id:"studio")
                    if case .opened=result {
                        if ProcessInfo.processInfo.arguments.contains("--setup-preview") {return}
                        try? await Task.sleep(for:.milliseconds(700))
                        model.fingerPlacement=false; model.position=[0,1.25,-0.85]; model.placementReady=true; model.placed=true
                        model.setStep(9); model.seek(3.0)
                        if ProcessInfo.processInfo.arguments.contains("--sync-preview") {model.setStep(0)}
                        if ProcessInfo.processInfo.arguments.contains("--repair-preview") {model.chooseLesson(LessonCatalog.repair.id);model.setStep(3)}
                        if ProcessInfo.processInfo.arguments.contains("--author-preview") {model.beginAuthoring(blank:false);openWindow(id:"author")}
                        if ProcessInfo.processInfo.arguments.contains("--avatar-preview") {
                            var fixture=IllustratedMotion.clip(step:2,side:LetterPaper.width)
                            fixture.isIllustration=false;fixture.title="Simulator hand fixture"
                            model.load(fixture);model.seek(3);model.avatarEnabled=true;model.avatarTableHeight=0.8;model.tab = .settings
                        }
                        if ProcessInfo.processInfo.arguments.contains("--move-preview") {model.beginAdjustment()}
                        dismiss(id:"home")
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
        DeskCard(title:"01 / LEARN") {
            HStack { Text(model.course.title).font(.title2.bold()).lineLimit(1); Spacer(); Text(String(format:"%02d / %02d",model.step+1,model.stepCount)).font(.title3.monospacedDigit()) }
            if model.isPaperLesson {
            HStack(alignment:.top) {
                VStack(alignment:.leading,spacing:6) {Text("START SHAPE").font(.caption2.monospaced());PaperFinishDiagram(step:model.lesson,progress:model.currentStep.staticPaper ? 1 : 0).frame(height:110)}
                VStack(alignment:.leading,spacing:6) {Text("FINISH SHAPE").font(.caption2.monospaced());PaperFinishDiagram(step:model.lesson).frame(height:110)}
            }
            } else {
                VStack(spacing:10) {Image(systemName:"wrench.and.screwdriver").font(.system(size:38));Text(model.course.object).font(.caption);Text("MANUAL SPATIAL GUIDANCE").font(.caption2.monospaced())}.frame(maxWidth:.infinity).frame(height:130)
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
            Text("Watch this action, then try it. Next moves the video and guide together. Say “next” while the video is paused.").font(.system(size:11)).foregroundStyle(.secondary)
        }.frame(width:400)
    }
}

struct PlaybackControls: View {
    @Environment(StudioModel.self) private var model
    @Environment(\.dismissImmersiveSpace) private var dismiss
    @Environment(\.openWindow) private var open
    var body: some View {
        DeskCard(title:"GHOSTHANDS / TRANSPORT") {
            HStack {
                Text(model.selected?.isIllustration == false ? "YOUR RECORDED TAKE" : "ILLUSTRATED HANDS").font(.caption.monospaced())
                Spacer(); Text("\(model.elapsed,specifier:"%.1f") / \(model.progressDuration,specifier:"%.1f")s").font(.caption.monospacedDigit())
            }
            Slider(value:Binding(get:{model.elapsed},set:{model.seek($0)}),in:0...max(model.progressDuration,0.01)).disabled(model.selected==nil || model.busyRecording).accessibilityLabel("Playback position")
            HStack {
                Button {model.seek(0)} label:{Image(systemName:"backward.end.fill")}.disabled(model.busyRecording)
                Button(model.mode == .playing ? "PAUSE" : "PLAY",systemImage:model.mode == .playing ? "pause.fill" : "play.fill") {model.playPause()}.buttonStyle(SquareButton(selected:true)).disabled(!model.placed || model.busyRecording)
                Spacer()
                Button(model.loops ? "LOOP ON" : "LOOP OFF") {model.toggleLoop()}
            }
            HStack(spacing:6) {
                ForEach([0.25,0.5,0.75,1,1.5,2.0],id:\.self) { speed in
                    Button("\(speed.formatted())×") {model.changeSpeed(speed)}.buttonStyle(SquareButton(selected:model.speed==speed))
                }
            }.disabled(model.busyRecording)
            Button("REPLAY CURRENT DEMO") {model.replayCurrent()}.disabled(!model.placed || model.busyRecording)
            HStack {
                Text(model.sourceLabel).font(.system(size:11)).foregroundStyle(.secondary)
                Spacer()
                Button("HOME") {
                    guard !model.transitioning else {return};model.transitioning=true
                    Task {open(id:"home");await dismiss();model.transitioning=false}
                }.disabled(model.transitioning)
            }
        }.frame(width:570)
    }
}

struct SpatialControls: View {
    @Environment(StudioModel.self) private var model
    var body: some View {
        DeskCard(title:"02 / CREATE") {
            HStack(spacing:5) {
                ForEach([StudioTab.lessons,.record,.library,.placement,.settings],id:\.self) { tab in
                    Button(tab.rawValue) {model.tab=tab}.buttonStyle(SquareButton(selected:model.tab==tab || (tab == .record && model.tab == .learn)))
                }
            }.disabled(model.busyRecording)
            ScrollView {
                Group {
                    switch model.tab {
                    case .lessons: LessonLibraryPanel()
                    case .learn,.record: RecordPanel()
                    case .library: LibraryPanel()
                    case .placement: PlacementPanel()
                    case .video: VideoIntro()
                    case .settings: SettingsPanel()
                    }
                }.frame(maxWidth:.infinity,alignment:.leading)
            }.frame(height:310)
            Text(model.status).font(.system(size:11)).foregroundStyle(.secondary).lineLimit(3)
        }.frame(width:470)
            .alert("GhostHands",isPresented:Binding(get:{model.error != nil},set:{if !$0 {model.error=nil}})) {Button("OK"){model.error=nil}} message:{Text(model.error ?? "")}
    }
}

struct RecordPanel: View {
    @Environment(StudioModel.self) private var model
    var body: some View {
        @Bindable var model=model
        VStack(alignment:.leading,spacing:15) {
            Text("Teach this step.").font(.title2.bold())
            Text(model.currentStep.title).foregroundStyle(.secondary)
            TextField("Name your take",text:$model.recordingName).textFieldStyle(.plain).padding(12).overlay(Rectangle().stroke(.white.opacity(0.4))).disabled(model.busyRecording)
            HStack {
                ForEach([15.0,30,60],id:\.self) {seconds in Button("\(Int(seconds))s") {model.secondsToRecord=seconds}.buttonStyle(SquareButton(selected:model.secondsToRecord==seconds)).disabled(model.busyRecording)}
            }
            if model.busyRecording {
                Text(model.mode == .countdown ? "STARTING IN \(model.countdown)" : "REC / \(model.elapsed,specifier:"%.1f")s").font(.title2.monospacedDigit())
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
    var body: some View {
        VStack(alignment:.leading,spacing:14) {
            Text("Your teaching library").font(.title2.bold())
            Button("ILLUSTRATED EXAMPLE") {model.load(IllustratedMotion.clip(step:model.step,side:LetterPaper.width))}
            if model.clips.isEmpty {Text("Record a fold. Your take will appear here.").foregroundStyle(.secondary)}
            ForEach(model.clips) {clip in
                Button {model.load(clip)} label:{ VStack(alignment:.leading) {Text(clip.title);Text("\(clip.duration,specifier:"%.1f")s · \(Int(clip.trackedFraction*100))% tracked").font(.caption).foregroundStyle(.secondary)} }
            }
        }
    }
}
struct PlacementPanel: View {
    @Environment(StudioModel.self) private var model
    var body: some View {
        VStack(spacing:16) {
            Text("Fit your workspace").font(.title2.bold())
            Text("Tap Reposition to reveal arrows around the paper. Each tap moves it 1 cm; height arrows move it 2 mm.").multilineTextAlignment(.center)
            Button(model.adjustingPlacement ? "DONE MOVING" : "REPOSITION") {
                if model.adjustingPlacement {model.adjustingPlacement=false} else {model.beginAdjustment()}
            }.buttonStyle(SquareButton(selected:true))
            Button("CHOOSE A NEW TABLE SPOT") {model.beginPlacement()}
            Text("The object, menus, and human replay move together.").font(.caption)
            if !model.course.isBoat {
                Text(model.course.spatialNote).font(.caption)
                HStack {Button("ARROW START") {model.beginCuePlacement("start")};Button("ARROW END") {model.beginCuePlacement("end")}}
                if model.cuePlacement != nil {Text(model.status).font(.caption);Button("CANCEL MARKER") {model.cuePlacement=nil}}
            }
        }.disabled(model.busyRecording)
    }
}
struct SettingsPanel: View {
    @Environment(StudioModel.self) private var model
    @Environment(VoiceCoach.self) private var voice
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        VStack(spacing:12) {
            Text("Your workspace").font(.title3.bold())
            Button(voice.listening ? "VOICE / ON" : "VOICE / OFF") {voice.toggle()}.buttonStyle(SquareButton(selected:voice.listening))
            Text(voice.status).font(.caption)
            Text("Next · Back · Slow down · Show that again · Pause · Read instructions. During video, start with “GhostHands.”").font(.caption)
            if !voice.lastCommand.isEmpty {Text("Heard: \(voice.lastCommand)").font(.caption)}
            Button(model.narrationEnabled ? "READ INSTRUCTIONS / ON" : "READ INSTRUCTIONS / OFF") {model.narrationEnabled.toggle();model.narrationRevision += 1}
            Button(model.syncVideo ? "VIDEO SYNC / ON" : "VIDEO SYNC / OFF") {model.syncVideo.toggle();if model.syncVideo {model.sendVideo(seek:true,play:model.mode == .playing)}}
            Text("Read-aloud waits until video audio stops.").font(.caption)
            Button(model.avatarEnabled ? "HUMAN REPLAY / ON" : "HUMAN REPLAY / OFF") {model.avatarEnabled.toggle()}.buttonStyle(SquareButton(selected:model.avatarEnabled))
            Text(model.avatarStatus).font(.caption).foregroundStyle(.secondary)
            Text("Life-size mirrored replay across the table. Turn on, record BOTH hands, then replay. Arms/body are reconstructed; tracking gaps hide the person.").font(.caption).multilineTextAlignment(.center)
            if model.avatarEnabled {
                Text("TABLE HEIGHT / \(Int(model.avatarTableHeight*100)) CM").font(.caption.monospaced())
                Slider(value:Binding(get:{Double(model.avatarTableHeight)},set:{model.avatarTableHeight=Float($0)}),in:0.6...1.0)
            }
            Button(model.showHands ? "GHOST HANDS / ON" : "GHOST HANDS / OFF") {model.showHands.toggle()}
            Button(model.showGuides ? "PAPER MODEL / ON" : "PAPER MODEL / OFF") {model.showGuides.toggle()}
            Button("OPEN STEP VIDEO") {openWindow(id:"video")}
        }
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
        HStack {Button("↶") {model.yaw -= .pi/36};Button("DONE") {model.adjustingPlacement=false};Button("↷") {model.yaw += .pi/36}}
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
