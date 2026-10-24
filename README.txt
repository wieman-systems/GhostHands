GHOSTHANDS — BUILD 5 — OCTOBER 24, 2026

Open GhostHands.xcodeproj; scheme GhostHands. Bundle: com.calebwieman.ghosthands.
Latest confirmed headset version before this update attempt: build 4.
Build 5 installation failed when the device disconnected; reconnect and unlock
the headset before retrying. Signed and simulator builds are in Builds/.

SETUP
Enter Workspace. Rest your RIGHT index fingertip on the center of a full
8½ × 11 inch sheet and hold still. Open LEFT thumb/index, then pinch left and
hold briefly to lock. Calibration needs 0.35 s of stability and a 0.15 s pinch.
Lost tracking or movement resets commitment. The setup window shows tracking
status and Cancel; it closes when placement succeeds. Reposition reopens it.
There is no automatic height guess and no competing drag gesture.

TABLE CONTROLS
The lesson, playback and tools panels lie flat at the same calibrated table
height. Place provides rotation, 1 cm movement and 2 mm height adjustments.
Adjust height if physical table contact does not match buttons. These use
visionOS system direct interaction; exact worn-headset alignment is unverified.

LESSON
18 actions use the full Letter sheet. Each selected step plays once and holds
its finished pose. Next starts the next authored example. Replay Current Demo
preserves your selected take. Show Start/Show Finish pause at the endpoints.
Speed: 0.25×–2×; default 0.75×. Optional looping, paper and hand visibility.
Hands use soft translucent joints. Paper flips lift clear of the table; front
folds preserve back layers. Pocket opening starts from the preceding shape;
corner wrapping, flattening and hull spreading visibly animate. The start and
finish cards render the same geometry as the animation.
The paper is an authored teaching approximation, not a physical simulation or
an expert recording. Actual beginner completion remains a wearer check.

RECORDINGS / VIDEO
Recording and local replay remain available. Older takes preserve original
paper dimensions and lesson IDs; select them explicitly in Library. Nothing is
uploaded. Device Documents backup completed before the attempted update.
YouTube remains a separate reference window, not automatic video-to-3D motion.
Licensed Apple hand resources remain included for prior retargeting support;
the active renderer uses translucent joint geometry.

VALIDATION
30 tests passed; signed device and simulator builds passed; simulator tabletop
rendering inspected. See VALIDATION.txt, Adversarial-Review.txt and
Installation/Build5 for exact evidence and limitations.

BUILD
xcodebuild -project GhostHands.xcodeproj -scheme GhostHands -configuration Release -sdk xros build
swift test --scratch-path <cache-directory> --disable-sandbox
Use DerivedData outside Documents for signing.
