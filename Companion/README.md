# Optional Apple Watch haptics

**Build 18:** Use the on-panel digit keypad to enter the iPhone code; the system
keyboard is no longer needed. Pair enables after six digits and phone discovery.

**Build 17:** Automatic left-hand button pulses are temporarily disabled after a
button-input regression. Pairing and **Test Watch Tap** remain available. The
visionOS switch is now labeled **Connect Watch companion**. The original design
and limits below describe build 16; do not treat normal button haptics as active.


Build 16 adds an opt-in local relay: Vision Pro → iPhone → paired Apple Watch.
The iPhone and Vision Pro builds are installed and launched. The Watch target builds,
but physical Watch installation, paired-device messaging and tactile latency remain
unverified until the Watch is connected for development.

## Setup

1. Open `GhostHandsHaptics.xcodeproj` in Xcode. Select the iPhone and run the
   `GhostHandsHaptics` scheme. Select its paired Watch and run `GhostHandsWatch`.
   Use your own signing team when building elsewhere. The Watch needs a profile
   that includes that Watch; a generic signed build is not proof of installability.
2. Open **GhostHands Haptics** on the iPhone and Watch. Keep the iPhone app visible.
   The iPhone intentionally stays awake during an active pairing session.
3. Tap **Start pairing** on the iPhone. In GhostHands on Vision Pro, open
   **Settings → Watch**, enable **Left-hand Watch feedback**, enter the six-digit
   code and tap **Pair with iPhone**. Allow Local Network access when requested.
4. Tap **Test Watch Tap**, then press a GhostHands button with your left hand.
   Right-hand and unknown-hand events remain silent. The test button deliberately
   sends a pulse independently of handedness.
5. Keep the Watch app frontmost. Lowering the wrist can leave it frontmost/inactive;
   returning to the watch face stops availability. Reopen it if feedback stops.
   If either relay app goes into the background, restart pairing.

Only custom GhostHands buttons using `SquareButton` participate. Native YouTube
controls, system menus, toggles and controls outside GhostHands are not covered.
This is a wrist click, not force feedback or a physical fingertip sensation.

## Behavior and verification

- Uses the button's pressed state plus SwiftUI spatial-event chirality. Does not
  replace button actions or send raw hand tracking/recordings over the network.
- MultipeerConnectivity requires encryption and a fresh, explicit pairing code.
  Only one peer is accepted per session. Messages are small and ephemeral.
- Uses WatchConnectivity immediate messaging; no background transfer/retry queue.
- Pulses older than 600 ms, duplicated, unavailable or less than 90 ms apart are
  dropped. Valid IDs are consumed even on a rejected pulse, preventing later replay.
- Watch acknowledgements report round-trip time, not measured tactile onset.
- Keeps existing GhostHands layout, recordings, tutorial playback and placement.
- 93 core tests pass, including left/right/unknown input, callback ordering,
  cancellation, unavailable/late/future/duplicate packets and burst rejection.
- Vision Pro, iOS and watchOS device targets compile. Vision Pro/iPhone simulator
  builds and screens were checked. No watchOS simulator runtime is installed.
- Signed phone and Vision Pro ZIPs pass strict verification after extraction.
  Physical Watch gesture routing, foreground recovery and haptic delay still
  require a real-device test. No claim of instantaneous feedback is made.

The Xcode project can be regenerated with `python3 ../Scripts/create-haptics-project.py`
from this folder. Source files shared with Vision Pro live in `../GhostHands`.

Apple references: [WatchConnectivity](https://developer.apple.com/documentation/watchconnectivity),
[immediate messaging](https://developer.apple.com/documentation/watchconnectivity/wcsession/sendmessage(_:replyhandler:errorhandler:)),
[frontmost Watch apps](https://developer.apple.com/documentation/watchkit/taking-advantage-of-frontmost-app-state),
[spatial-event chirality](https://developer.apple.com/documentation/swiftui/spatialeventcollection/event/chirality).
