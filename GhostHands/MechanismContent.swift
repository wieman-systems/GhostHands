import Foundation
import simd

/// Geometric teaching models; no force, load or failure simulation.
enum MechanismMotion {
    static let crankRadius:Float=0.04
    static let rodLength:Float=0.15
    static func crank(_ angle:Float)->(pin:SIMD3<Float>,slider:SIMD3<Float>) {
        let pin=SIMD3<Float>(crankRadius*cos(angle),crankRadius*sin(angle),0)
        return (pin,[pin.x+sqrt(max(0,rodLength*rodLength-pin.y*pin.y)),0,0])
    }
    static func camTop(_ angle:Float)->Float {0.045+0.012*sin(angle)}
    static let smallRadius:Float=0.035,largeRadius:Float=0.070,spacing:Float=0.19
    static var tangentAngle:Float {acos((smallRadius-largeRadius)/spacing)}
    static var straightLength:Float {sqrt(spacing*spacing-pow(largeRadius-smallRadius,2))}
    static var beltLength:Float {2*straightLength+2*tangentAngle*largeRadius+(2*Float.pi-2*tangentAngle)*smallRadius}
    static func beltPoint(_ fraction:Float)->SIMD3<Float> {
        let a=tangentAngle,r=smallRadius,R=largeRadius,d=spacing
        let left=SIMD3<Float>(-d/2,0,0),right=SIMD3<Float>(d/2,0,0)
        let n=SIMD3<Float>(cos(a),sin(a),0),down=SIMD3<Float>(cos(a),-sin(a),0)
        var distance=(fraction-floor(fraction))*beltLength
        if distance<straightLength {return left+n*r+(right+n*R-left-n*r)*(distance/straightLength)}
        distance -= straightLength
        if distance<2*a*R {let angle=a-distance/R;return right+[R*cos(angle),R*sin(angle),0]}
        distance -= 2*a*R
        if distance<straightLength {return right+down*R+(left+down*r-right-down*R)*(distance/straightLength)}
        distance -= straightLength
        let angle = -a-distance/r
        return left+[r*cos(angle),r*sin(angle),0]
    }
}
extension LessonCatalog {
    static let cam:LessonDefinition = .init(id:"cam-follower-lab",title:"Cam and follower",category:"Mechanisms",object:"Eccentric cam · flat follower",preparation:"Follow a rotating cam lifting a guided follower. Tap a part to identify it. Slow the animation and compare its highest and lowest positions.",tools:["Virtual mechanism"],videoURL:"https://www.youtube.com/watch?v=2u0VlFaJ0nE",attribution:"CAD CAM 23 · CAM & Follower Mechanism Explained in Seconds",sourceURL:"https://www.youtube.com/watch?v=2u0VlFaJ0nE",spatialNote:"Our eccentric circular cam demonstrates the same motion conversion; it is not an exact replica of the reference video's cam profile. Gravity/contact are prescribed, not simulated.",trayLabels:[],steps:[
        .init(id:"drive",title:"Rotation becomes lift",instruction:"The shaft turns the off-center circular cam. Its highest point rises and falls once each turn, lifting the flat follower above it.",check:"Find the shaft center and the cam's offset center."),
        .init(id:"contact",title:"Follow the contact",instruction:"Choose a slow speed. Watch the follower stay on top of the cam while its stem slides through the fixed guide. The guide prevents sideways movement.",check:"The stem moves vertically while the cam keeps rotating."),
        .init(id:"check",title:"Compare the travel",instruction:"Pause near the top and bottom of the cycle. The cam offset determines the follower's travel. The same principle appears in timing mechanisms and mechanical toys.",check:"Identify the cam, follower and guide with Parts.")
    ],mechanicalModel:.cam)
    static let belt:LessonDefinition = .init(id:"belt-drive-lab",title:"Belt and pulley drive",category:"Mechanisms",object:"Open belt · 2:1 pulley diameter ratio",preparation:"Watch one belt connect two pulleys. Compare their rotation rates and follow the direction markers. Tap a pulley or the belt to identify it.",tools:["Virtual mechanism"],videoURL:"https://www.youtube.com/watch?v=v5urs0gWF3U",attribution:"Jay Panchal · V-belt pulley drive motion animation",sourceURL:"https://www.youtube.com/watch?v=v5urs0gWF3U",spatialNote:"Illustrative open belt with ideal no-slip speed ratio. Moving markers indicate direction, not tracked material points. No belt tension or maintenance tolerances are simulated.",trayLabels:[],steps:[
        .init(id:"drive",title:"Follow the belt path",instruction:"The small pulley drives the large pulley through an open belt. Trace the upper straight run, the large pulley wrap, the lower run and the small pulley wrap.",check:"Both pulleys turn in the same direction."),
        .init(id:"ratio",title:"Two turns become one",instruction:"The large pulley has twice the diameter of the small one. With no slip, it makes one turn while the small pulley makes two. Use the bright witness spokes to count.",check:"One large-pulley turn matches two small-pulley turns."),
        .init(id:"check",title:"Inspect the drive",instruction:"Pause and rotate the model to see the pulley rims and shaft supports. In real machines, alignment, belt condition and tension matter; this model only explains the motion.",check:"Find both shafts and the two straight belt runs.")
    ],mechanicalModel:.belt)
    static let crank:LessonDefinition = .init(id:"crank-slider-lab",title:"Crank-slider linkage",category:"Mechanisms",object:"Rotating crank · rigid rod · sliding carriage",preparation:"Explore the linkage behind pistons and reciprocating machines. Tap its crank, rod or slider, then slow the motion to trace a full cycle.",tools:["Virtual mechanism"],videoURL:"https://www.youtube.com/watch?v=G6XZvkfiIng",attribution:"Ujjwal Suryakant Rane · Kinematics Ch01F Slider Crank Mechanism",sourceURL:"https://www.youtube.com/watch?v=G6XZvkfiIng",spatialNote:"Ideal rigid linkage with a fixed crank radius and rod length. Reference explains the same mechanism; no invented step timestamps or repair tolerances.",trayLabels:[],steps:[
        .init(id:"drive",title:"Trace the three moving parts",instruction:"The crank pin travels around a circle. The rigid connecting rod carries that movement to a slider constrained by two straight rails.",check:"The pin circles; the carriage travels only along the rails."),
        .init(id:"ends",title:"Find the two end positions",instruction:"Slow down and watch the crank line up with the rod. These are the ends of the slider's travel. One crank revolution produces one complete out-and-back stroke.",check:"The slider stroke is twice the crank radius."),
        .init(id:"check",title:"Compare motion through the cycle",instruction:"The crank turns steadily, but the slider changes speed and reverses direction. Scrub the animation and see how the rod tilts without changing length.",check:"Trace the crank pin, both rod ends and the slider guide.")
    ],mechanicalModel:.crank)
}
