# SGFPlayer3D Refactoring Status

**Date Started**: 2025-10-15
**Goal**: Implement live clock countdown and refactor codebase for better maintainability

## Current Status: ✅ PHASE 1 COMPLETE - Ready for commit

## Background
- ContentView3D.swift is 1,566 lines (too large)
- OGSClient.swift is 1,173 lines
- Total codebase: 42 Swift files, ~12,612 lines
- Clock times are displayed but don't count down during play

## Refactoring Plan

### Phase 1: Extract TimeControlManager ✅ CURRENT PHASE
**Goal**: Create a dedicated manager for clock countdown logic

**Steps:**
1. [✓] Create TimeControlManager.swift (new file) - DONE
   - Handle live countdown timers
   - Track current player's time
   - Support byo-yomi periods
   - Sync with OGS clock updates

2. [✓] Test compilation - DONE
   - Build project to ensure no errors
   - Build succeeded

3. [✓] Integrate into ContentView3D - DONE
   - [✓] Add @StateObject for TimeControlManager
   - [✓] Remove old unused clock variables
   - [✓] Update UI to display TimeControlManager times
   - [✓] Connect TimeControlManager to OGS clock updates
   - [✓] Start/stop clock on moves
   - [✓] Fix clock switching between players

4. [✓] Test functionality - DONE
   - [✓] Verify countdown works (local countdown implemented)
   - [✓] Test move transitions (clock switches on moves)
   - [✓] Test byo-yomi handling (UI shows periods correctly)
   - [✓] Test game switching (old timer properly stopped)

5. [ ] Commit changes - READY
   - Git commit with Phase 1 complete

**Files to Modify:**
- NEW: SGFPlayer3D/TimeControlManager.swift (~100-150 lines)
- MODIFY: SGFPlayer3D/ContentView3D.swift (remove ~50 lines, add ~20 lines)

**Expected Line Changes:**
- Net reduction: ~30 lines in ContentView3D
- New specialized file: TimeControlManager.swift

---

### Phase 2: Extract OGSGameViewModel (FUTURE)
**Goal**: Separate OGS game state management from UI

**Steps:**
1. Create OGSGameViewModel.swift
2. Move OGS-related state and logic
3. Test and integrate
4. Commit

**Files to Create:**
- SGFPlayer3D/ViewModels/OGSGameViewModel.swift (~200-300 lines)

---

### Phase 3: Split ContentView3D (FUTURE)
**Goal**: Break large view into focused components

**Components to Extract:**
1. GameBoardView3D.swift - 3D board rendering
2. GameControlsView.swift - Playback controls
3. OGSStatusView.swift - Network/game status

---

## Change Log

### 2025-10-15 23:45
- Created REFACTORING_STATUS.md
- Starting Phase 1: TimeControlManager extraction
- Current commit: ea2a9a0 (v3.24)

### 2025-10-15 23:55
- Created TimeControlManager.swift (186 lines)
- Build test: SUCCESS
- Integrated @StateObject into ContentView3D
- Updated UI to use TimeControlManager times
- Next: Wire up OGS clock updates to TimeControlManager

### 2025-10-15 23:58
- ✅ Integration complete!
- Added .onChange handler to sync OGS clock to TimeControlManager
- Build test #2: SUCCESS
- Ready for user testing
- Next: Test live countdown, then commit if working

### 2025-10-16 (Session 2)
- **Fixed clock switching bug**: Added logic to determine whose turn it is after loading game (ContentView3D.swift:937-943)
  - Calculate current player based on move count and handicap
  - Call `timeControl.switchToPlayer()` with correct player
  - User confirmed: "seems to be working"

- **Added latency compensation**: Implemented server timestamp sync in OGSClient.swift:984-998
  - Extract "now" timestamp from OGS clock events
  - Calculate network latency offset
  - Subtract latency from displayed times to compensate for network delay
  - Note: Still not receiving WebSocket clock events (only REST API polling)

- **Added dual clock monitoring**: ContentView3D.swift:292-325
  - Monitor both blackTimeRemaining and whiteTimeRemaining
  - Sync all clock changes to TimeControlManager
  - Start clock automatically when OGS game is loaded

- **Fixed game switching bug**: ContentView3D.swift:816-823, 956-957
  - Problem: Loading new game after finishing one would show old game's final position
  - Root cause: Old polling timer kept fetching previous game's data
  - Solution: Detect game ID change, stop old timer, reset state, restart with new game ID
  - User confirmed: "it seems to be working"

- **Status**: Phase 1 complete, ready for commit
- **Known issue**: WebSocket clock events not being received (subscription not working yet)
  - Clock times sync via REST API polling instead
  - Need to investigate WebSocket subscription in future session

---

## Recovery Instructions (If Interrupted)

If this refactoring is interrupted, follow these steps:

1. **Check this status file** to see which phase was in progress
2. **Check git status** to see what files have uncommitted changes
3. **Review the TODO list** in the Phase section marked CURRENT PHASE
4. **Options:**
   - If changes compile and work: Complete the phase and commit
   - If changes are broken: Run `git restore .` to revert and restart the phase
   - If uncertain: Review the diffs with `git diff` before deciding

## Build & Test Commands

```bash
# Build the project
cd "/Users/Dave/Go/SGFPlayer Code/SGFPlayer3D"
xcodebuild -project SGFPlayer3D.xcodeproj -scheme SGFPlayer3D -configuration Debug build

# Run the app
open "/Users/dave/Library/Developer/Xcode/DerivedData/SGFPlayer3D-clytobqxdmoqeccwzekaxegwfyjh/Build/Products/Debug/SGFPlayer3D.app"

# Check uncommitted changes
git status
git diff
```

## Notes
- Each phase should be committed separately
- Test after each integration step
- Keep changes small and focused
- Update this file after each step
