import Foundation
import Observation
import QuartzCore
import simd

enum StudioTab: String, CaseIterable { case settings = "Settings", learn = "Learn", record = "Record", library = "Library", placement = "Place", video = "Video" }
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
    var step = 0
    var clips: [MotionClip] = []
    var selected: MotionClip?
    var elapsed = 0.0
    var speed = 0.75
    var loops = false
    var showGuides = true
    var showHands = true
    var adjustingPlacement = false
    var placementProgress: Float = 0
    var avatarEnabled = false
    var avatarStatus = "Off"
    var avatarTableHeight: Float = 0.8
    var automaticVideo = true
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
        let result = ClipStorage.load(in: self.storage)
        clips = result.clips
        if result.failures > 0 { error = "\(result.failures) unreadable recording(s) were left untouched in storage." }
    }
    var busyRecording: Bool { mode == .recording || mode == .countdown }
    var workspace: simd_float4x4 {
        var matrix = simd_float4x4(simd_quatf(angle: yaw, axis: [0,1,0]))
        matrix.columns.3 = SIMD4(position, 1)
        return matrix
    }
    var lesson: PaperStep { PaperStep.all[step] }
    var sourceLabel: String { selected?.isIllustration == false ? "Recorded hands" : "Illustrated motion · not a recording" }

    func entered() async {
        immersive = true; interactionActive = true; previousTick = 0; placed = false
        status = "Use Place to align the outline with your paper."
        beginPlacement()
        await capture.start()
        guard !Task.isCancelled, immersive else { return }
    }
    func leftStudio() {
        if mode == .recording { finishRecording() }
        mode = .paused; immersive = false; transitioning = false
        onRender = nil; capture.stop()
    }
    func suspend() {
        if mode == .recording { finishRecording() }
        mode = .paused; calibration.reset(); interactionActive=false; capture.clear()
        placementReady = false
    }
    func beginPlacement() {
        guard !busyRecording else { return }
        mode = .paused; placed = false; placementReady = false
        fingerPlacement = false; calibration.reset(); placementReady = false; placementProgress=0;adjustingPlacement=false
        placed = false; tab = .placement
        placementHint = "Rest your right index on the paper center and hold it still."
        status = "Rest your right index on the paper center. Open your left hand, then pinch left to lock the table."
    }
    func startFingerPlacement() {
        guard immersive,!placed else{return}
        calibration.reset();fingerPlacement=true;placementProgress=0;approachOrigin=nil;approachedTable=false
        placementHint="Rest your RIGHT index fingertip in the center of the clear spot. Hold still for two seconds."
    }
    func beginAdjustment() {
        guard placed,!busyRecording else{return}
        mode = .paused;adjustingPlacement=true
    }
    func move(_ delta: SIMD3<Float>) {
        guard !busyRecording else { return }
        position += simd_act(simd_quatf(angle: yaw, axis: [0,1,0]), delta)
    }
    func resizePaper(_ size: Float) {
        guard !busyRecording else { return }
        paperSide = size
        selected = IllustratedMotion.clip(step: step, side: size)
        elapsed = 0; mode = .paused
        status = "Guide resized. Recorded takes keep the paper size they were captured with."
    }
    func setStep(_ index: Int) {
        guard !busyRecording else { return }
        step = min(max(index, 0), PaperStep.all.count - 1)
        paperSide = LetterPaper.width; paperHeight = LetterPaper.height; showGuides = true
        selected = IllustratedMotion.clip(step: step, side: paperSide)
        elapsed = 0; previousTick = 0; mode = immersive && placed ? .playing : .paused
    }
    func load(_ clip: MotionClip) {
        guard !busyRecording else { return }
        selected = clip; elapsed = 0; paperSide = clip.paperSide; paperHeight = clip.paperHeight ?? clip.paperSide
        if clip.lessonID == "letter-boat-guided-v3", let step = clip.lessonStep { self.step = min(step, PaperStep.all.count - 1) }
        showGuides = clip.lessonID == "letter-boat-guided-v3"
        mode = immersive && placed ? .playing : .paused; previousTick = 0; tab = .learn
    }
    func playPause() {
        guard immersive, placed, !busyRecording else { return }
        if mode == .playing { mode = .paused; return }
        if selected == nil { setStep(step) }
        if elapsed >= (selected?.duration ?? 0) { elapsed = 0 }
        mode = .playing
    }
    func resumeInteraction() { interactionActive=true;previousTick=0;calibration.reset() }
    func replayCurrent() {
        guard immersive,placed,!busyRecording else{return}
        elapsed=0;previousTick=0;mode = .playing
    }
    func seek(_ value: Double) {
        guard !busyRecording else { return }
        elapsed = min(max(value, 0), selected?.duration ?? 0); mode = .paused
    }
    func beginRecording(now: Double = CACurrentMediaTime()) {
        guard immersive, placed, !busyRecording, capture.ready, !saving, unsaved == nil else { return }
        let live = capture.snapshot(at: now)
        guard live.left != nil || live.right != nil else {
            status = "Bring at least one hand into view before recording."; return
        }
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
        let clip = MotionClip(title: name.isEmpty ? lesson.title : name, lessonStep: step, paperSide: paperSide, paperHeight: paperHeight, lessonID: "letter-boat-guided-v3", frames: frames)
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
        status = "Letter paper placed. Record a fold or play the illustrated guide."
    }
    func tick(now: Double = CACurrentMediaTime()) {
        let dt = previousTick == 0 ? 0 : min(now - previousTick, 0.1)
        previousTick = now
        let live = capture.snapshot(at: now)
        guard interactionActive else { return }
        if fingerPlacement && !placed {
            let gap:Float? = {
                guard let thumb=live.left?.joints[4],let index=live.left?.joints[9] else{return nil}
                return simd_distance(thumb,index)
            }()
            if !approachedTable,let tip=live.right?.joints[9] {
                if approachOrigin == nil {approachOrigin=tip}
                if let thumb=live.right?.joints[4],simd_distance(thumb,tip)>0.035,simd_distance(tip,approachOrigin!)>0.05 {approachedTable=true;calibration.reset()}
            }
            let commit=calibration.update(rightTip:approachedTable ? live.right?.joints[9] : nil,leftGap:gap,now:now,automatic:true)
            placementProgress=calibration.progress
            placementReady=calibration.ready
            if let tip=calibration.candidate {
                position=tip-SIMD3<Float>(0,0.008,0)
                if !calibration.isCommitting && !commit, let head=capture.headTransform() {
                    let direction=SIMD3<Float>(position.x-head.columns.3.x,0,position.z-head.columns.3.z)
                    if simd_length(direction)>0.1 {yaw=atan2(-direction.x,-direction.z)}
                }
                placementHint=placementReady ? "Keep your right fingertip touching the table. Placing…" : "Touch the table with your right index and hold it still."
            } else {placementHint=live.right == nil ? "Right index not visible. Keep your hand in view." : "Open your right hand. Lift your index, then move it down to touch the table center."}
            if commit {confirmPlacement()}
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
        } else if mode == .playing, let selected {
            elapsed += dt * speed
            if elapsed >= selected.duration {
                if loops, selected.duration > 0 { elapsed.formTruncatingRemainder(dividingBy: selected.duration) }
                else { elapsed = selected.duration; mode = .paused }
            }
        }
        let frame = busyRecording ? nil : selected?.sample(at: elapsed)
        onRender?(frame, live, Float(elapsed / max(selected?.duration ?? 1, 0.01)))
    }
}
