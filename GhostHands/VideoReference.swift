import SwiftUI
import WebKit

struct VideoIntro: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        VStack(alignment:.leading,spacing:14) {
            Label("Keep a tutorial beside your workspace",systemImage:"play.rectangle").font(.title3.bold())
            Text("Paste a YouTube link into a movable reference window. Watch, pause, and scrub using YouTube’s controls while you practice.").font(.subheadline)
            Button("Open YouTube reference",systemImage:"rectangle.on.rectangle") { openWindow(id:"video") }
            Text("This plays the original video. It does not convert video into 3D hands; record your own demonstration to make a spatial lesson.").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct VideoReference: View {
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var customLink = false
    @State private var input = "https://www.youtube.com/watch?v=vNba3jbBSOw"
    @State private var link: YouTubeLink? = YouTubeLink("https://www.youtube.com/watch?v=vNba3jbBSOw")
    @State private var message = "EzOrigami · How to Make a Paper Boat. Tap Play to watch the rectangular-paper boat tutorial."
    var body: some View {
        VStack(alignment:.leading,spacing:16) {
            HStack {
                Label("Paper boat / EzOrigami",systemImage:"play.rectangle.fill").font(.title2.bold())
                Spacer()
                Button("CLOSE VIDEO",systemImage:"xmark") { dismissWindow(id:"video") }
            }
            DisclosureGroup("Use a different tutorial link",isExpanded:$customLink) {
              HStack {
                TextField("https://www.youtube.com/watch?v=…",text:$input).textFieldStyle(.plain).padding(10).overlay(Rectangle().stroke(.white.opacity(0.3)))
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                Button("Load") {
                    guard let parsed = YouTubeLink(input) else { message = "Enter a valid YouTube video link (watch, share, Shorts, or live)."; return }
                    link = parsed; message = "Use the player to pause, scrub, or change speed. Some videos do not allow embedding."
                }.buttonStyle(SquareButton(selected:true)).tint(.ghostMint).foregroundStyle(.black)
            }
            }
            Group {
                if let link { YouTubePlayer(link:link,message:$message).id(link.embedURL) }
                else {
                    VStack(spacing:14) {
                        Image(systemName:"play.rectangle").font(.system(size:64)).foregroundStyle(Color.ghostLavender)
                        Text("A reference you can put anywhere.").font(.title3)
                        Text("Move this window next to your paper.").foregroundStyle(.secondary)
                    }.frame(maxWidth:.infinity,maxHeight:.infinity).background(.black.opacity(0.25))
                }
            }.frame(height:360).clipShape(Rectangle())
            Text(message).font(.caption).foregroundStyle(.secondary)
            HStack {
                if let link { Link("Open on YouTube",destination:link.watchURL).font(.caption) }
            }
        }.padding(24).frame(width:760,height:customLink ? 730 : 650).background(.black).foregroundStyle(.white).buttonStyle(SquareButton()).tint(.white)
        .task {
            #if targetEnvironment(simulator)
            if ProcessInfo.processInfo.arguments.contains("--video-preview") {
                input = "https://www.youtube.com/watch?v=vNba3jbBSOw"
                link = YouTubeLink(input)
                message = "EzOrigami · Paper boat tutorial. Tap Play to begin."
            }
            #endif
        }
    }
}

struct YouTubePlayer: UIViewRepresentable {
    let link: YouTubeLink
    @Binding var message: String
    func makeCoordinator() -> Coordinator { Coordinator(message:$message) }
    func makeUIView(context:Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        let view = WKWebView(frame:.zero,configuration:configuration)
        view.navigationDelegate = context.coordinator
        var request = URLRequest(url:link.embedURL)
        // YouTube requires mobile WebViews to identify the embedding app.
        let identity = "https://" + (Bundle.main.bundleIdentifier ?? "com.calebwieman.ghosthands").lowercased()
        request.setValue(identity,forHTTPHeaderField:"Referer")
        view.load(request)
        return view
    }
    func updateUIView(_ view:WKWebView,context:Context) {}
    static func dismantleUIView(_ view:WKWebView,coordinator:Coordinator) {
        view.stopLoading(); view.navigationDelegate = nil
        view.loadHTMLString("<html><body></body></html>",baseURL:nil)
    }
    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var message:String
        init(message:Binding<String>) { _message = message }
        func webView(_ webView:WKWebView,didFailProvisionalNavigation navigation:WKNavigation!,withError error:Error) {
            message = "Video could not load: \(error.localizedDescription). Check the connection or use Open on YouTube."
        }
        func webView(_ webView:WKWebView,didFail navigation:WKNavigation!,withError error:Error) {
            message = "Video playback could not load. Try Open on YouTube."
        }
    }
}
