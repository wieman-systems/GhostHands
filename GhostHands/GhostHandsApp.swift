import SwiftUI

@main
struct GhostHandsApp: App {
    @State private var studio = StudioModel()
    @State private var voice = VoiceCoach()
    var body: some Scene {
        WindowGroup(id: "home") { HomeView().environment(studio).environment(voice) }
            .windowStyle(.plain)
            .defaultSize(width:960,height:640)
            .windowResizability(.contentSize)
        WindowGroup(id: "video") { VideoReference().environment(studio).environment(voice) }
            .windowStyle(.plain)
            .defaultSize(width:760,height:650)
            .windowResizability(.contentSize)
        WindowGroup(id:"author") {LessonAuthorView().environment(studio).environment(voice)}
            .windowStyle(.plain).defaultSize(width:900,height:740).windowResizability(.contentSize)
        ImmersiveSpace(id: "studio") { SpatialStudio().environment(studio).environment(voice) }
            .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
