import Foundation
import simd

enum EnginePart:String,CaseIterable,Identifiable {
    case piston,rod,crank,inlet,exhaust,plug
    var id:String {rawValue}
    var title:String {switch self {case .piston:return "Piston";case .rod:return "Connecting rod";case .crank:return "Crankshaft";case .inlet:return "Inlet valve";case .exhaust:return "Exhaust valve";case .plug:return "Spark plug"}}
    var detail:String {switch self {case .piston:return "Moves inside the cylinder.";case .rod:return "Links the piston to the crank.";case .crank:return "Turns the piston's motion into rotation.";case .inlet:return "Opens to admit fresh charge.";case .exhaust:return "Opens to release spent gas.";case .plug:return "Starts combustion with a spark."}}
}
struct EnginePose {
    let angle:Float
    let stroke:Int
    let progress:Float
    let pin:SIMD3<Float>
    let piston:SIMD3<Float>
    var inletOpen:Bool {stroke==0 && progress>0.03 && progress<0.97}
    var exhaustOpen:Bool {stroke==3 && progress>0.03 && progress<0.97}
    var spark:Bool {stroke==2 && progress<0.14}
}
enum EngineCycle {
    static let radius:Float=0.027
    static let rodLength:Float=0.075
    static let crankHeight:Float=0.045
    static func pose(stepID:String,progress:Double)->EnginePose {
        let p=Float(min(1,max(0,progress.isFinite ? progress : 0)))
        let phase:[String:Int]=["intake":0,"compression":1,"power":2,"exhaust":3]
        let phasePosition:Float
        if let stroke=phase[stepID] {phasePosition=Float(stroke)+p}
        else {phasePosition=p*4}
        let angle=phasePosition * .pi
        // At an action's endpoint retain that stroke, instead of briefly showing the next valve state.
        let stroke=phase[stepID] ?? min(3,Int(phasePosition))
        let local=phase[stepID] != nil ? p : min(1,phasePosition-Float(stroke))
        let pin=SIMD3<Float>(radius*sin(angle),crankHeight+radius*cos(angle),0)
        let piston=SIMD3<Float>(0,pin.y+sqrt(max(0,rodLength*rodLength-pin.x*pin.x)),0)
        return .init(angle:angle,stroke:stroke,progress:local,pin:pin,piston:piston)
    }
}
