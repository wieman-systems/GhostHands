import Foundation
import simd

struct VideoSegment: Codable, Equatable {
    var start: Double
    var end: Double
    var duration: Double { end-start }
    var isValid: Bool {start.isFinite && end.isFinite && start >= 0 && end > start+0.25 && end <= 86400}
    func progress(at time:Double)->Double {min(1,max(0,(time-start)/max(duration,0.01)))}
}
struct SpatialCue: Codable, Equatable {
    var label: String
    var from: [Float]
    var to: [Float]
    var isValid:Bool { !label.isEmpty && label.count <= 120 && [from,to].allSatisfy{$0.count==3 && $0.allSatisfy{$0.isFinite && abs($0)<=2}} }
}
struct LessonStep: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var title: String
    var instruction: String
    var check: String
    var segment: VideoSegment?
    var paperIndex: Int?
    var staticPaper: Bool = false
    var cue: SpatialCue?
    var traySlot: Int?
    var reassembly: Bool = false
    var recordingID: UUID?
}
enum MechanicalModel:String,Codable {case engine,cabinFilter,jet,gearbox,brake,pump}

struct LessonDefinition: Codable, Identifiable, Equatable {
    var version = 1
    var id: String
    var title: String
    var category: String
    var object: String
    var preparation: String
    var tools: [String]
    var videoURL: String
    var attribution: String
    var sourceURL: String
    var spatialNote: String
    var trayLabels: [String]
    var steps: [LessonStep]
    var mechanicalModel:MechanicalModel?
    var hasVideo:Bool {YouTubeLink(videoURL) != nil}
    var isValid:Bool {
        version==1 && !id.isEmpty && id.range(of:"^[A-Za-z0-9_-]{1,100}$",options:.regularExpression) != nil && !title.isEmpty && title.count <= 200 && steps.count>0 && steps.count<=100 && Set(steps.map(\.id)).count==steps.count && trayLabels.count<=4 && (hasVideo || (videoURL.isEmpty && steps.allSatisfy{$0.segment==nil})) && steps.allSatisfy {
            !$0.title.isEmpty && !$0.instruction.isEmpty && $0.title.count<=200 && $0.instruction.count<=4000 && $0.check.count<=1000 && ($0.segment?.isValid ?? true) && ($0.paperIndex.map{PaperStep.all.indices.contains($0)} ?? true) && ($0.cue?.isValid ?? true) && ($0.traySlot.map{trayLabels.indices.contains($0)} ?? true)
        }
    }
    var isBoat:Bool {category == "Origami" && steps.contains{$0.paperIndex != nil}}
}
enum LessonCatalog {
    static let boat:LessonDefinition = {
        // Reviewed against EzOrigami's visible action sequence. Some actions are
        // deliberately split into smaller lessons; timings can be refined in Author.
        let order=[0,1,2,3,4,5,6,7,9,10,8,11,12,13,14,15,16,17]
        let ranges:[(Double,Double)]=[(20,31),(31,34),(34,53),(55,73),(73,88),(88,97),(97,101),(101,113),(114,123),(123,134),(134,150),(150,163),(163,166),(166,178),(179,187),(187,196),(196,207),(207,217)]
        let steps=order.enumerated().map {index,paperIndex -> LessonStep in
            let p=PaperStep.all[paperIndex]
            return LessonStep(id:"boat-\(paperIndex)",title:paperIndex==8 ? "Tidy the diamond edges" : p.title,instruction:paperIndex==8 ? "Keep the diamond flat. Tuck the small projecting brim corners around its edges, following the video. Leave the lower layers separate." : p.instruction,check:paperIndex==8 ? "A tidy diamond with two separate lower tips." : p.check,segment:.init(start:ranges[index].0,end:ranges[index].1),paperIndex:paperIndex==8 ? 10 : paperIndex,staticPaper:paperIndex==8)
        }
        return .init(id:"letter-boat-video-v1",title:"Paper boat",category:"Origami",object:"US Letter paper · 8½ × 11 in",preparation:"Clear a large table. Use one rectangular Letter sheet. The video sometimes turns the sheet; keep the ghost outline as your workspace orientation.",tools:["One US Letter sheet"],videoURL:"https://www.youtube.com/watch?v=vNba3jbBSOw",attribution:"EzOrigami · How to Make a Paper Boat",sourceURL:"https://www.youtube.com/watch?v=vNba3jbBSOw",spatialNote:"Authored paper illustration; video timing stretches its movement across each segment. Hands are illustrative, not extracted from the video.",trayLabels:[],steps:steps)
    }()
    static let repair:LessonDefinition = {
        func s(_ id:String,_ title:String,_ instruction:String,_ check:String,_ start:Double,_ end:Double,_ label:String,_ from:[Float],_ to:[Float],_ slot:Int?=nil,_ assembly:Bool=false)->LessonStep {
            .init(id:id,title:title,instruction:instruction,check:check,segment:.init(start:start,end:end),cue:.init(label:label,from:from,to:to),traySlot:slot,reassembly:assembly)
        }
        return .init(id:"corolla-2018-cabin-filter",title:"Cabin air filter",category:"Car maintenance",object:"2018 Toyota Corolla · glove-box access",preparation:"Park the vehicle and switch it off. Confirm the glove-box layout and replacement filter match the video and your owner's manual. Start with a tabletop rehearsal; spatial arrows are manually placed cues, not a scan of your car.",tools:["Correct replacement cabin filter","Clear parts space"],videoURL:"https://www.youtube.com/watch?v=LFA9g7GdXbQ",attribution:"Filterheads · 2018 Corolla · AQ1102C",sourceURL:"https://www.youtube.com/watch?v=LFA9g7GdXbQ",spatialNote:"Tabletop rehearsal. Set each cue with your fingertip on the matching component before using it on a real object. No automatic part recognition or fit verification.",trayLabels:["Filter cover","Old filter","New filter","Spare parts"],steps:[
            s("open","Open the glove box","Empty and open the glove box. In tabletop rehearsal, use a box and lid as the housing and cover.","The glove box is supported and empty.",5,8,"Glove box",[0,0.03,0],[0,0.03,0.12]),
            s("damper","Release the damper","Support the glove box and disconnect the small damper arm from its side peg as shown.","The arm is free; the glove box is still supported.",8,12,"Damper arm",[0.10,0.03,0],[0.14,0.03,0]),
            s("lower","Lower past the stops","Gently press the glove-box sides inward to clear their stops, then lower the box.","The filter housing is accessible behind it.",12,17,"Side stops",[0.10,0.02,0],[0.06,0.02,0]),
            s("cover","Remove the filter cover","Release the cover tab and remove the narrow cover. Store it in tray space 1.","The filter edge is visible.",17,21,"Cover tab",[0.08,0.03,0],[0.08,0.03,0.08],0),
            s("remove","Slide out the old filter","Pull the old filter straight out. Keep it separate in tray space 2.","The housing is empty; note how the old filter sat.",21,25,"Old filter",[0,0.03,0],[0,0.03,0.14],1),
            s("compare","Check the replacement","Compare the replacement's size and markings. This video uses AQ1102C with UP arrows. UP and AIR FLOW markings mean different things; follow your filter's instructions.","Correct fit and orientation confirmed before insertion.",25,31,"Replacement filter",[-0.06,0.02,0],[0.06,0.02,0],2),
            s("insert","Insert the new filter","For the AQ1102C shown here, keep UP arrows pointing upward and slide the filter fully into its housing. Do not force a mismatched filter.","The filter is seated flat.",31,38,"Insert filter",[0,0.03,0.14],[0,0.03,0],2,true),
            s("replace-cover","Refit the cover","Return the cover from tray space 1. Engage its locating end and secure its tab.","The cover is flush and secure.",38,41,"Return cover",[0,0.03,0.10],[0,0.03,0],0,true),
            s("raise","Raise the glove box","Lift the glove box and gently clear its side stops back into their normal position.","Both side stops are engaged.",41,46,"Side stops",[0.06,0.02,0],[0.10,0.02,0],nil,true),
            s("reattach","Reconnect the damper","Reconnect the damper arm to its peg while supporting the glove box.","The damper connection is secure.",46,50,"Damper peg",[0.14,0.03,0],[0.10,0.03,0],nil,true),
            s("check","Check and close","Open and close the glove box gently. Confirm its movement and latch, and account for the removed cover and old filter.","The glove box closes normally; no loose parts remain.",50,53,"Close glove box",[0,0.03,0.12],[0,0.03,0],nil,true)
        ],mechanicalModel:.cabinFilter)
    }()
    static let engine:LessonDefinition = {
        func s(_ id:String,_ title:String,_ instruction:String,_ check:String)->LessonStep {.init(id:id,title:title,instruction:instruction,check:check)}
        return .init(id:"four-stroke-engine",title:"Inside a car engine",category:"Automotive",object:"Spark-ignition engine · teaching cutaway",preparation:"Explore a tabletop cutaway of one cylinder. Tap a part to highlight it, then use Next to study each stroke. This model teaches the cycle; it is not a vehicle-specific disassembly guide.",tools:["No tools — virtual engine"],videoURL:"https://www.youtube.com/watch?v=kMCfZL9HgSk",attribution:"4-stroke reference · Briggs & Stratton",sourceURL:"https://www.briggsandstratton.com/en-us/support/videos/4-stroke-theory",spatialNote:"Simplified overhead-valve teaching model. Valve timing and combustion are illustrative. The reference video plays separately; no unverified timestamps are used.",trayLabels:[],steps:[
            s("parts","Meet the engine parts","Tap the piston, connecting rod, crankshaft, inlet valve, exhaust valve, or spark plug. Watch how the rod links the piston's motion to crankshaft rotation.","Find the piston and follow its rod down to the crankshaft."),
            s("intake","1 / Intake","The piston travels down while the inlet valve opens. The dots show incoming charge entering the cylinder.","The inlet valve is open; the piston moves down."),
            s("compression","2 / Compression","Both valves close. The piston rises and compresses the charge above it.","The piston approaches the cylinder head with both valves closed."),
            s("power","3 / Power","A spark begins combustion near the top. Expanding gas pushes the piston down; the connecting rod transfers this force to the crankshaft.","The spark flashes, then the piston descends with both valves closed."),
            s("exhaust","4 / Exhaust","The exhaust valve opens. The rising piston pushes spent gas out. Four strokes complete one cycle over two crankshaft revolutions.","Exhaust exits as the piston rises; Replay repeats this stroke.")
        ],mechanicalModel:.engine)
    }()
    static let all:[LessonDefinition] = [boat,repair,engine,jet,gearbox,brake,pump]
    // Bundled lessons are immutable. Validate once, outside the animation loop.
    static let valid = all.filter(\.isValid)
    static let byID = Dictionary(valid.map {($0.id,$0)},uniquingKeysWith: {first,_ in first})
}

enum LessonStorage {
    static func load(in directory:URL)->[LessonDefinition] {
        ((try? FileManager.default.contentsOfDirectory(at:directory,includingPropertiesForKeys:nil)) ?? []).filter{$0.pathExtension=="json"}.compactMap {url in
            guard let data=try? Data(contentsOf:url),data.count<=2_000_000,let lesson=try? JSONDecoder().decode(LessonDefinition.self,from:data),lesson.isValid else{return nil};return lesson
        }.sorted{$0.title<$1.title}
    }
    static func save(_ lesson:LessonDefinition,in directory:URL) throws {
        guard lesson.isValid else{throw LessonError.invalid}
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        let encoder=JSONEncoder();encoder.outputFormatting=[.prettyPrinted,.sortedKeys]
        try encoder.encode(lesson).write(to:directory.appendingPathComponent(lesson.id+".json"),options:.atomic)
    }
}
enum LessonError:LocalizedError {case invalid;var errorDescription:String?{"Check the title, instructions, YouTube link and step times. Each end must be after its start."}}
