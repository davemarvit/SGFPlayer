# SGFPlayer3D Baseline

Last reviewed: 2026-08-03

This file captures a safe baseline for continuing SGFPlayer3D work without accidentally changing runtime behavior during cleanup.

## Repository State

Repo root:

`/Users/Dave/SGFPlayer`

Active project:

`/Users/Dave/SGFPlayer/SGFPlayer3D/SGFPlayer3D.xcodeproj`

Baseline branch:

`codex/baseline-sgfplayer3d-ogs`

Baseline source commit:

`423666a v3.193 - Extract GameInfoAndControlsView`

Upstream branch at baseline creation:

`origin/refactor/clean-architecture-for-chat`

The source branch was 4 commits ahead of upstream when this baseline was created.

## Current Dirty Files

Tracked non-source metadata changes present before baseline work:

- `.DS_Store`
- `SGFPlayer/.DS_Store`
- `SGFPlayer/build/Release/.DS_Store`

Untracked files/directories present before or during baseline work:

- `CLEAN_ARCHITECTURE_REBUILD_PLAN.md`
- `CONTENTVIEW_DEPENDENCY_MAP.md`
- `OGS-Client/.DS_Store`
- `OGS-Client/js/.DS_Store`
- `Old/.DS_Store`
- `Old/OGS-Client/.DS_Store`
- `SGFPlayer3D/Backups/`
- `SGFPlayer3D/PROJECT_MAP.md`
- `SGFPlayer3D/BASELINE.md`

Do not delete or revert these casually. Some may be user-created work or useful recovery material.

## Launch

Open the project in Xcode:

```bash
open /Users/Dave/SGFPlayer/SGFPlayer3D/SGFPlayer3D.xcodeproj
```

Use the `SGFPlayer3D` scheme.

The app switches between 2D and 3D through `AppModel.viewMode`; both views share the same `AppModel`, `SGFPlayer`, `OGSClient`, `TimeControlManager`, and `OGSGameViewModel`.

## Baseline Build Command

Use a local derived-data folder so validation does not depend on user-level DerivedData state:

```bash
xcodebuild \
  -project /Users/Dave/SGFPlayer/SGFPlayer3D/SGFPlayer3D.xcodeproj \
  -scheme SGFPlayer3D \
  -configuration Debug \
  -derivedDataPath /private/tmp/SGFPlayer3DDerivedData \
  build
```

Result on 2026-08-03:

`BUILD SUCCEEDED`

Observed warnings only:

- asset catalog has unassigned children in `AppIcon` and `clamNH_01`
- several unused local variables
- one `@ViewBuilder` warning in `BoardInteractionOverlay`
- one main-actor warning in `SGFPlayerViewModel`
- optional interpolation warnings in `GameStateCache`

## Baseline Test Command

```bash
xcodebuild \
  -project /Users/Dave/SGFPlayer/SGFPlayer3D/SGFPlayer3D.xcodeproj \
  -scheme SGFPlayer3D \
  -configuration Debug \
  -derivedDataPath /private/tmp/SGFPlayer3DDerivedData \
  test
```

Result on 2026-08-03:

Tests did not run because the scheme is not configured for the test action.

`xcodebuild: error: Scheme SGFPlayer3D is not currently configured for the test action.`

Before relying on tests as a baseline, configure the `SGFPlayer3D` scheme to include `SGFPlayer3DTests`, or add a separate shared test scheme.

## Runtime Logs

Useful live logs:

```bash
log stream --predicate 'processImagePath CONTAINS "SGFPlayer3D"' --style compact | grep -E "OGS|CAPTURE|capture|BOWL|BOARD|MOVE|SGF|DEBUG3D"
```

Custom OGS log:

```bash
tail -f /tmp/sgfplayer_ogs.log
```

Other debug files observed in code:

- `/tmp/sgfplayer3d_debug.log`
- `~/Desktop/sgfplayer3d_debug.log`
- `~/Desktop/sgfplayer_ogs_debug.log`
- `~/Desktop/sgfplayer3d_debug.txt`

## Active Source Map

Architecture map:

`/Users/Dave/SGFPlayer/SGFPlayer3D/PROJECT_MAP.md`

Primary files:

- `SGFPlayer3D/SGFPlayer3DApp.swift`: app entry and view-mode switch
- `SGFPlayer3D/AppModel.swift`: composition root and shared state
- `SGFPlayer3D/SGFKit.swift`: lightweight SGF parsing and game model
- `SGFPlayer3D/SGFPlayerEngine.swift`: board state, playback, captures, optimistic moves
- `SGFPlayer3D/OGSClient.swift`: OGS auth, REST, websocket, challenge/game actions
- `SGFPlayer3D/ViewModels/OGSGameViewModel.swift`: OGS game data to synthetic SGF/game load
- `SGFPlayer3D/ContentView.swift`: 2D board path
- `SGFPlayer3D/ContentView3D.swift`: 3D SceneKit board path and much of current event routing
- `SGFPlayer3D/SceneManager3D.swift`: 3D rendering
- `SGFPlayer3D/TimeControlManager.swift`: OGS clock/local countdown
- `SGFPlayer3D/ViewModels/StonePositionViewModel.swift`: bowl stone layout and capture sound trigger
- `SGFPlayer3D/SoundManager.swift`: stone/capture audio

## Known Source-of-Truth Concerns

These are baseline risks, not new changes:

1. `OGSClient.swift` is very large and owns too many responsibilities.
2. OGS state is delivered through stringly-typed `NotificationCenter` events.
3. `ContentView` and `ContentView3D` duplicate OGS event routing.
4. OGS game state is converted into synthetic SGF, reparsed, then loaded into `SGFPlayer`.
5. Optimistic moves mutate the same `SGFPlayer` state later overwritten by authoritative OGS reloads.
6. Capture side effects are not clearly tied to one validated capture event.
7. Capture counts/bowl stones have several partially overlapping sources.
8. There is a root-level `OGSClient.swift` and a target-level `SGFPlayer3D/OGSClient.swift`; they are not identical. The nested target file is the active source.
9. Some docs still reference `/Users/Dave/Go/SGFPlayer Code/SGFPlayer3D`, which appears stale for this baseline.

## Cleanup Rules

Do first:

- Keep behavior unchanged.
- Commit docs separately from code.
- Ignore `.DS_Store` unless intentionally normalizing repo hygiene.
- Do not delete `Backups/`, `Old/`, duplicate client files, or existing docs until they are classified.
- Prefer adding small tests before changing game/OGS behavior.

Do not do first:

- Do not rewrite `OGSClient`.
- Do not remove the synthetic SGF bridge before a replacement OGS game-state model exists.
- Do not move OGS routing out of both views in one large patch.
- Do not change capture/bowl/sound behavior without instrumentation proving the source of the issue.

## Recommended Next Work

1. Add structured debug logging around captures:
   - `SGFPlayer.apply`
   - OGS reload identity
   - `StonePositionViewModel.updateStonePositions`
   - `SoundManager.playCaptureSound`

2. Add pure unit tests:
   - no-capture move leaves capture counts unchanged
   - one-stone capture increments the right count
   - repeated OGS reload with same move count does not emit new capture effect
   - optimistic move followed by authoritative reload does not double-trigger effects

3. Introduce typed OGS events or an `OGSGameSessionCoordinator` beneath both views.

4. Move OGS notification handling out of `ContentView` and `ContentView3D` after tests/logging exist.

5. Classify stale/generated files and update `.gitignore` only after confirming nothing important is hidden there.
