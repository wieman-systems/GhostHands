# GhostHands

Learn a hands-on skill through spatial demonstrations on Apple Vision Pro. Built for SASEHacks 2026, GhostHands includes a paper boat lesson, interactive piston-engine, jet-turbine, gearbox, disc-brake and water-pump labs, and a manually guided cabin-filter replacement rehearsal.

![GhostHands docked tutorial — simulator](Workspace-Build10.png)

## What it does

- Guides you through clearing a table, then places the workspace from a two-second right-index hold, 1 cm higher than build 10.
- Locks the table with an ARKit world anchor. Tracking loss hides and pauses the workspace; large position/orientation changes require explicit placement again.
- Offers optional metallic colored models under Settings → Models, while retaining monochrome UI.
- Adds a ventilated disc-brake assembly (tap caliper to clamp/release) and centrifugal pump (tap impeller to start/stop), with selectable parts and exploded views.
- Reveals movement arrows around the paper for horizontal, vertical, and rotational adjustment.
- Demonstrates an 18-step paper boat with animated paper and translucent joint hands.
- Keeps a compact playback panel on the far side of the paper: Play/Pause, speed dropdown, and More menu for replay, loop, start/finish, video and Home.
- Records real hand joints and replays them relative to the paper workspace.
- Seeks the YouTube tutorial to each action, pauses at the segment end, and replays that segment alongside the spatial guide.
- Accepts spoken Next, Back, Slow down, Faster, Show that again, Pause, Play, and Read instructions.
- Bundles 51 natural AI-generated instruction clips for offline playback. Settings → Audio controls automatic reading and repetition after video (off by default). Narration stops when video resumes.
- Opens YouTube from an always-visible playback button in every lesson, including all 3D labs.
- Accepts any supported YouTube video URL and remembers the choice per lesson. The jet lab includes Safran’s turbine reference.
- Keeps independent video and model playback separate, with optional Step Sync for authored tutorials. Opening YouTube in a mechanical lab enables model looping.
- Anchors YouTube above the workspace, with Standard/Large/Largest sizes and height/distance adjustments in Place.
- Keeps the right panel at a fixed size with compact tabs, dropdowns and paginated recordings.
- Explores a jet engine with fan, compressor, combustion, turbine, bypass/core flow and exploded inspection; a gearbox adds meshing gears and defect-finding practice.
- Includes a 2018 Toyota Corolla cabin-filter lesson with a 3D housing/filter illustration, manual arrows and a numbered parts tray.
- Teaches an engine’s four-stroke cycle with a native 3D cutaway, moving piston/rod/crank, opening valves and a spark cue. Tap a part or use the parts dropdown to highlight it.
- Authors new lessons with video timestamps, written instructions, fingertip-placed arrows, and local hand takes; imports/exports lesson JSON.
- Offers an optional life-size human for mirrored hand recording/replay (off by default in Settings).

The built-in demonstrations are authored illustrations, not expert recordings or a physical paper simulation. YouTube playback does not generate 3D motion.

## Run

1. Open `GhostHands.xcodeproj` in Xcode with a visionOS SDK (built with Xcode 27; deployment target visionOS 2).
2. Select the GhostHands scheme, your signing team, and an Apple Vision Pro destination.
3. Build and run. Allow hand tracking and world sensing.
4. Enter Workspace, find a large clear spot, and select **I Have a Clear Spot**. Lift your right index, move it to the table center, and hold still for two seconds.
5. Use **Place → Reposition** to expose movement arrows around the paper, then select **Done**.
6. For timed boat/filter lessons, the selected video opens automatically. Tap Play if YouTube requires it. Next/Back select a timed action; Show That Again replays it.
7. Enable **Settings → Voice** and grant microphone/speech permissions. Say “Next,” “Slow down,” or “Show that again.” While video audio is playing, say “GhostHands, next” (the wake phrase helps avoid tutorial speech triggering controls). Auto-read is enabled by default for 3D lessons. Repeat After Video defaults off; enable it in Settings → Audio if wanted. Read Now pauses the video first.
8. Choose **Lessons → Cabin air filter** for the repair rehearsal. Use **Place → Arrow Start/End** to anchor each action manually. Tray buttons mark parts stored/returned; they do not detect objects.
9. **Lessons → New Lesson / Edit a Copy** opens the editor. Load a YouTube URL, scrub it, mark Start/End, write each action, preview, and save. Record and attach a take for custom hand motion. JSON export includes cues and timings; recordings remain local.
10. Choose **Lessons → Inside a car engine** for the engine lesson. Use Next to study each stroke, or Replay/Loop in the playback More menu. Its reference video is optional and plays independently.
11. For human replay, turn on **Settings → Scene → Human Replay**, record both hands, then replay the take.

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
| `EngineCycle.swift` | Crank/rod/piston geometry and teaching stroke states |
| `LabContent.swift`, `LabVisual.swift` | Turbofan/gearbox lessons and interactive procedural assemblies |
| `NarrationPolicy.swift` | Narration preferences and exact-text offline clip lookup |
| `MechanicalVisual.swift` | Interactive engine cutaway and filter housing illustration |
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

Build 15: 88 core tests and 8 player-controller scenarios passed. Device and simulator builds succeeded. New tests verify universal video access, custom-video timing isolation, independent transport, sync toggling, persistent choices and reference reconciliation across lesson/recording changes. Live player and installation results are in `VALIDATION.txt`. Worn-headset reach and audio still require user testing.

## Data and assets

Recordings and custom lessons stay on the device unless explicitly exported. Voice uses on-device English speech recognition when available; unavailable recognition leaves the buttons usable. No microphone audio is saved by GhostHands. YouTube playback uses the network and its official player. This repository excludes recordings, provisioning profiles, signed builds, and device installation logs. Included Apple hand reference assets retain their license in `GhostHands/HandResources/AppleGlove-LICENSE.txt`; the current renderer uses procedural joint geometry.

## Engine lesson

The engine is an original procedural teaching model of one spark-ignition cylinder, with simplified valve timing and combustion cues. It is not a scanned engine or a vehicle-specific repair procedure. The lesson follows [Briggs & Stratton’s four-stroke explanation](https://www.briggsandstratton.com/en-us/support/videos/4-stroke-theory); its [reference video](https://www.youtube.com/watch?v=kMCfZL9HgSk) is optional and has no claimed timestamp synchronization. Piston, connecting rod, crankshaft, inlet/exhaust valves and spark plug can be selected by hand targeting or the parts dropdown.

## Human replay

The bundled human is Microsoft Rocketbox’s Male_Adult_01, converted to USDZ and normalized to 1.75 m. Its MIT license and provenance are in `GhostHands/AvatarResources/`. Recorded hand positions are rotated 180° for face-to-face mirrored replay. Arm bends and wrist orientation are inferred; this is not full-body motion capture. Both hands must be tracked; gaps hide the avatar. It is a textured game character, not a photoreal scan. Adjust Table Height in Settings to align the feet with the room.

The boat source is [How to Make a Paper Boat by EzOrigami](https://www.youtube.com/watch?v=vNba3jbBSOw). The repair source is [Filterheads’ 2018 Corolla cabin filter replacement](https://www.youtube.com/watch?v=LFA9g7GdXbQ), specifically showing AQ1102C UP markings. Confirm the exact vehicle/filter match before working on a car. The first repair mode is a tabletop rehearsal with manually placed arrows, not vehicle scanning or automatic part recognition.

Timestamps were manually reviewed. Illustrated folds are stretched across each video segment; they are not frame-exact captured movements. New YouTube links require authored steps and timings; arbitrary videos are not automatically converted to 3D. Offline, close the video and use the authored guide.

![Optional human replay — simulator fixture](Human-Replay-Build6.png)

## Jet, gearbox and narration

The turbofan lesson uses an original procedural cutaway with selectable modules, rotating compressor/turbine stages, core and bypass flow, and a miniature aircraft silhouette. The [NASA turbofan explanation](https://www.grc.nasa.gov/www/k-12/airplane/Animation/turbtyp/etfh.html) informs the lesson. The gearbox illustrates a 12:24 tooth ratio. Exploded views and deliberately shortened components support visual inspection practice; these are teaching models, not engineering simulations or maintenance instructions.

`NarrationResources/manifest.json` documents 51 AI-generated clips produced from the original built-in instructions using OpenAI gpt-4o-mini-tts and the Cedar voice. The app plays the bundled MP3 files offline; it contains no API key and makes no speech-generation requests. Edited/custom instructions use the best installed English device voice. Generation reference: [OpenAI text-to-speech guide](https://developers.openai.com/api/docs/guides/text-to-speech).

## Build 11 placement and interactive models

The initial guide is 2 mm above the tracked index-tip center instead of 8 mm below it, a 1 cm upward change. Place → Reposition retains 2 mm height adjustments. Heading freezes once the fingertip settles. Placement requires a tracked device pose, and table movement is accepted only in explicit reposition mode.

The committed workspace uses an [ARKit world anchor](https://developer.apple.com/documentation/visionos/tracking-points-in-world-space). An untracked anchor hides the scene and pauses playback; a valid nearby update can recover it. Translation of 12 cm or more, heading changes of 15° or more, invalid transforms, or substantial tilt latch the recovery screen until Place Again. These are conservative app safeguards, not a guarantee that OS tracking never shifts. Current recordings are saved before tracking pauses.

Colored mode uses physically based metallic materials, with translucent cutaway surfaces where needed. The original monochrome hologram mode remains available. Jet blades now use swept, tapered geometry. The brake includes annular rotor faces, cooling vanes, hub bolts, pads and caliper pistons. The pump includes curved vanes, an open casing, shaft and flanges. These original procedural assemblies illustrate mechanisms; they are not manufacturer CAD, scanned assets or maintenance instructions. Concept references: [Brembo ventilation](https://asia.bremboparts.com/america/en/support/car/how-to-choose-the-right-product/brake-rotors-with-vane-vs-pillar-ventilation-the-differences-204921), [Grundfos impeller and volute](https://www.grundfos.com/ca/learn/ecademy/all-courses/centrifugal-pump-theory/impeller-and-volute-function).

Use Lessons to choose the new assemblies. Tap the caliper/impeller or use Inspect → Apply brake / Stop pump. Exploded mode separates the assemblies and disables operation until reassembled. Speed and Pause control their motion. Color is saved between launches.

![Colored disc-brake assembly — simulator](Brake-Build11.png)

![Colored pump assembly — simulator](Pump-Build11.png)

## YouTube in every lesson

Select **More → Open YouTube** on the playback panel, or **Settings → Scene → Open YouTube**. The jet lab opens [Safran’s explanation](https://www.youtube.com/watch?v=kz5kv0RfeUc). Other lessons retain their original references or show a video chooser. **More → Choose Video → Enter a YouTube link** loads a custom reference without modifying the authored lesson. **Find videos on YouTube** opens an external YouTube search when no reference is selected. Choices stay on device in ReferenceVideos.json.

YouTube controls live below the right workspace panel. Play/Pause and Replay operate the video; model playback stays on the tabletop playback panel. Next, Replay, model speed and model scrubbing do not seek or truncate an independent video. A custom video never inherits origami timestamps. Paper/filter lessons still offer Step Sync for their original references; switch it off to watch freely. Closing or failing an independent video leaves the model running. Narration continues to defer while video audio is playing.

The video remains docked behind the workspace; use the YouTube controls’ More → Video Size to enlarge it. Position adjustments are available under Place while the panel is open. Opening YouTube enables looping for mechanical labs; the playback More menu can turn looping off. Embedding still depends on the selected creator’s YouTube settings and network access.

## Simpler controls and smoother playback (build 13)

YouTube is back under the playback panel’s **More** menu. The floating video has one centered row of four fixed-width controls; source selection, step sync and sizing are grouped in **More**. Editing a link replaces that row with Load and Cancel. The video area is taller without increasing the window footprint.

Bundled lesson validation is cached instead of repeated during rendering. Hand sampling retains full precision while the timer and scrubber update at tenths of a second. Synced animation advances between YouTube’s 150 ms snapshots, with a 300 ms extrapolation limit and immediate holds for pending commands, buffering and pause. Fresh callbacks remain authoritative. Play restarts a completed timed step.

A local optimized core benchmark (1,000 ticks per case, no RealityKit/GPU) measured boat 0.319 → 0.00275 ms/tick, cabin-filter 0.289 → 0.00174, recorded playback 0.314 → 0.00274. This measures model/lookup work, not headset frame rate. Worn-headset smoothness still needs confirmation.

![Centered video controls — simulator](YouTube-Build13.png)

## Tabletop video controls and continuous folds (build 14)

The right workspace panel and YouTube controls form a fixed **470 × 820** column (590 + 12 gap + 218). The left lesson panel uses the same outer dimensions. Video controls remain reachable on the table when the floating screen is enlarged or moved.

- **Move:** look at the screen, pinch and drag it in 3D, then tap **Done** to lock its position. Movement changes only the screen’s offset from the anchored workspace. **More → Reset video position** returns it above the paper.
- **Video Only:** removes the app title and frame and enlarges the screen. Playback controls remain on the table. **Framed** restores the title. **More → Video Size** offers additional sizes. Moving/resizing does not recreate or seek the player. YouTube retains control of its own branding, ads and other service overlays.
- The presentation embed uses YouTube’s supported `controls=0`; standalone authoring retains its native timeline for marking tutorial segments.

RealityKit frame events now drive playback instead of a work-plus-16-ms sleep loop. Paper vertices update continuously in one reusable LowLevelMesh; the former 45-pose quantization and repeated mesh creation are removed. Existing recording interpolation, missing-hand gaps, anchor recovery and pause rules remain in force.

API references: [Apple LowLevelMesh](https://developer.apple.com/documentation/realitykit/lowlevelmesh), [Apple spatial gestures](https://developer.apple.com/videos/play/wwdc2023/10113/), [YouTube player parameters](https://developers.google.com/youtube/player_parameters).

![Matched tabletop panels — simulator](Workspace-Build14.png)

![Moved video-only screen — simulator](VideoOnly-Build14.png)

## Symmetric controls, two-hand sizing and more mechanisms (build 15)

Both tabletop columns are **470 × 852**: a 590-point panel, a 12-point gap, and 250-point controls. Animation transport is beneath the left lesson panel; video controls are beneath the right workspace panel.

In video **Move** mode, use a **two-handed pinch-and-spread gesture** on the screen to resize it (bounded to 0.35–1.4 scale). Drag still moves it. During Move the screen faces the tracked head in yaw and pitch; Done locks the resulting pose. A small vertical dead zone prevents heading flips above or below the head. No video gesture changes the workspace anchor.

Three original selectable teaching assemblies were added, each with three steps, looping motion, part highlighting, existing color controls and bundled Cedar narration:

| Model | Demonstration | Matched video reference |
|---|---|---|
| Cam and follower | Eccentric disk lifts a guided flat follower | [CAD CAM 23 — cam and follower](https://www.youtube.com/watch?v=2u0VlFaJ0nE) |
| Belt and pulley drive | Open belt; large pulley turns at half input speed | [Jay Panchal — V-belt animation](https://www.youtube.com/watch?v=v5urs0gWF3U) |
| Crank-slider linkage | Rigid rod converts circular motion into an 80 mm stroke | [Ujjwal Suryakant Rane — slider-crank kinematics](https://www.youtube.com/watch?v=G6XZvkfiIng) |

Titles and publishers for these and the four previously assigned references were checked through YouTube oEmbed on October 24, 2026; metadata is in `VideoReferences.json`. The new videos explain the same mechanisms and run independently, without invented step timestamps. The model geometry is illustrative rather than a replica of each video's CAD or a repair specification. Existing user-selected video overrides are preserved.

![Symmetric controls and crank-slider — simulator](Crank-Build15.png)

## Build 16 — optional Watch feedback

Left-hand presses on custom GhostHands buttons can send a short click through an
iPhone relay to a paired Apple Watch. Enable it in **Settings → Watch**.
[Companion setup and current limits](Companion/README.md). Vision Pro and iPhone
build 16 are installed and launched; actual Watch installation and haptic latency
are not yet verified. 93 core tests pass.
