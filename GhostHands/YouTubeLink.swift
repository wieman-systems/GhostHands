import Foundation

struct YouTubeLink: Equatable {
    let videoID: String
    let startSeconds: Int
    init?(_ input: String) {
        let trimmed = input.trimmingCharacters(in:.whitespacesAndNewlines)
        guard trimmed.count <= 4096 else { return nil }
        let candidate = trimmed.contains("://") ? trimmed : "https://" + trimmed
        guard let url = URLComponents(string:candidate), url.scheme?.lowercased() == "https",
              url.user == nil, url.password == nil, url.port == nil || url.port == 443,
              let host = url.host?.lowercased() else { return nil }
        let parts = url.path.split(separator:"/").map(String.init)
        let items = url.queryItems ?? []
        let id: String?
        if ["youtu.be","www.youtu.be"].contains(host), parts.count == 1 { id = parts[0] }
        else if ["youtube.com","www.youtube.com","m.youtube.com","youtube-nocookie.com","www.youtube-nocookie.com"].contains(host) {
            if url.path == "/watch" { id = items.first { $0.name == "v" }?.value }
            else if parts.count == 2, ["embed","shorts","live"].contains(parts[0]) { id = parts[1] }
            else { id = nil }
        } else { return nil }
        guard let id, id.range(of:"^[a-zA-Z0-9_-]{11}$",options:.regularExpression) != nil else { return nil }
        videoID = id
        let time = items.first { $0.name == "t" || $0.name == "start" }?.value ?? "0"
        if let seconds = Int(time) { startSeconds = min(86400,max(0,seconds)) }
        else {
            var value = 0, total = 0
            for char in time {
                if let digit = char.wholeNumberValue { value = min(86400,value*10+digit) }
                else {
                    if char == "h" { total += value*3600 }
                    else if char == "m" { total += value*60 }
                    else if char == "s" { total += value }
                    value = 0
                }
            }
            startSeconds = min(86400,max(0,total+value))
        }
    }
    var embedURL: URL {
        var parts = URLComponents(string:"https://www.youtube.com/embed/\(videoID)")!
        parts.queryItems = [.init(name:"playsinline",value:"1"), .init(name:"start",value:String(startSeconds)), .init(name:"autoplay",value:"0")]
        return parts.url!
    }
    var watchURL: URL { URL(string:"https://www.youtube.com/watch?v=\(videoID)&t=\(startSeconds)s")! }
}
