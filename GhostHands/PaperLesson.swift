import Foundation
import simd

enum PaperAction { case fold, unfold, flip, tidy, open, flatten, pull, finish }
struct PaperStep: Identifiable {
    let id: Int
    let title: String
    let instruction: String
    let check: String
    let action: PaperAction
    let from: SIMD2<Float>
    let to: SIMD2<Float>
    static let all: [PaperStep] = [
        .init(id:0,title:"Fold left to right",instruction:"Bring the left long edge to the right long edge. Match the corners, then press the fold.",check:"A half-width sheet.",action:.fold,from:[-1, 0],to:[1, 0]),
        .init(id:1,title:"Open the sheet again",instruction:"Unfold the flap you just made. Leave the center crease visible.",check:"A full Letter rectangle with a center line.",action:.unfold,from:[1, 0],to:[-1, 0]),
        .init(id:2,title:"Fold the top down",instruction:"Bring the far short edge to the near short edge. The center crease stays vertical.",check:"A wide rectangle; the closed edge is away from you.",action:.fold,from:[0, -1],to:[0, 1]),
        .init(id:3,title:"Fold the left corner",instruction:"Bring only the top-left corner to the center line. Its top edge lines up with that center crease.",check:"One triangle on the left. Leave the bottom strip free.",action:.fold,from:[-1, 0],to:[0, 0.773]),
        .init(id:4,title:"Fold the right corner",instruction:"Repeat with the top-right corner. The two folded edges meet in the middle.",check:"A pointed roof above a narrow rectangular strip.",action:.fold,from:[1, 0],to:[0, 0.773]),
        .init(id:5,title:"Lift the front strip",instruction:"Lift only the front layer of the bottom strip. Fold it upward along the base of the triangles.",check:"The front strip covers the bottom of the roof.",action:.fold,from:[0, 1],to:[0, 0.546]),
        .init(id:6,title:"Turn the model over",instruction:"Keep the point away from you. Turn the entire model over from left to right.",check:"The second, still-unfolded strip is facing you.",action:.flip,from:[-0.6, 0.45],to:[0.6, 0.45]),
        .init(id:7,title:"Lift the back strip",instruction:"Fold this remaining bottom strip upward along the same line.",check:"A paper hat, open at the bottom.",action:.fold,from:[0, 1],to:[0, 0.546]),
        .init(id:8,title:"Wrap the loose corners",instruction:"Fold each small protruding brim corner around the side of the hat. Keep the bottom opening free.",check:"The sides are tidy; you can still open the hat.",action:.tidy,from:[-1, 0.77],to:[-0.8, 0.65]),
        .init(id:9,title:"Open the hat",instruction:"Lift the hat slightly and hold it upright. Find the opening under its brim. Put your thumbs inside and separate the front and back layers. Keep the top closed.",check:"An open pocket. Keep it open for the next step.",action:.open,from:[0, 0.6],to:[0.6, 0.3]),
        .init(id:10,title:"Flatten into a diamond",instruction:"Keep the front and back layers separated. Push the LEFT and RIGHT corners toward each other; the opening widens in the other direction. Press the raised ridge down. Turn the flat square so an open corner faces you.",check:"A diamond with two separate lower tips.",action:.flatten,from:[-0.6, 0.3],to:[0, 0.65]),
        .init(id:11,title:"Lift the front lower tip",instruction:"Lift only the front lower tip to the top tip. Match the points and crease across the middle.",check:"One triangular flap; the back lower tip still points down.",action:.fold,from:[0, 0.65],to:[0, -0.65]),
        .init(id:12,title:"Turn the diamond over",instruction:"Turn the whole model over, keeping the top point away from you.",check:"The unfolded lower tip is now on top.",action:.flip,from:[-0.5, 0],to:[0.5, 0]),
        .init(id:13,title:"Lift the remaining tip",instruction:"Bring this lower tip to the top point. Crease it to match the other side.",check:"A smaller layered triangle, open underneath.",action:.fold,from:[0, 0.65],to:[0, -0.65]),
        .init(id:14,title:"Open the small triangle",instruction:"Lift the small triangle upright. Find the opening at the bottom, then separate its front and back layers with your thumbs.",check:"A second open pocket.",action:.open,from:[0, 0.4],to:[0.4, 0]),
        .init(id:15,title:"Flatten the small diamond",instruction:"Bring the outer corners together and flatten. Turn it so the two loose points are at the top.",check:"A small diamond with two loose upper tips.",action:.flatten,from:[-0.4, 0],to:[0, 0.4]),
        .init(id:16,title:"Pull the two tips apart",instruction:"Hold one loose upper tip in each hand. Pull left and right slowly; let the center rise by itself.",check:"A bow and stern, with a raised center between them.",action:.pull,from:[0, -0.4],to:[0.85, 0]),
        .init(id:17,title:"Open the hull",instruction:"Gently spread the bottom so the boat can stand. Sharpen the side creases without pushing down the center.",check:"The finished boat has an open hull and a raised center.",action:.finish,from:[-0.6, 0.15],to:[0.6, 0.15]),
    ]
    static let full: [SIMD2<Float>] = [[-1,1],[-1,-1],[1,-1],[1,1]]
    static let half: [SIMD2<Float>] = [[-1,1],[-1,0],[1,0],[1,1]]
    static let roof: [SIMD2<Float>] = [[-1,1],[-1,0.773],[0,0],[1,0.773],[1,1]]
    static let hat: [SIMD2<Float>] = [[-1,0.773],[0,0],[1,0.773]]
    static let diamond: [SIMD2<Float>] = [[0,0.65],[-0.65,0],[0,-0.65],[0.65,0]]
    static let smallDiamond: [SIMD2<Float>] = [[0,0.4],[-0.4,0],[0,-0.4],[0.4,0]]
    static let boat: [SIMD2<Float>] = [[-0.9,-0.15],[-0.55,0.3],[0.55,0.3],[0.9,-0.15],[0.3,-0.15],[0,-0.5],[-0.3,-0.15]]
    var outline: [SIMD2<Float>] {
        switch id {
        case 0,1,2:return Self.full
        case 3:return Self.half
        case 4:return [[-1,1],[-1,0.773],[0,0],[1,0],[1,1]]
        case 5,6,7:return Self.roof
        case 8,9,10:return Self.hat
        case 11,12,13:return Self.diamond
        case 14,15:return [[-0.65,0],[0,-0.65],[0.65,0]]
        case 16:return Self.smallDiamond
        default:return Self.boat
        }
    }
    var crease: (SIMD2<Float>,SIMD2<Float>) {
        switch id {
        case 0,1:return ([0,-1],[0,1])
        case 2:return ([-1,0],[1,0])
        case 3:return ([0,0],[-1,0.773])
        case 4:return ([0,0],[1,0.773])
        case 5,7:return ([-1,0.773],[1,0.773])
        default:return ([-0.65,0],[0.65,0])
        }
    }
    var opensPocket: Bool { [.open,.flatten,.pull,.finish].contains(action) }
    func phase(at seconds: Double) -> String {
        if seconds < 1.4 { return "START / Find the highlighted edge" }
        if seconds < 3.6 && action == .open {return "LIFT / Bring the flat model upright"}
        if seconds < 5.8 && action == .flatten {return "CLOSE / Bring side corners together; press down"}
        if seconds < 5.8 && action == .tidy {return seconds < 3.6 ? "WRAP / Left loose corner" : "WRAP / Right loose corner"}
        if seconds < 5.8 && action == .finish {return "SPREAD / Open the hull gently"}
        if seconds < 5.8 { return action == .flip ? "TURN / Move the whole model" : opensPocket ? "OPEN / Separate the layers" : "MOVE / Follow the paper flap" }
        return "FINISH / Match this shape, then choose Next"
    }
}

enum IllustratedMotion {
    static func progress(at seconds: Double) -> Float {
        let t=min(1,max(0,Float((seconds-1.4)/4.4)))
        return t*t*(3-2*t)
    }
    static func clip(step: Int, side: Float) -> MotionClip {
        let lesson=PaperStep.all[min(step,PaperStep.all.count-1)]
        let frames: [MotionFrame]=(0...240).map {i in
            let time=Double(i)/30, t=progress(at:Double(i)/30)
            let moving=PaperMotion.contact(step:lesson,progress:t,width:side)+SIMD3<Float>(0,0.012,0)
            let useBoth = [2,5,7].contains(lesson.id)
            let movingLeft = lesson.from.x < -0.1 && !lesson.opensPocket && lesson.action != .flip
            let spread: Float = 0.03 + 0.055*t
            let leftPoint: SIMD3<Float>
            let rightPoint: SIMD3<Float>
            if let contacts=PaperMotion.handContacts(step:lesson,progress:t,width:side) {
                leftPoint=contacts.0;rightPoint=contacts.1
            } else if lesson.opensPocket {
                leftPoint = [-spread,moving.y,moving.z-0.015*t]
                rightPoint = [spread,moving.y,moving.z+0.015*t]
            } else if useBoth {
                leftPoint = moving+SIMD3(-0.06,0,0); rightPoint = moving+SIMD3(0.06,0,0)
            } else {
                leftPoint = movingLeft ? moving : ([11,13].contains(lesson.id) ? SIMD3(-0.03,0.012,-0.025) : SIMD3(-0.065,0.012,0.06))
                rightPoint = movingLeft ? SIMD3(0.065,0.012,0.06) : moving
            }
            return MotionFrame(time:time,left:hand(at:leftPoint,left:true,curl:0.12),right:hand(at:rightPoint,left:false,curl:0.12))
        }
        return MotionClip(title:"Illustration · \(lesson.title)",lessonStep:step,paperSide:side,paperHeight:LetterPaper.height,lessonID:"letter-boat-guided-v3",isIllustration:true,frames:frames)
    }
    // Articulated, anatomically proportioned example; not a captured expert.
    static func hand(at tip: SIMD3<Float>, left: Bool, curl: Float) -> HandPose {
        let sign: Float = left ? -1 : 1
        let wrist = tip + SIMD3<Float>(0.024*sign,0.025,0.165)
        var joints: [SIMD3<Float>?] = [wrist]
        let thumb: [SIMD3<Float>] = [[-0.023*sign,0.004,-0.029],[-0.041*sign,-0.003,-0.054],[-0.046*sign,-0.012,-0.076],[-0.038*sign,-0.023,-0.098]]
        joints += thumb.map { wrist+$0 }
        for finger in 0..<4 {
            let x: Float = [-0.024,-0.003,0.018,0.036][finger]*sign
            let palm: Float = [0.073,0.080,0.075,0.063][finger]
            let lengths: [Float] = [[0.038,0.024,0.018],[0.042,0.027,0.020],[0.039,0.025,0.018],[0.031,0.019,0.016]][finger]
            joints.append(wrist+SIMD3(x*0.45,0,-0.028))
            var point=wrist+SIMD3(x,-0.004,-palm); joints.append(point)
            for bone in 0..<3 {
                let angle=curl*Float(bone+1)*0.55
                point += SIMD3(0,-sin(angle)*lengths[bone],-cos(angle)*lengths[bone]); joints.append(point)
            }
        }
        // Make the visible index fingertip the actual demonstration contact point.
        let delta=tip-joints[9]!
        return HandPose(joints:joints.map { $0.map { $0+delta } })
    }
}
