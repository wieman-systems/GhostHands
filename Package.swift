// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GhostHandsCore",
    platforms: [.macOS(.v14)],
    products: [.library(name: "GhostHandsCore", targets: ["GhostHandsCore"])],
    targets: [
        .target(name: "GhostHandsCore", path: "GhostHands", exclude: ["DetailedVisual.swift", "ModelSurface.swift", "LabVisual.swift", "NarrationResources", "MechanicalVisual.swift", "Adversarial-Review.txt", "GhostHandsApp.swift", "HandCapture.swift", "SpatialStudio.swift", "StudioUI.swift", "VideoReference.swift", "Info.plist", "Assets.xcassets", "HandResources", "HologramHand.swift", "PaperVisual.swift", "HumanReplay.swift", "AvatarResources", "LessonAuthorView.swift", "VoiceCoach.swift"], sources: ["LabContent.swift", "NarrationPolicy.swift", "EngineCycle.swift", "Lessons.swift", "VideoSession.swift", "PlayerHTML.swift", "AvatarRig.swift", "PaperMotion.swift", "Placement.swift", "HandRetargeting.swift", "Motion.swift", "PaperLesson.swift", "YouTubeLink.swift", "StudioModel.swift", "TestHandCapture.swift"]),
        .testTarget(name: "GhostHandsCoreTests", dependencies: ["GhostHandsCore"], path: "Tests")
    ])
