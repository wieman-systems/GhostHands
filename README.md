# GhostHands

Learn a hands-on skill through spatial demonstrations on Apple Vision Pro. Built for SASEHacks 2026, GhostHands focuses on folding a paper boat from a full US Letter sheet.

![GhostHands placement instructions](Setup-Build6.png)

## What it does

- Guides you through clearing a table, then places the workspace from a two-second right-index hold.
- Reveals movement arrows around the paper for horizontal, vertical, and rotational adjustment.
- Demonstrates an 18-step paper boat with animated paper and translucent joint hands.
- Supports autoplay per step, speed controls, start/finish inspection, and optional looping.
- Records real hand joints and replays them relative to the paper workspace.
- Opens EzOrigami’s paper-boat tutorial automatically after placement.
- Offers an optional life-size human for mirrored hand recording/replay (off by default in Settings).

The built-in demonstrations are authored illustrations, not expert recordings or a physical paper simulation. YouTube playback does not generate 3D motion.

## Run

1. Open `GhostHands.xcodeproj` in Xcode with a visionOS SDK (built with Xcode 27; deployment target visionOS 2).
2. Select the GhostHands scheme, your signing team, and an Apple Vision Pro destination.
3. Build and run. Allow hand tracking and world sensing.
4. Enter Workspace, find a large clear spot, and select **I Have a Clear Spot**. Lift your right index, move it to the table center, and hold still for two seconds.
5. Use **Place → Reposition** to expose movement arrows around the paper, then select **Done**.
6. The boat video opens automatically; tap Play. For human replay, turn on **Settings → Human Replay**, record both hands, then replay the take.

The Place controls include rotation, movement, and 2 mm height adjustment. Real hand recording requires Vision Pro; the simulator can show the authored animations.

## Code map

| File | Responsibility |
| --- | --- |
| `StudioModel.swift` | Session state, placement, playback, recording, saving |
| `Placement.swift` | Stable fingertip calibration |
| `HandCapture.swift` | ARKit tracking and fresh joint snapshots |
| `SpatialStudio.swift` | RealityKit scene and tabletop panels |
| `PaperLesson.swift` | Boat instructions and generated hand demonstrations |
| `PaperMotion.swift` | Authored folding geometry and hand contact paths |
| `HologramHand.swift` | Translucent joint rendering |
| `StudioUI.swift` | SwiftUI controls |
| `AvatarRig.swift` | Mirrored hand mapping and inferred arm movement |
| `HumanReplay.swift` | Loads and animates the optional human |

Source files are in `GhostHands/`.

## Validation

```sh
swift test --scratch-path /tmp/GhostHandsTests --disable-sandbox
```

Build 6: 34 tests passed, signed device and simulator builds succeeded, and the simulator view was inspected. The headset connection was unavailable for build 6 deployment. Direct-touch alignment and complete beginner tutorial usability still require worn-headset validation.

## Data and assets

Recordings stay on the device. This repository excludes recordings, provisioning profiles, signed builds, and device installation logs. Included Apple hand reference assets retain their license in `GhostHands/HandResources/AppleGlove-LICENSE.txt`; the current renderer uses procedural joint geometry.

## Human replay

The bundled human is Microsoft Rocketbox’s Male_Adult_01, converted to USDZ and normalized to 1.75 m. Its MIT license and provenance are in `GhostHands/AvatarResources/`. Recorded hand positions are rotated 180° for face-to-face mirrored replay. Arm bends and wrist orientation are inferred; this is not full-body motion capture. Both hands must be tracked; gaps hide the avatar. It is a textured game character, not a photoreal scan. Adjust Table Height in Settings to align the feet with the room.

The tutorial is [How to Make a Paper Boat by EzOrigami](https://www.youtube.com/watch?v=vNba3jbBSOw). Playback uses the official embed and requires an internet connection.

![Optional human replay — simulator fixture](Human-Replay-Build6.png)
