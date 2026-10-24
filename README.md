# GhostHands

Learn a hands-on skill through spatial demonstrations on Apple Vision Pro. Built for SASEHacks 2026, GhostHands includes a paper boat lesson and a manually guided cabin-filter replacement rehearsal.

![GhostHands placement instructions](Setup-Build6.png)

## What it does

- Guides you through clearing a table, then places the workspace from a two-second right-index hold.
- Reveals movement arrows around the paper for horizontal, vertical, and rotational adjustment.
- Demonstrates an 18-step paper boat with animated paper and translucent joint hands.
- Supports autoplay per step, speed controls, start/finish inspection, and optional looping.
- Records real hand joints and replays them relative to the paper workspace.
- Seeks the YouTube tutorial to each action, pauses at the segment end, and replays that segment alongside the spatial guide.
- Accepts spoken Next, Back, Slow down, Faster, Show that again, Pause, Play, and Read instructions.
- Reads instructions after video playback stops. Narration stops when video resumes.
- Includes a 2018 Toyota Corolla cabin-filter lesson with manual arrows and a numbered parts tray.
- Authors new lessons with video timestamps, written instructions, fingertip-placed arrows, and local hand takes; imports/exports lesson JSON.
- Offers an optional life-size human for mirrored hand recording/replay (off by default in Settings).

The built-in demonstrations are authored illustrations, not expert recordings or a physical paper simulation. YouTube playback does not generate 3D motion.

## Run

1. Open `GhostHands.xcodeproj` in Xcode with a visionOS SDK (built with Xcode 27; deployment target visionOS 2).
2. Select the GhostHands scheme, your signing team, and an Apple Vision Pro destination.
3. Build and run. Allow hand tracking and world sensing.
4. Enter Workspace, find a large clear spot, and select **I Have a Clear Spot**. Lift your right index, move it to the table center, and hold still for two seconds.
5. Use **Place → Reposition** to expose movement arrows around the paper, then select **Done**.
6. The selected video opens automatically. Tap Play if YouTube requires it. Next/Back select a timed action; Show That Again replays it.
7. Enable **Settings → Voice** and grant microphone/speech permissions. Say “Next,” “Slow down,” or “Show that again.” While video audio is playing, say “GhostHands, next” (the wake phrase helps avoid tutorial speech triggering controls). Read Instructions is enabled by default and waits for the video to pause.
8. Choose **Lessons → Cabin air filter** for the repair rehearsal. Use **Place → Arrow Start/End** to anchor each action manually. Tray buttons mark parts stored/returned; they do not detect objects.
9. **Lessons → New Lesson / Edit a Copy** opens the editor. Load a YouTube URL, scrub it, mark Start/End, write each action, preview, and save. Record and attach a take for custom hand motion. JSON export includes cues and timings; recordings remain local.
10. For human replay, turn on **Settings → Human Replay**, record both hands, then replay the take.

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
| `Lessons.swift` | Reusable lesson schema, boat/repair catalog and storage |
| `VideoSession.swift`, `PlayerHTML.swift`, `VideoReference.swift` | Serialised player commands, official YouTube bridge and segment playback |
| `VoiceCoach.swift` | On-device speech commands and narration/audio coordination |
| `LessonAuthorView.swift` | Timestamp editor, spatial cues, local takes and JSON import/export |
| `AvatarRig.swift` | Mirrored hand mapping and inferred arm movement |
| `HumanReplay.swift` | Loads and animates the optional human |

Source files are in `GhostHands/`.

## Validation

```sh
swift test --scratch-path /tmp/GhostHandsTests --disable-sandbox
node Scripts/player-controller-tests.cjs
```

Build 8: 44 core tests and 8 player-controller scenarios passed. Signed device and simulator builds succeeded. The real embedded YouTube player passed initial playback, step seek, segment pause and replay checks in the simulator. Author and repair screens were rendered and inspected. Installation is deferred until the headset reconnects. Voice recognition, acoustic echo handling, tabletop contact and novice tutorial usability still need worn-headset validation.

## Data and assets

Recordings and custom lessons stay on the device unless explicitly exported. Voice uses on-device English speech recognition when available; unavailable recognition leaves the buttons usable. No microphone audio is saved by GhostHands. YouTube playback uses the network and its official player. This repository excludes recordings, provisioning profiles, signed builds, and device installation logs. Included Apple hand reference assets retain their license in `GhostHands/HandResources/AppleGlove-LICENSE.txt`; the current renderer uses procedural joint geometry.

## Human replay

The bundled human is Microsoft Rocketbox’s Male_Adult_01, converted to USDZ and normalized to 1.75 m. Its MIT license and provenance are in `GhostHands/AvatarResources/`. Recorded hand positions are rotated 180° for face-to-face mirrored replay. Arm bends and wrist orientation are inferred; this is not full-body motion capture. Both hands must be tracked; gaps hide the avatar. It is a textured game character, not a photoreal scan. Adjust Table Height in Settings to align the feet with the room.

The boat source is [How to Make a Paper Boat by EzOrigami](https://www.youtube.com/watch?v=vNba3jbBSOw). The repair source is [Filterheads’ 2018 Corolla cabin filter replacement](https://www.youtube.com/watch?v=LFA9g7GdXbQ), specifically showing AQ1102C UP markings. Confirm the exact vehicle/filter match before working on a car. The first repair mode is a tabletop rehearsal with manually placed arrows, not vehicle scanning or automatic part recognition.

Timestamps were manually reviewed. Illustrated folds are stretched across each video segment; they are not frame-exact captured movements. New YouTube links require authored steps and timings; arbitrary videos are not automatically converted to 3D. Offline, close the video and use the authored guide.

![Optional human replay — simulator fixture](Human-Replay-Build6.png)
