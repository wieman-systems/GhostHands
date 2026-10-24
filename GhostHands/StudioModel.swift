import Foundation
import Observation
import QuartzCore
import simd

enum StudioTab: String, CaseIterable { case lessons = "Lessons", settings = "Settings", learn = "Learn", record = "Record", library = "Library", placement = "Place", video = "Video" }
enum Transport { case idle, countdown, recording, playing, paused }

@MainActor @Observable
final class StudioModel {
    let capture = HandCapture()
    var tab: StudioTab = .learn
    var immersive = false
    var transitioning = false
    var mode: Transport = .idle
    var status = "Place the workspace on your table, then follow a lesson or record your own."
    var error: String?
    let video = VideoSession()
    var activeLessonID = LessonCatalog.boat.id
    var customLessons: [LessonDefinition] = []
    var draft: LessonDefinition?
    var isAuthoring = false
    var syncVideo = true
    var narrationEnabled = true {didSet {saveNarrationPreferences()}}
    var repeatNarrationAfterVideo = false {didSet {saveNarrationPreferences();narrationRevision += 1}}
    var naturalNarration = true {didSet {saveNarrationPreferences()}}
    var manualNarrationRevision = 0
    var narrationRevision = 0
    private var lastEndedSerial = -1
    var cuePlacement: String?
    var cueOverrides: [String:SpatialCue] = [:]
    var trayContents: Set<Int> = []
    var engineFocus:EnginePart?
    var labFocus:LabPart?
    var explodedView=false
    var modelScale:Float=1
    var modelRotation:Float=0
    var showFlow=true
    var showCasing=true
    var revealDefect=false
    var defectFound=false
    var mechanismEngaged=false
    var coloredModels=false {didSet {saveVisualPreferences()}}
    var mechanismAngle:Float=0
    var mechanismBlend:Float=0
    func saveVisualPreferences() {
        let url=storage.deletingLastPathComponent().appendingPathComponent("VisualPreferences.json")
        do {try FileManager.default.createDirectory(at:url.deletingLastPathComponent(),withIntermediateDirectories:true);try JSONEncoder().encode(coloredModels).write(to:url,options:.atomic)} catch {self.error="Could not save model colors."}
    }
    var mechanismAction:String {course.mechanicalModel == .brake ? (mechanismEngaged ? "Release brake" : "Apply brake") : (mechanismEngaged ? "Start pump" : "Stop pump")}
    func operateMechanism() {
        guard placed,workspaceVisible,!busyRecording,!adjustingPlacement,!explodedView,[.brake,.pump].contains(course.mechanicalModel) else{return}
        mechanismEngaged.toggle();mode = .playing;elapsed=0
        status=course.mechanicalModel == .brake ? (mechanismEngaged ? "Brake applied · pads clamp the rotor." : "Brake released.") : (mechanismEngaged ? "Pump stopped." : "Pump running.")
    }
    private var cueCalibration = TableCalibration()
    private var cueApproach: SIMD3<Float>?
    private var cueApproached = false
    var step = 0
    var clips: [MotionClip] = []
    var selected: MotionClip?
    var elapsed = 0.0
    var speed = 0.75
    var loops = false
    var showGuides = true
    var showHands = true
    var adjustingPlacement = false
    var trackingIssue:String?
    private var workspaceLock=WorkspaceLock()
    var workspaceVisible:Bool {trackingIssue == nil && interactionActive}
    var placementProgress: Float = 0
    var avatarEnabled = false
    var avatarStatus = "Off"
    var avatarTableHeight: Float = 0.8
    var automaticVideo = true
    var dockedVideo=false
    var videoOwner:UUID?
    var videoHeight:Float=0.30
    var videoDepth:Float = -0.29
    var paperSide: Float = LetterPaper.width
    var paperHeight: Float = LetterPaper.height
    var placementReady = false
    var placementHint = "Rest your right index on the paper center."
    var secondsToRecord = 15.0
    var countdown = 3
    var recordingName = ""
    var trackedHands = 0
    var placed = false
    var saving = false
    var savedMessage = ""
    var position = SIMD3<Float>(0, 0, -0.45)
    var fingerPlacement = false
    private var approachOrigin: SIMD3<Float>?
    private var approachedTable = false
    private var calibration = TableCalibration()
    var interactionActive = true
    var yaw: Float = 0
    @ObservationIgnored var onRender: ((MotionFrame?, MotionFrame, Float) -> Void)?
    @ObservationIgnored private var frames: [MotionFrame] = []
    @ObservationIgnored private var recordingContext:(lessonID:String,step:Int,title:String)?
    @ObservationIgnored private var started = 0.0
    @ObservationIgnored private var previousTick = 0.0
    @ObservationIgnored private var lastCapture = 0.0
    @ObservationIgnored private var unsaved: MotionClip?
    @ObservationIgnored private let storage: URL
    #if targetEnvironment(simulator)
    @ObservationIgnored var previewConsumed = false
    #endif

    init(storage: URL? = nil) {
        self.storage = storage ?? URL.documentsDirectory.appendingPathComponent("GhostHandsRecordings", isDirectory: true)
        if let data=try? Data(contentsOf:self.storage.deletingLastPathComponent().appendingPathComponent("NarrationPreferences.json")),let preferences=try? JSONDecoder().decode(NarrationPreferences.self,from:data) {
            narrationEnabled=preferences.enabled;repeatNarrationAfterVideo=preferences.repeatAfterVideo;naturalNarration=preferences.naturalVoice
        }
        if let data=try? Data(contentsOf:self.storage.deletingLastPathComponent().appendingPathComponent("VisualPreferences.json")),let colored=try? JSONDecoder().decode(Bool.self,from:data) {coloredModels=colored}
        let result = ClipStorage.load(in: self.storage)
        clips = result.clips
        customLessons = LessonStorage.load(in:self.storage.deletingLastPathComponent().appendingPathComponent("GhostHandsLessons"))
        if let data=try? Data(contentsOf:self.storage.deletingLastPathComponent().appendingPathComponent("GhostHandsCues.json")),let cues=try? JSONDecoder().decode([String:SpatialCue].self,from:data) {cueOverrides=cues.filter{$0.value.isValid}}
        if result.failures > 0 { error = "\(result.failures) unreadable recording(s) were left untouched in storage." }
    }
    var busyRecording: Bool { mode == .recording || mode == .countdown }
    var workspace: simd_float4x4 {
        var matrix = simd_float4x4(simd_quatf(angle: yaw, axis: [0,1,0]))
        matrix.columns.3 = SIMD4(position, 1)
        return matrix
    }
    var lessons:[LessonDefinition] {LessonCatalog.all.filter(\.isValid)+customLessons}
    var course:LessonDefinition {if isAuthoring,let draft{return draft};return lessons.first{$0.id==activeLessonID} ?? LessonCatalog.boat}
    var currentStep:LessonStep {course.steps[min(max(step,0),course.steps.count-1)]}
    var stepCount:Int {course.steps.count}
    var lesson: PaperStep {PaperStep.all[currentStep.paperIndex ?? 0]}
    var isPaperLesson:Bool {currentStep.paperIndex != nil}
    var linkedVideo:Bool {syncVideo && video.visible && !video.failed && !isAuthoring && currentStep.segment != nil && !busyRecording}
    var cueKey:String {course.id+"/"+currentStep.id}
    var spatialCue:SpatialCue? {cueOverrides[cueKey] ?? currentStep.cue}
    var instructionToRead:String {NarrationPolicy.text(for:currentStep)}
    var automaticNarrationAllowed:Bool {NarrationPolicy.allows(automatic:narrationEnabled,hasVideo:video.visible && !video.failed && course.hasVideo,repeatAfterVideo:repeatNarrationAfterVideo,manual:false)}
    func saveNarrationPreferences() {
        let preferences=NarrationPreferences(enabled:narrationEnabled,repeatAfterVideo:repeatNarrationAfterVideo,naturalVoice:naturalNarration)
        let url=storage.deletingLastPathComponent().appendingPathComponent("NarrationPreferences.json")
        do {try FileManager.default.createDirectory(at:url.deletingLastPathComponent(),withIntermediateDirectories:true);try JSONEncoder().encode(preferences).write(to:url,options:.atomic)} catch {self.error="Could not save audio preferences."}
    }
    func requestNarration() {pauseVideo();manualNarrationRevision += 1}
    func selectLabPart(_ name:String) {
        guard !busyRecording,!adjustingPlacement else{return}
        if name=="lab-defect",currentStep.id=="inspect" {defectFound=true;status="Finding marked: this example has a shortened \(course.mechanicalModel == .jet ? "blade tip" : "gear tooth")."}
        else if name.hasPrefix("lab-part-") {labFocus=LabPart(rawValue:String(name.dropFirst(9)));if (course.mechanicalModel == .brake && labFocus == .caliper) || (course.mechanicalModel == .pump && labFocus == .impeller) {operateMechanism()}}
    }
    var progressDuration:Double {selected?.duration ?? currentStep.segment?.duration ?? 8}

    var sourceLabel: String { selected?.isIllustration == false ? "Recorded hands" : isPaperLesson ? "Illustrated motion · not a recording" : course.mechanicalModel == .brake ? "Disc brake · interactive assembly" : course.mechanicalModel == .pump ? "Water pump · interactive assembly" : course.mechanicalModel == .jet ? "Turbofan · teaching cutaway" : course.mechanicalModel == .gearbox ? "Gear drive · teaching assembly" : course.mechanicalModel == .engine ? "Engine cutaway · illustrative" : course.mechanicalModel == .cabinFilter ? "Manual cues + filter model" : "Manually placed spatial cues" }

    func entered() async {
        guard !immersive else{return}
        immersive = true; interactionActive = true; previousTick = 0; placed = false
        capture.onWorkspaceAnchor = { [weak self] transform,tracked in self?.receiveWorkspaceAnchor(transform,tracked:tracked) }
        status = "Use Place to align the outline with your paper."
        beginPlacement()
        await capture.start()
        guard !Task.isCancelled, immersive else { return }
    }
    func leftStudio() {
        capture.onWorkspaceAnchor=nil;workspaceLock.reset();trackingIssue=nil
        if mode == .recording { finishRecording() }
        pauseVideo();dockedVideo=false; cuePlacement=nil; mode = .paused; immersive = false; transitioning = false
        onRender = nil; capture.stop()
    }
    func suspend() {
        if mode == .recording { finishRecording() }
        pauseVideo();cuePlacement=nil;mode = .paused; calibration.reset(); interactionActive=false; capture.clear()
        placementReady = false
        onRender?(nil,capture.snapshot(at:CACurrentMediaTime()),0)
    }
    func beginPlacement() {
        guard !busyRecording else { return }
        capture.clearWorkspaceAnchor();workspaceLock.reset();trackingIssue=nil
        pauseVideo();cuePlacement=nil;mode = .paused; placed = false; placementReady = false
        fingerPlacement = false; calibration.reset(); placementReady = false; placementProgress=0;adjustingPlacement=false
        placed = false; tab = .placement
        placementHint = "Rest your right index on the paper center and hold it still."
        status = "Clear your workspace, then lift and rest your right index at its center for two seconds."
    }
    func startFingerPlacement() {
        guard immersive,!placed else{return}
        calibration.reset();fingerPlacement=true;placementProgress=0;approachOrigin=nil;approachedTable=false
        placementHint="Rest your RIGHT index fingertip in the center of the clear spot. Hold still for two seconds."
    }
    func beginAdjustment() {
        guard placed,!busyRecording else{return}
        guard trackingIssue == nil else{return}
        capture.clearWorkspaceAnchor();pauseVideo();mode = .paused;adjustingPlacement=true
    }
    func move(_ delta: SIMD3<Float>) {
        guard placed,adjustingPlacement,!busyRecording,delta.isFinite,simd_length(delta)<=0.025 else { return }
        position += simd_act(simd_quatf(angle: yaw, axis: [0,1,0]), delta)
    }
    func resizePaper(_ size: Float) {
        guard !busyRecording else { return }
        paperSide = size
        selected = currentStep.paperIndex.map {IllustratedMotion.clip(step:$0,side:size)}
        elapsed = 0; mode = .paused
        status = "Guide resized. Recorded takes keep the paper size they were captured with."
    }
    func setStep(_ index: Int) {
        guard !busyRecording else { return }
        step = min(max(index, 0), stepCount - 1);cuePlacement=nil;revealDefect=false;defectFound=false;labFocus=nil
        paperSide = LetterPaper.width; paperHeight = LetterPaper.height; showGuides = true
        selected = currentStep.recordingID.flatMap {id in clips.first{$0.id==id}}
        if selected == nil,let paper=currentStep.paperIndex {selected=IllustratedMotion.clip(step:paper,side:paperSide)}
        elapsed = currentStep.staticPaper ? progressDuration : 0; previousTick = 0
        mode = immersive && placed && !isAuthoring ? .playing : .paused
        if isAuthoring || currentStep.segment != nil || video.command?.videoID != YouTubeLink(course.videoURL)?.videoID {
            sendVideo(seek:true,play:mode == .playing,time:isAuthoring ? (currentStep.segment?.start ?? video.currentTime) : nil)
        }
        narrationRevision += 1
    }
    func chooseLesson(_ id:String) {
        guard !busyRecording,!hasUnsaved,lessons.contains(where:{$0.id==id}) else{return}
        pauseVideo();isAuthoring=false;draft=nil;activeLessonID=id;trayContents=[];engineFocus=nil;labFocus=nil;explodedView=false;modelScale=1;modelRotation=0;mechanismEngaged=false;mechanismAngle=0;mechanismBlend=0;loops=[.brake,.pump].contains(course.mechanicalModel);setStep(0);tab = .lessons
    }
    func sendVideo(seek:Bool,play:Bool,time:Double?=nil) {
        guard let link=YouTubeLink(course.videoURL) else{return}
        video.request(videoID:link.videoID,segment:isAuthoring ? nil : currentStep.segment,time:time,seek:seek,play:play && (isAuthoring || currentStep.segment != nil),rate:speed,loop:loops && !isAuthoring)
    }
    func pauseVideo() {if video.visible {sendVideo(seek:false,play:false)}}
    func showVideo() {guard course.hasVideo else{return};dockedVideo=true}
    func videoOpened(owner:UUID?=nil) {videoOwner=owner;video.visible=true;sendVideo(seek:true,play:immersive && placed && !isAuthoring && !busyRecording)}
    func retryVideo() {video.failed=false;video.ready=false;video.playerGeneration += 1;videoOpened(owner:videoOwner)}
    func videoClosed(owner:UUID?=nil) {if let owner,videoOwner != owner {return};videoOwner=nil;let wasLinked=linkedVideo;video.close();if wasLinked {mode = .paused};narrationRevision += 1}
    func changeSpeed(_ value:Double) {speed=min(2,max(0.25,value));if linkedVideo {sendVideo(seek:false,play:video.playing)}}
    func toggleLoop() {loops.toggle();if linkedVideo {sendVideo(seek:false,play:video.playing)}}
    func acceptVideo(serial:Int,id:String,time:Double,duration:Double,state:Int,rate:Double,ended:Bool) {
        guard video.receive(serial:serial,videoID:id,time:time,duration:duration,state:state,rate:rate) else{return}
        guard immersive,placed,interactionActive,linkedVideo,let segment=currentStep.segment else{return}
        elapsed=currentStep.staticPaper ? progressDuration : segment.progress(at:time)*progressDuration
        mode = state==1 ? .playing : .paused
        if ended {elapsed=progressDuration;mode = .paused;if lastEndedSerial != serial {lastEndedSerial=serial;narrationRevision += 1}}
    }
    func applyVoice(_ command:VoiceCommand) {
        guard immersive,placed,interactionActive,workspaceVisible,!busyRecording,!isAuthoring else{return}
        switch command {
        case .next:if step<stepCount-1 {setStep(step+1)}
        case .back:if step>0 {setStep(step-1)}
        case .slower:changeSpeed(speed-0.25)
        case .faster:changeSpeed(speed+0.25)
        case .replay:replayCurrent()
        case .pause:mode = .paused;pauseVideo()
        case .play:if mode != .playing {playPause()}
        case .read:requestNarration()
        case .stopListening:break
        }
    }
    func load(_ clip: MotionClip) {
        guard !busyRecording else { return }
        selected = clip; elapsed = 0; paperSide = clip.paperSide; paperHeight = clip.paperHeight ?? clip.paperSide
        if clip.lessonID == "letter-boat-guided-v3", let oldStep = clip.lessonStep {
            activeLessonID=LessonCatalog.boat.id;self.step=LessonCatalog.boat.steps.firstIndex{$0.id=="boat-\(oldStep)"} ?? 0
        } else if let id=clip.lessonID,lessons.contains(where:{$0.id==id}) {activeLessonID=id;self.step=min(clip.lessonStep ?? 0,stepCount-1)}
        showGuides = isPaperLesson || course.mechanicalModel != nil || spatialCue != nil
        mode = immersive && placed ? .playing : .paused; previousTick = 0; tab = .learn;if currentStep.segment != nil {sendVideo(seek:true,play:mode == .playing)}
    }
    func playPause() {
        guard immersive, placed, !busyRecording else { return }
        if mode == .playing || (linkedVideo && video.playing) { mode = .paused;if linkedVideo {pauseVideo()};return }
        if selected == nil && currentStep.paperIndex != nil { setStep(step) }
        if elapsed >= progressDuration { elapsed = 0;if linkedVideo {sendVideo(seek:true,play:true);mode = .playing;return} }
        mode = .playing
        if linkedVideo {sendVideo(seek:false,play:true)}
    }
    func resumeInteraction() { interactionActive=true;previousTick=0;calibration.reset() }
    func replayCurrent() {
        guard immersive,placed,!busyRecording else{return}
        elapsed=currentStep.staticPaper ? progressDuration : 0;previousTick=0;mode = .playing;if currentStep.segment != nil {sendVideo(seek:true,play:true)}
    }
    func seek(_ value: Double) {
        guard !busyRecording else { return }
        elapsed = min(max(value, 0), progressDuration); mode = .paused
        if let segment=currentStep.segment,video.visible {sendVideo(seek:true,play:false,time:segment.start+elapsed/max(progressDuration,0.01)*segment.duration)}
    }
    func beginRecording(now: Double = CACurrentMediaTime()) {
        guard immersive, placed, workspaceVisible, !busyRecording, capture.ready, !saving, unsaved == nil else { return }
        let live = capture.snapshot(at: now)
        guard live.left != nil || live.right != nil else {
            status = "Bring at least one hand into view before recording."; return
        }
        pauseVideo();recordingContext=(course.id,step,currentStep.title)
        frames.removeAll(keepingCapacity: true); elapsed = 0; countdown = 3
        started = now + 3; lastCapture = 0; mode = .countdown
        status = "Get your hands ready. Recording starts after the countdown."
    }
    func cancelCountdown() { mode = .idle; status = "Recording cancelled." }
    func finishRecording() {
        guard mode == .recording else { return }
        mode = .paused
        guard frames.count >= 2, frames.contains(where: { $0.left != nil || $0.right != nil }) else {
            status = "No usable hands were captured. Keep hands in view and try again."; return
        }
        let name = recordingName.trimmingCharacters(in: .whitespacesAndNewlines)
        let clip = MotionClip(title: name.isEmpty ? (recordingContext?.title ?? currentStep.title) : name, lessonStep: recordingContext?.step ?? step, paperSide: paperSide, paperHeight: paperHeight, lessonID: recordingContext?.lessonID ?? course.id, frames: frames)
        selected = clip; unsaved = clip; elapsed = 0
        savePending()
    }
    func savePending() {
        guard let clip = unsaved, !saving else { return }
        saving = true
        let directory = storage
        Task {
            do {
                try await Task.detached { try ClipStorage.save(clip, in: directory) }.value
                clips.insert(clip, at: 0); unsaved = nil; savedMessage = "Saved \(clip.title)"
                status = "Saved on this device · \(Int(clip.trackedFraction * 100))% of frames contain tracked hands."
            } catch { self.error = "Could not save: \(error.localizedDescription). Your take is still in memory; use Retry save." }
            saving = false
        }
    }
    var hasUnsaved: Bool { unsaved != nil }

    func confirmPlacement() {
        guard immersive, !placed, placementReady, !busyRecording else { return }
        placed = true; fingerPlacement = false; calibration.reset()
        paperSide = LetterPaper.width; paperHeight = LetterPaper.height
        setStep(step); tab = .learn; showGuides = true
        status = "Workspace placed. Follow the lesson, or record a demonstration."
        lockWorkspace()
    }
    func lockWorkspace() {
        workspaceLock.reset(workspace);trackingIssue=nil;capture.anchorWorkspace(workspace)
    }
    func finishAdjustment() {guard placed,adjustingPlacement else{return};adjustingPlacement=false;lockWorkspace()}
    func rotateWorkspace(_ delta:Float) {guard placed,adjustingPlacement,!busyRecording,delta.isFinite,abs(delta)<=Float.pi/12 else{return};yaw += delta}
    private func suspendForTracking() {
        if mode == .recording {finishRecording()} else if mode == .countdown {cancelCountdown()}
        pauseVideo();mode = .paused;cuePlacement=nil
        onRender?(nil,capture.snapshot(at:CACurrentMediaTime()),0)
    }
    func receiveWorkspaceAnchor(_ transform:simd_float4x4?,tracked:Bool) {
        guard immersive,placed,!adjustingPlacement else{return}
        guard tracked,let transform else {
            trackingIssue="Table tracking paused. Look at the table in good light. If it does not recover, choose Place Again."
            suspendForTracking();return
        }
        guard workspaceLock.accepts(transform) else {
            trackingIssue="A large tracking change was detected. The workspace is hidden to prevent a jump. Place it again on the table."
            suspendForTracking();return
        }
        position=[transform.columns.3.x,transform.columns.3.y,transform.columns.3.z]
        yaw=atan2(transform.columns.2.x,transform.columns.2.z)
        trackingIssue=nil
    }
    func beginCuePlacement(_ target:String) {
        guard placed,!busyRecording else{return};pauseVideo();mode = .paused
        cuePlacement=target;cueCalibration.reset();cueApproach=nil;cueApproached=false
        status="Lift your RIGHT index, move it to the arrow \(target), then hold still for two seconds."
    }
    private func saveCues() {
        do {let url=storage.deletingLastPathComponent().appendingPathComponent("GhostHandsCues.json");try FileManager.default.createDirectory(at:url.deletingLastPathComponent(),withIntermediateDirectories:true);try JSONEncoder().encode(cueOverrides).write(to:url,options:.atomic)} catch {self.error="Could not save spatial cues: \(error.localizedDescription)"}
    }
    func beginAuthoring(blank:Bool) {
        guard !busyRecording,!hasUnsaved else{return}
        pauseVideo();mode = .paused
        var copy=exportLesson;copy.id="lesson-"+UUID().uuidString.lowercased();copy.title=blank ? "My lesson" : course.title+" · My edition"
        if blank {copy.mechanicalModel=nil;copy.category="Custom";copy.object="My object";copy.preparation="Clear your workspace and gather the tools.";copy.tools=[];copy.spatialNote="Manually authored guidance.";copy.trayLabels=["Part 1","Part 2","Part 3","Part 4"];copy.steps=[.init(title:"First action",instruction:"Describe the action to perform.",check:"Describe the finished result.",cue:.init(label:"Target",from:[0,0.01,0],to:[0,0.08,0]))]}
        draft=copy;isAuthoring=true;step=0;selected=nil;sendVideo(seek:true,play:false)
    }
    var exportLesson:LessonDefinition {
        var result=course
        for i in result.steps.indices {if let cue=cueOverrides[result.id+"/"+result.steps[i].id] {result.steps[i].cue=cue}}
        return result
    }
    func saveDraft() {
        guard draft != nil,!busyRecording,!hasUnsaved else{return}
        let draft=exportLesson
        do {try LessonStorage.save(draft,in:storage.deletingLastPathComponent().appendingPathComponent("GhostHandsLessons"));customLessons.removeAll{$0.id==draft.id};customLessons.append(draft);activeLessonID=draft.id;self.draft=nil;isAuthoring=false;setStep(0);status="Lesson saved on this device."} catch {self.error=error.localizedDescription}
    }
    func cancelDraft() {
        if mode == .recording {finishRecording()} else if mode == .countdown {cancelCountdown()}
        draft=nil;isAuthoring=false;cuePlacement=nil;setStep(0)
    }
    func tick(now: Double = CACurrentMediaTime()) {
        let dt = previousTick == 0 ? 0 : min(now - previousTick, 0.1)
        previousTick = now
        let live = capture.snapshot(at: now)
        guard interactionActive else { return }
        if trackingIssue != nil {onRender?(nil,live,0);return}
        if fingerPlacement && !placed {
            let gap:Float? = {
                guard let thumb=live.left?.joints[4],let index=live.left?.joints[9] else{return nil}
                return simd_distance(thumb,index)
            }()
            if !approachedTable,let tip=live.right?.joints[9] {
                if approachOrigin == nil {approachOrigin=tip}
                if let thumb=live.right?.joints[4],simd_distance(thumb,tip)>0.035,simd_distance(tip,approachOrigin!)>0.05 {approachedTable=true;calibration.reset()}
            }
            let head=capture.headTransform(),wasReady=calibration.ready
            let commit=calibration.update(rightTip:approachedTable && head != nil ? live.right?.joints[9] : nil,leftGap:gap,now:now,automatic:true)
            placementProgress=calibration.progress
            placementReady=calibration.ready
            if let tip=calibration.candidate {
                position=tip+SIMD3<Float>(0,0.002,0)
                if !wasReady && !commit, let head {
                    let direction=SIMD3<Float>(position.x-head.columns.3.x,0,position.z-head.columns.3.z)
                    if simd_length(direction)>0.1 {yaw=atan2(-direction.x,-direction.z)}
                }
                placementHint=placementReady ? "Keep your right fingertip touching the table. Placing…" : "Touch the table with your right index and hold it still."
            } else {placementHint=live.right == nil ? "Right index not visible. Keep your hand in view." : "Open your right hand. Lift your index, then move it down to touch the table center."}
            if commit {confirmPlacement()}
        }
        if let target=cuePlacement {
            if !cueApproached,let tip=live.right?.joints[9] {
                if cueApproach==nil {cueApproach=tip}
                if let thumb=live.right?.joints[4],simd_distance(thumb,tip)>0.035,simd_distance(tip,cueApproach!)>0.05 {cueApproached=true}
            }
            if cueCalibration.update(rightTip:cueApproached ? live.right?.joints[9] : nil,leftGap:nil,now:now,automatic:true),let tip=cueCalibration.candidate {
                let local=simd_inverse(workspace)*SIMD4(tip,1)
                var cue=spatialCue ?? .init(label:"Target",from:[0,0.01,0],to:[0,0.08,0])
                if target=="start" {cue.from=[local.x,local.y,local.z]} else {cue.to=[local.x,local.y,local.z]}
                if cue.isValid {cueOverrides[cueKey]=cue;saveCues();status="Spatial cue placed."}
                cuePlacement=nil
            }
        }
        let count = (live.left == nil ? 0 : 1) + (live.right == nil ? 0 : 1)
        if count != trackedHands { trackedHands = count }
        if mode == .countdown {
            if !capture.ready { cancelCountdown(); status = "Tracking interrupted. Reopen the studio and try again." }
            else if now < started { countdown = max(1, Int(ceil(started - now))) }
            else { mode = .recording; started = now; status = "Recording · lost hands leave a gap, not a guessed pose." }
        }
        if mode == .recording {
            elapsed = now - started
            if !capture.ready { finishRecording(); status = "Tracking stopped. The captured portion was kept." }
            else if now - lastCapture >= 1.0 / 30 {
                let inverse = simd_inverse(workspace)
                frames.append(MotionFrame(time: elapsed, left: live.left?.transformed(by: inverse), right: live.right?.transformed(by: inverse)))
                lastCapture = now
                if elapsed >= secondsToRecord { finishRecording() }
            }
        } else if mode == .playing, !linkedVideo {
            elapsed += dt * speed
            if elapsed >= progressDuration {
                if loops, progressDuration > 0 { elapsed.formTruncatingRemainder(dividingBy: progressDuration) }
                else { elapsed = progressDuration; mode = .paused }
            }
        }
        if [.brake,.pump].contains(course.mechanicalModel),mode == .playing,!explodedView {
            let target:Float=mechanismEngaged ? 1 : 0
            mechanismBlend += (target-mechanismBlend)*min(1,Float(max(0,dt))*7)
            mechanismAngle += Float(max(0,dt)*speed)*4*(1-mechanismBlend)
        }
        let frame = busyRecording || currentStep.staticPaper ? nil : selected?.sample(at: elapsed)
        onRender?(frame, live, Float(elapsed / max(selected?.duration ?? 1, 0.01)))
    }
}
