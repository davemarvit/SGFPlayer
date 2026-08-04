# SGFPlayer3D Working Plan

This plan keeps the two product goals separate while we stabilize the shared codebase:

1. Ambient SGF player for local game folders.
2. OGS client for live Online Go Server play.

## Baseline

- Current baseline branch: `codex/baseline-sgfplayer3d-ogs`.
- Baseline tag: `baseline-sgfplayer3d-ogs-2026-08-03`.
- The app builds with `xcodebuild`.
- The scheme is not configured for Xcode test execution yet.
- Existing architectural map: `PROJECT_MAP.md`.
- Existing launch/status notes: `BASELINE.md`.

## Stabilization Rules

- Keep local SGF playback and OGS live play as explicit modes.
- Do not let OGS polling, websocket notifications, or live game metadata mutate the local SGF player while in local mode.
- Do not let local autoplay, random game selection, or loop playback run while in OGS mode.
- Prefer small commits that preserve a working build.
- Add logging around mode transitions and game-state changes before changing deeper behavior.

## Track A: Ambient SGF Player

Definition of usable:

- Select a folder of SGF files.
- Restore the last folder and selected game on launch.
- Play, pause, seek, loop, randomize, and auto-advance local games reliably.
- Keep 2D and 3D views consistent because they share one `SGFPlayer`.
- Avoid spurious captures, sounds, or bowl animations when seeking, polling, or reloading.

Near-term work:

- Add focused logs around `SGFPlayer` move application, captures, seeks, and reloads.
- Reproduce the false capture/sound issue with a small SGF fixture.
- Separate "move playback effects" from "board state calculation" so seeking/reloading does not look like a live capture.
- Add a minimal test target or command-line harness for capture rules and SGF parsing.

## Track B: OGS Client

Definition of usable:

- Authenticate or reuse credentials.
- Connect to OGS.
- List or join active games.
- Render the current game board and metadata.
- Submit legal moves when it is our turn.
- Receive live updates without corrupting local SGF playback state.

Near-term work:

- Keep all OGS entry and exit behavior routed through `AppModel`.
- Inventory the OGS REST and websocket calls in `OGSClient`.
- Replace stringly typed `NotificationCenter` events with typed app-level state updates, or at least wrap notification names in one place first.
- Add logs for join-game, game-data load, move receipt, polling reload, optimistic move placement, and reconnects.
- Define a small "OGS game session" model that owns `currentGameID`, phase, polling, and live metadata.

## Architecture Direction

The current system works through a shared `SGFPlayer`, a large `OGSClient`, `OGSGameViewModel`, two large content views, and several notification handlers. The likely cleanup path is incremental:

1. Make mode boundaries explicit.
2. Centralize side effects in `AppModel` or a small coordinator.
3. Add enough logs and tests to reproduce state bugs.
4. Split OGS session state from local SGF playlist state.
5. Shrink `ContentView` and `ContentView3D` so they render state and delegate actions.

The first code change after this plan should be small: add explicit local-vs-OGS mode transitions and gate event handlers by mode.
