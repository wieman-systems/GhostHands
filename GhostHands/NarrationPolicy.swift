import Foundation
import CryptoKit

struct NarrationPreferences:Codable,Equatable {
    var enabled=true
    var repeatAfterVideo=false
    var naturalVoice=true
}
enum NarrationPolicy {
    static func allows(automatic:Bool,hasVideo:Bool,repeatAfterVideo:Bool,manual:Bool)->Bool {manual || (automatic && (!hasVideo || repeatAfterVideo))}
    static func text(for step:LessonStep)->String {"\(step.title). \(step.instruction)"}
    static func assetName(for text:String)->String {SHA256.hash(data:Data(text.utf8)).map{String(format:"%02x",$0)}.joined()}
}
