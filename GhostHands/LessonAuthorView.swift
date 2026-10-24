import SwiftUI
import UniformTypeIdentifiers

struct LessonDocument:FileDocument {
    static var readableContentTypes:[UTType]{[.json]}
    var data:Data
    init(_ lesson:LessonDefinition){let e=JSONEncoder();e.outputFormatting=[.prettyPrinted,.sortedKeys];data=(try? e.encode(lesson)) ?? Data()}
    init(configuration:ReadConfiguration)throws {data=configuration.file.regularFileContents ?? Data()}
    func fileWrapper(configuration:WriteConfiguration)throws->FileWrapper {FileWrapper(regularFileWithContents:data)}
}
struct LessonAuthorView:View {
    @Environment(StudioModel.self) private var model
    @Environment(\.openWindow) private var open
    @Environment(\.dismissWindow) private var dismiss
    @State private var link=""
    @State private var exporting=false
    private func field(_ key:WritableKeyPath<LessonDefinition,String>)->Binding<String> {.init(get:{model.draft?[keyPath:key] ?? ""},set:{model.draft?[keyPath:key]=$0})}
    private func stepField(_ key:WritableKeyPath<LessonStep,String>)->Binding<String> {.init(get:{model.currentStep[keyPath:key]},set:{value in update{$0[keyPath:key]=value}})}
    private func update(_ body:(inout LessonStep)->Void) {guard var draft=model.draft,draft.steps.indices.contains(model.step) else{return};body(&draft.steps[model.step]);model.draft=draft}
    var body:some View {
        VStack(alignment:.leading,spacing:18) {
            HStack {Text("GHOSTHANDS / LESSON AUTHOR").font(.headline.monospaced());Spacer();Button("CLOSE") {model.cancelDraft();dismiss(id:"author")}.frame(width:130).disabled(model.busyRecording || model.hasUnsaved)}
            if model.isAuthoring,model.draft != nil {
                ScrollView {
                    VStack(alignment:.leading,spacing:16) {
                        HStack {TextField("Lesson title",text:field(\.title));TextField("Object / exact model",text:field(\.object))}
                        TextField("Preparation and tools",text:field(\.preparation),axis:.vertical)
                        HStack {TextField("YouTube link",text:$link).textInputAutocapitalization(.never).autocorrectionDisabled();Button("LOAD LINK") {
                            guard YouTubeLink(link) != nil else{model.error="Enter a valid YouTube link.";return}
                            if model.draft?.videoURL != link {model.draft?.videoURL=link;for i in model.draft!.steps.indices {model.draft!.steps[i].segment=nil}}
                            model.sendVideo(seek:true,play:false);open(id:"video")
                        }.frame(width:150)}
                        HStack {
                            Button("PREVIOUS") {model.setStep(model.step-1)}.disabled(model.step==0)
                            Text("\(model.step+1) / \(model.stepCount)").monospacedDigit()
                            Button("NEXT") {model.setStep(model.step+1)}.disabled(model.step==model.stepCount-1)
                            Button("ADD STEP") {model.draft?.steps.append(.init(title:"New action",instruction:"Describe this action.",check:"Describe its result."));model.setStep(model.stepCount-1)}
                        }
                        TextField("Step title",text:stepField(\.title))
                        TextField("Instructions",text:stepField(\.instruction),axis:.vertical).lineLimit(3...6)
                        TextField("How to check completion",text:stepField(\.check),axis:.vertical)
                        HStack {
                            Text("VIDEO \(model.video.currentTime,specifier:"%.1f")s").monospacedDigit()
                            Button("MARK START") {update{$0.segment = .init(start:model.video.currentTime,end:max($0.segment?.end ?? 0,model.video.currentTime+5))}}
                            Button("MARK END") {update{$0.segment = .init(start:$0.segment?.start ?? max(0,model.video.currentTime-5),end:model.video.currentTime)}}
                        }.disabled(!model.video.ready || !model.video.visible)
                        HStack {
                            Text("Start");TextField("0",value:Binding(get:{model.currentStep.segment?.start ?? 0},set:{value in update{$0.segment = .init(start:value,end:$0.segment?.end ?? value+5)}}),format:.number).frame(width:90)
                            Text("End");TextField("5",value:Binding(get:{model.currentStep.segment?.end ?? 5},set:{value in update{$0.segment = .init(start:$0.segment?.start ?? 0,end:value)}}),format:.number).frame(width:90)
                            Button("PREVIEW SEGMENT") {if let segment=model.currentStep.segment,segment.isValid,let id=YouTubeLink(model.course.videoURL)?.videoID {model.video.request(videoID:id,segment:segment,play:true,rate:model.speed)}}
                        }
                        Text("Scrub the video, mark the action's start and end, then preview it. Each step needs a human review before saving.").font(.caption).foregroundStyle(.secondary)
                        HStack {
                            Button("PLACE ARROW START") {model.beginCuePlacement("start")}
                            Button("PLACE ARROW END") {model.beginCuePlacement("end")}
                        }.disabled(!model.placed || model.busyRecording)
                        Text(model.cuePlacement == nil ? "Place the workspace first. Lift your right index, move to the target, and hold for two seconds." : model.status).font(.caption)
                        HStack {
                            if model.mode == .recording {Button("STOP + SAVE") {model.finishRecording()}}
                            else if model.mode == .countdown {Button("CANCEL COUNTDOWN") {model.cancelCountdown()}}
                            else {Button("RECORD THIS ACTION") {model.tab = .record;model.beginRecording()}.disabled(!model.placed || !model.capture.ready)}
                            Button("ATTACH SELECTED TAKE") {if let clip=model.selected,!clip.isIllustration {update{$0.recordingID=clip.id}}}.disabled(model.selected == nil || model.selected?.isIllustration == true)
                        }
                        if let id=model.currentStep.recordingID {Text("Attached take: \(model.clips.first{$0.id==id}?.title ?? "Not on this device")").font(.caption)}
                        Text("Export includes instructions, times and markers. Hand recordings stay on this device and are not included.").font(.caption).foregroundStyle(.secondary)
                    }.textFieldStyle(AuthorFieldStyle()).padding(2)
                }.frame(height:545)
                HStack {
                    Button("OPEN VIDEO") {open(id:"video")}
                    Button("EXPORT JSON") {exporting=true}.disabled(!model.course.isValid)
                    Button("SAVE + USE LESSON") {model.saveDraft();if !model.isAuthoring {dismiss(id:"author")}}.buttonStyle(SquareButton(selected:true)).disabled(model.busyRecording)
                }
            } else {Text("Choose New Lesson or Edit a Copy in Lessons.").frame(maxWidth:.infinity,maxHeight:.infinity)}
        }.padding(24).frame(width:900,height:740).background(.black).foregroundStyle(.white).buttonStyle(SquareButton()).preferredColorScheme(.dark)
        .onAppear{link=model.course.videoURL}
        .onDisappear{if model.isAuthoring {model.cancelDraft()}}
        .fileExporter(isPresented:$exporting,document:LessonDocument(model.exportLesson),contentType:.json,defaultFilename:model.course.id){result in if case .failure(let error)=result {model.error=error.localizedDescription}}
        .alert("Lesson editor",isPresented:Binding(get:{model.error != nil},set:{if !$0 {model.error=nil}})){Button("OK"){model.error=nil}}message:{Text(model.error ?? "")}
    }
}
struct LessonLibraryPanel:View {
    @Environment(StudioModel.self) private var model
    @Environment(\.openWindow) private var open
    @State private var importing=false
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            ForEach(model.lessons) {lesson in
                Button {model.chooseLesson(lesson.id)} label:{VStack(alignment:.leading){Text(lesson.title).font(.headline);Text(lesson.object).font(.caption)}}.buttonStyle(SquareButton(selected:model.course.id==lesson.id))
            }
            Text(model.course.preparation).font(.caption)
            Text("Tools: "+model.course.tools.joined(separator:", ")).font(.caption)
            HStack {
                Button("NEW LESSON") {model.beginAuthoring(blank:true);open(id:"author");open(id:"video")}
                Button("EDIT A COPY") {model.beginAuthoring(blank:false);open(id:"author");open(id:"video")}
            }
            Button("IMPORT LESSON JSON") {importing=true}
        }.disabled(model.busyRecording || model.hasUnsaved)
        .fileImporter(isPresented:$importing,allowedContentTypes:[.json]){result in
            do {
                let url=try result.get();let scope=url.startAccessingSecurityScopedResource();defer{if scope {url.stopAccessingSecurityScopedResource()}}
                let data=try Data(contentsOf:url);guard data.count<=2_000_000 else{throw LessonError.invalid}
                var lesson=try JSONDecoder().decode(LessonDefinition.self,from:data);guard lesson.isValid else{throw LessonError.invalid}
                lesson.id="lesson-"+UUID().uuidString.lowercased();model.draft=lesson;model.isAuthoring=true;model.step=0;model.saveDraft()
            } catch {model.error=error.localizedDescription}
        }
    }
}
struct PartsTray:View {
    @Environment(StudioModel.self) private var model
    var body:some View {
        VStack(spacing:8) {
            Text("PARTS TRAY / TAP TO MARK STORED OR RETURNED").font(.system(size:10,design:.monospaced))
            HStack(spacing:10) {
                ForEach(Array(model.course.trayLabels.enumerated()),id:\.offset){index,label in
                    Button {if model.trayContents.contains(index){model.trayContents.remove(index)}else{model.trayContents.insert(index)}} label:{VStack(spacing:8){Text("\(index+1)").font(.title);Text(label).font(.caption);Text(model.trayContents.contains(index) ? "STORED" : "EMPTY").font(.caption2)}}
                        .buttonStyle(SquareButton(selected:model.currentStep.traySlot==index)).frame(width:120,height:100)
                }
            }
            if model.currentStep.reassembly {Text("REASSEMBLY / Return the highlighted part").font(.caption)}
        }.padding(12).background(.black).foregroundStyle(.white)
    }
}

struct AuthorFieldStyle:TextFieldStyle {func _body(configuration:TextField<Self._Label>)->some View {configuration.padding(10).background(Color.white.opacity(0.08)).overlay(Rectangle().stroke(Color.white.opacity(0.4),lineWidth:1))}}
