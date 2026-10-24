import SwiftUI

extension Color {
    static let ghostMint = Color.white
    static let ghostLavender = Color.white.opacity(0.7)
}
struct SquareButton: ButtonStyle {
    var selected=false
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size:15,weight:.medium))
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
    @Environment(StudioModel.self) private var model
    @Environment(\.openImmersiveSpace) private var open
    @Environment(\.dismissImmersiveSpace) private var dismissSpace
    @Environment(\.dismissWindow) private var dismiss
    var body: some View {
        HStack(spacing:0) {
            VStack(alignment:.leading,spacing:24) {
                Text("GHOSTHANDS").font(.system(size:14,weight:.bold,design:.monospaced)).tracking(6)
                Spacer()
                Text(model.immersive ? "Set your\ntable." : "Learn it.\nMake it.\nPass it on.").font(.system(size:model.immersive ? 42 : 56,weight:.medium)).lineSpacing(-5)
                Text("A skill you can see from every angle.").font(.title3).foregroundStyle(.secondary)
                Button { enter() } label: { HStack { Text(model.transitioning ? "OPENING…" : "ENTER WORKSPACE"); Spacer(); Image(systemName:"arrow.up.right") } }
                    .buttonStyle(SquareButton(selected:true)).disabled(model.transitioning || model.immersive)
                if model.immersive && !model.placed {
                    Text(model.placementHint).font(.headline).fixedSize(horizontal:false,vertical:true)
                    Text(model.capture.status).font(.caption).foregroundStyle(.secondary)
                    Button("CANCEL SETUP") {Task {await dismissSpace()}}.buttonStyle(SquareButton())
                }
                Text("US LETTER / 8½ × 11 IN / NO CUTTING").font(.system(size:11,design:.monospaced)).foregroundStyle(.secondary)
                Spacer()
                Text("SASEHACKS 2026  ·  SKILLS FOR EVERYONE").font(.system(size:10,design:.monospaced)).foregroundStyle(.secondary)
            }.padding(40).frame(width:470)
            Rectangle().fill(.white.opacity(0.25)).frame(width:1)
            VStack(alignment:.leading,spacing:20) {
                HStack { Text("01 / PAPER BOAT").font(.system(size:13,design:.monospaced)).tracking(2); Spacer(); Text("\(PaperStep.all.count) STEPS").font(.caption.monospaced()) }
                PaperDiagram(step:PaperStep.all.last!).frame(height:245)
                Text("From a flat sheet\nto a three-dimensional boat.").font(.title.bold())
                Text("Touch the paper center with your right index, then pinch left. Watch one action at a time, with animated paper and soft joint hands.").font(.body).foregroundStyle(.secondary)
                HStack { Label("\(model.clips.count) saved takes",systemImage:"square.stack"); Spacer(); Text("ON DEVICE").font(.caption.monospaced()) }.font(.caption)
            }.padding(36)
        }.frame(width:960,height:640).background(.black).foregroundStyle(.white)
            .overlay(Rectangle().stroke(.white.opacity(0.35),lineWidth:1)).preferredColorScheme(.dark)
            .alert("GhostHands",isPresented:Binding(get:{model.error != nil},set:{if !$0 {model.error=nil}})) { Button("OK") { model.error=nil } } message: { Text(model.error ?? "") }
            .task {
                #if targetEnvironment(simulator)
                if ProcessInfo.processInfo.arguments.contains("--spatial-preview"),!model.previewConsumed {
                    model.previewConsumed=true
                    let result=await open(id:"studio")
                    if case .opened=result {
                        try? await Task.sleep(for:.milliseconds(700))
                        model.fingerPlacement=false; model.position=[0,1.25,-0.85]; model.placementReady=true; model.placed=true
                        model.load(IllustratedMotion.clip(step:10,side:LetterPaper.width)); model.seek(3.0)
                        dismiss(id:"home")
                    }
                }
                #endif
            }
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
            HStack { Text("Paper boat").font(.title2.bold()); Spacer(); Text(String(format:"%02d / %02d",model.step+1,PaperStep.all.count)).font(.title3.monospacedDigit()) }
            HStack(alignment:.top) {
                VStack(alignment:.leading,spacing:6) {Text("START SHAPE").font(.caption2.monospaced());PaperFinishDiagram(step:model.lesson,progress:0).frame(height:110)}
                VStack(alignment:.leading,spacing:6) {Text("FINISH SHAPE").font(.caption2.monospaced());PaperFinishDiagram(step:model.lesson).frame(height:110)}
            }
            Text(model.lesson.phase(at:model.elapsed)).font(.caption.monospaced()).padding(8).overlay(Rectangle().stroke(.white.opacity(0.3)))
            Text(model.lesson.title).font(.title3.bold())
            Text(model.lesson.instruction).font(.system(size:17)).fixedSize(horizontal:false,vertical:true)
            Text(model.lesson.check).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
            HStack {
                Button {model.setStep(model.step-1)} label:{Image(systemName:"arrow.left")}.disabled(model.step==0 || model.busyRecording)
                Spacer()
                Button(model.step==PaperStep.all.count-1 ? "FINISHED" : "NEXT STEP") {model.setStep(model.step+1)}.disabled(model.step==PaperStep.all.count-1 || model.busyRecording)
            }
            HStack {
                Button("SHOW START") {model.seek(0)}
                Button("SHOW FINISH") {model.seek(model.selected?.duration ?? 8)}
            }.disabled(model.busyRecording)
            Text("Watch the moving paper, then copy this one action. Next starts the next demonstration automatically.").font(.system(size:11)).foregroundStyle(.secondary)
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
                Spacer(); Text("\(model.elapsed,specifier:"%.1f") / \(model.selected?.duration ?? 8,specifier:"%.1f")s").font(.caption.monospacedDigit())
            }
            Slider(value:Binding(get:{model.elapsed},set:{model.seek($0)}),in:0...max(model.selected?.duration ?? 8,0.01)).disabled(model.selected==nil || model.busyRecording).accessibilityLabel("Playback position")
            HStack {
                Button {model.seek(0)} label:{Image(systemName:"backward.end.fill")}.disabled(model.busyRecording)
                Button(model.mode == .playing ? "PAUSE" : "PLAY",systemImage:model.mode == .playing ? "pause.fill" : "play.fill") {model.playPause()}.buttonStyle(SquareButton(selected:true)).disabled(!model.placed || model.busyRecording)
                Spacer()
                Button(model.loops ? "LOOP ON" : "LOOP OFF") {model.loops.toggle()}
            }
            HStack(spacing:6) {
                ForEach([0.25,0.5,0.75,1,1.5,2.0],id:\.self) { speed in
                    Button("\(speed.formatted())×") {model.speed=speed}.buttonStyle(SquareButton(selected:model.speed==speed))
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
                ForEach([StudioTab.record,.library,.placement,.video],id:\.self) { tab in
                    Button(tab.rawValue) {model.tab=tab}.buttonStyle(SquareButton(selected:model.tab==tab || (tab == .record && model.tab == .learn)))
                }
            }.disabled(model.busyRecording)
            ScrollView {
                Group {
                    switch model.tab {
                    case .learn,.record: RecordPanel()
                    case .library: LibraryPanel()
                    case .placement: PlacementPanel()
                    case .video: VideoIntro()
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
            Text(model.lesson.title).foregroundStyle(.secondary)
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
        VStack(alignment:.leading,spacing:14) {
            Text(model.placed ? "Paper locked in." : "Touch the paper center.").font(.title2.bold())
            Text("US LETTER / 8½ × 11 IN").font(.caption.monospaced())
            Text("Rest your right index fingertip on the paper center. Open your left hand, then pinch left to lock the whole table. Keep your right fingertip still until it locks.").fixedSize(horizontal:false,vertical:true)
            if model.placed {Button("REPOSITION PAPER") {model.beginPlacement()}}
            else {Button("START LESSON HERE") {model.confirmPlacement()}.buttonStyle(SquareButton(selected:true)).disabled(!model.immersive)}
            Text("FINE ADJUSTMENT / 1 CM").font(.caption.monospaced())
            HStack {Button("←") {model.move([-0.01,0,0])};Button("→") {model.move([0.01,0,0])};Button("DOWN") {model.move([0,-0.01,0])};Button("UP") {model.move([0,0.01,0])}}
            HStack {Button("AWAY") {model.move([0,0,-0.01])};Button("CLOSER") {model.move([0,0,0.01])}}
            HStack {Button("↶ 5°") {model.yaw -= .pi/36};Button("↷ 5°") {model.yaw += .pi/36}}
            Text("CONTACT HEIGHT / 2 MM").font(.caption.monospaced())
            HStack {Button("LOWER 2 MM") {model.move([0,-0.002,0])};Button("RAISE 2 MM") {model.move([0,0.002,0])}}
            Button(model.showHands ? "HANDS ON" : "HANDS OFF") {model.showHands.toggle()}
            Button(model.showGuides ? "PAPER MODEL ON" : "PAPER MODEL OFF") {model.showGuides.toggle()}
        }.disabled(model.busyRecording)
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
