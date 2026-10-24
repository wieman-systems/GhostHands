import Foundation
import simd

enum LabPart:String,CaseIterable,Identifiable {
    case fan,compressor,combustor,turbine,nozzle,driver,driven,bearing
    var id:String {rawValue}
    var title:String {switch self {case .fan:return "Fan";case .compressor:return "Compressor";case .combustor:return "Combustor";case .turbine:return "Turbine";case .nozzle:return "Nozzle";case .driver:return "Input gear";case .driven:return "Output gear";case .bearing:return "Bearings"}}
    var detail:String {switch self {case .fan:return "Splits incoming air into core and bypass paths.";case .compressor:return "Raises the pressure of core air.";case .combustor:return "Adds heat by burning fuel in the core flow.";case .turbine:return "Extracts power to turn the compressor and fan.";case .nozzle:return "Directs the exhaust out of the engine.";case .driver:return "The smaller gear drives the larger gear.";case .driven:return "Twice the teeth, half the rotational speed.";case .bearing:return "Supports the shaft while it rotates."}}
    static func available(for model:MechanicalModel?)->[Self] {model == .jet ? [.fan,.compressor,.combustor,.turbine,.nozzle] : model == .gearbox ? [.driver,.driven,.bearing] : []}
}
enum LabMotion {
    static func rotorAngle(seconds:Double,fast:Bool)->Float {Float(seconds * (fast ? 5 : 2) * Double.pi)}
    static func gearAngles(seconds:Double)->(Float,Float) {let a=Float(seconds * .pi);return(a,-a/2 + .pi/24)}
    static func flow(index:Int,count:Int,progress:Double,bypass:Bool)->SIMD3<Float> {
        let t=Float((Double(index)/Double(max(1,count))+progress*2).truncatingRemainder(dividingBy:1))
        let a=Float(index)*2.399963
        let radius:Float=bypass ? 0.056 : 0.018
        return [-0.16+t*0.36,0.10+cos(a)*radius,sin(a)*radius]
    }
}
extension LessonCatalog {
    static let jet:LessonDefinition = {
        func s(_ id:String,_ title:String,_ text:String,_ check:String)->LessonStep {.init(id:id,title:title,instruction:text,check:check)}
        return .init(id:"turbofan-lab",title:"Jet engine lab",category:"Aviation",object:"Twin-spool turbofan · animated cutaway",preparation:"Explore the engine beneath a miniature wing. Open Inspect to separate the modules or hide the casing. Follow core and bypass airflow, then try the blade-inspection exercise.",tools:["Virtual inspection model"],videoURL:"",attribution:"Concept reference: NASA Glenn",sourceURL:"https://www.grc.nasa.gov/www/k-12/airplane/Animation/turbtyp/etfh.html",spatialNote:"Illustrative teaching model; speeds and stage counts are simplified. Inspection exercises are not aircraft maintenance procedures.",trayLabels:[],steps:[
            s("overview","An engine beneath the wing","Follow air through the fan, compressor, combustor, turbine and nozzle. The surrounding path carries bypass air around the core.","Tap a stage to identify it. Inspect opens an exploded view."),
            s("fan","Fan and bypass","The large front fan feeds two paths. Some air enters the core; the rest flows around it through the bypass duct.","Find both streams of moving dots."),
            s("compressor","Compression stages","Rows of rotating blades and stationary vanes guide core air through the compressor. The high-pressure compressor shares a shaft with its turbine.","Compare the rotating rows with the fixed rows."),
            s("combustor","Combustion chamber","Fuel adds heat to the compressed core air. The pulsing shapes represent combustion inside the chamber; this simplified model does not calculate temperatures.","Bypass air stays outside the combustion chamber."),
            s("turbine","Two rotating spools","The hot flow turns turbine stages. One spool drives the core compressor; the other drives the fan. Watch their different illustrative rotation rates.","Trace the shafts through the center."),
            s("nozzle","Exhaust and thrust","The core exhaust leaves through the nozzle while bypass air leaves around it. These flows contribute to thrust.","Follow both streams beyond the back of the engine."),
            s("inspect","Inspect a stopped fan","Rotation is stopped for this exercise. One fan blade has a deliberately shortened tip. Look around the fan and tap the blade that differs from the others.","Use Inspect → Reveal defect if you need a hint. This is recognition practice, not a service decision.")
        ],mechanicalModel:.jet)
    }()
    static let gearbox:LessonDefinition = {
        func s(_ id:String,_ title:String,_ text:String,_ check:String)->LessonStep {.init(id:id,title:title,instruction:text,check:check)}
        return .init(id:"gearbox-lab",title:"Gearbox lab",category:"Mechanisms",object:"Two-gear drive · inspection model",preparation:"Watch a small input gear drive a larger output gear. Separate the cover and bearings with Inspect, then examine a damaged tooth.",tools:["Virtual inspection model"],videoURL:"",attribution:"Original teaching geometry",sourceURL:"",spatialNote:"Simplified spur gears. This is a teaching assembly, not a dimensioned service model.",trayLabels:[],steps:[
            s("overview","Follow the drive","The small input gear turns the larger output gear. These external gears turn in opposite directions.","Tap each gear to identify input and output."),
            s("ratio","Compare rotational speed","The output gear has twice as many teeth. Watch the input make two turns while the output makes one.","Use the speed menu to slow the motion."),
            s("bearings","Inspect the supports","Bearings support the rotating shafts. Use the exploded view to separate the supports and see how the gears sit between them.","Find the two shafts and their supports."),
            s("inspect","Find the damaged tooth","The drive is stopped. One tooth on the small gear is visibly shorter. Tap it to mark the finding.","Reveal defect offers a hint; recognizing a defect does not determine whether a real part is safe to use.")
        ],mechanicalModel:.gearbox)
    }()
}
