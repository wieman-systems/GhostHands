import Foundation
import simd

// All positions are meters in the paper workspace: +X right, +Y up, -Z away.
// Joint order is fixed in the file format, independent of ARKit enumeration order.
enum HandLayout {
    static let names = ["wrist", "thumbKnuckle", "thumbIntermediateBase", "thumbIntermediateTip", "thumbTip",
        "indexFingerMetacarpal", "indexFingerKnuckle", "indexFingerIntermediateBase", "indexFingerIntermediateTip", "indexFingerTip",
        "middleFingerMetacarpal", "middleFingerKnuckle", "middleFingerIntermediateBase", "middleFingerIntermediateTip", "middleFingerTip",
        "ringFingerMetacarpal", "ringFingerKnuckle", "ringFingerIntermediateBase", "ringFingerIntermediateTip", "ringFingerTip",
        "littleFingerMetacarpal", "littleFingerKnuckle", "littleFingerIntermediateBase", "littleFingerIntermediateTip", "littleFingerTip"]
    static let bones: [(Int, Int)] = [(0,1),(1,2),(2,3),(3,4), (0,5),(5,6),(6,7),(7,8),(8,9),
        (0,10),(10,11),(11,12),(12,13),(13,14), (0,15),(15,16),(16,17),(17,18),(18,19),
        (0,20),(20,21),(21,22),(22,23),(23,24), (6,11),(11,16),(16,21)]
}

struct HandPose: Codable, Equatable {
    var joints: [SIMD3<Float>?]
    var isUsable: Bool { joints.count == HandLayout.names.count && joints[0] != nil }
    func transformed(by matrix: simd_float4x4) -> HandPose {
        HandPose(joints: joints.map { point in
            guard let p = point else { return nil }
            let q = matrix * SIMD4(p, 1)
            let result = SIMD3(q.x, q.y, q.z)
            return result.isFinite ? result : nil
        })
    }
    static func interpolate(_ a: HandPose?, _ b: HandPose?, fraction: Float) -> HandPose? {
        guard let a, let b, a.isUsable, b.isUsable else { return nil }
        return HandPose(joints: zip(a.joints, b.joints).map { p, q in
            guard let p, let q else { return nil }
            return p + (q - p) * fraction
        })
    }
}

struct MotionFrame: Codable, Equatable {
    var time: Double
    var left: HandPose?
    var right: HandPose?
}

struct MotionClip: Codable, Identifiable, Equatable {
    var version = 1
    var id = UUID()
    var title: String
    var createdAt = Date()
    var lessonStep: Int?
    var paperSide: Float = 0.20
    var paperHeight: Float?
    var lessonID: String?
    var isIllustration = false
    var frames: [MotionFrame]
    var duration: Double { frames.last?.time ?? 0 }
    var trackedFraction: Double {
        guard !frames.isEmpty else { return 0 }
        return Double(frames.filter { $0.left != nil || $0.right != nil }.count) / Double(frames.count)
    }
    func validated() throws -> MotionClip {
        guard version == 1, !frames.isEmpty, frames.count <= 6000,
              paperSide.isFinite, (0.05...0.5).contains(paperSide),
              paperHeight == nil || (paperHeight!.isFinite && (0.05...0.5).contains(paperHeight!)), duration <= 180,
              lessonStep == nil || (0..<max(9, PaperStep.all.count)).contains(lessonStep!) else { throw MotionError.invalid }
        var last = -Double.infinity
        for frame in frames {
            guard frame.time.isFinite, frame.time >= 0, frame.time > last else { throw MotionError.invalid }
            last = frame.time
            for pose in [frame.left, frame.right].compactMap({ $0 }) {
                guard pose.isUsable, pose.joints.allSatisfy({ $0 == nil || ($0!.isFinite && simd_length($0!) < 5) }) else { throw MotionError.invalid }
            }
        }
        return self
    }
    func sample(at time: Double) -> MotionFrame {
        let empty = MotionFrame(time: time, left: nil, right: nil)
        guard !frames.isEmpty, time.isFinite else { return empty }
        if time <= frames[0].time { return frames[0] }
        if time >= duration { return frames[frames.count - 1] }
        var lo = 0, hi = frames.count - 1
        while hi - lo > 1 {
            let mid = (lo + hi) / 2
            if frames[mid].time <= time { lo = mid } else { hi = mid }
        }
        let a = frames[lo], b = frames[hi]
        if abs(time - a.time) < 0.000001 { return a }
        // Never bridge dropped capture intervals or a hand disappearing.
        guard b.time - a.time <= 0.15 else { return empty }
        let t = Float((time - a.time) / (b.time - a.time))
        return MotionFrame(time: time, left: HandPose.interpolate(a.left, b.left, fraction: t),
                           right: HandPose.interpolate(a.right, b.right, fraction: t))
    }
}

enum MotionError: LocalizedError {
    case invalid
    var errorDescription: String? { "This recording has an unsupported format or invalid motion data." }
}

struct TimedHand {
    var time: Double
    var pose: HandPose
    func fresh(at now: Double) -> HandPose? {
        guard now >= time, now - time <= 0.18, pose.isUsable else { return nil }
        return pose
    }
}

extension SIMD3 where Scalar == Float {
    var isFinite: Bool { x.isFinite && y.isFinite && z.isFinite }
}

enum ClipStorage {
    static func save(_ clip: MotionClip, in directory: URL) throws {
        _ = try clip.validated()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(clip).write(to: directory.appendingPathComponent(clip.id.uuidString + ".json"), options: .atomic)
    }
    static func load(in directory: URL) -> (clips: [MotionClip], failures: Int) {
        guard let urls = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return ([], 0) }
        var clips: [MotionClip] = [], failures = 0
        for url in urls where url.pathExtension == "json" {
            do { clips.append(try JSONDecoder().decode(MotionClip.self, from: Data(contentsOf: url)).validated()) }
            catch { failures += 1 }
        }
        return (clips.sorted { $0.createdAt > $1.createdAt }, failures)
    }
}
