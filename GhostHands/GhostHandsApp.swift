import SwiftUI

@main
struct GhostHandsApp: App {
    @State private var studio = StudioModel()
    var body: some Scene {
        WindowGroup(id: "home") { HomeView().environment(studio) }
            .windowStyle(.plain)
            .defaultSize(width:960,height:640)
            .windowResizability(.contentSize)
        WindowGroup(id: "video") { VideoReference() }
            .windowStyle(.plain)
            .defaultSize(width:760,height:570)
            .windowResizability(.contentSize)
        ImmersiveSpace(id: "studio") { SpatialStudio().environment(studio) }
            .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
