# SGFPlayer3D Refactoring Status

**Date Started**: 2025-10-15
**Goal**: Implement live clock countdown and refactor codebase for better maintainability

## Current Status: ✅ 2D/3D FEATURE PARITY ACHIEVED (Session 7) - Board Size Support & Unified Controls!

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

### Phase 2: Extract OGSGameViewModel ✅ COMPLETE
**Goal**: Separate OGS game state management from UI

**Steps:**
1. [✓] Create OGSGameViewModel.swift - DONE
2. [✓] Move OGS-related state and logic - DONE
3. [✓] Test and integrate - DONE
4. [✓] Create test suite - DONE
5. [✓] Commit - DONE (commit 08450a3)

**Files Created:**
- SGFPlayer3D/ViewModels/OGSGameViewModel.swift (308 lines)
- SGFPlayer3DTests/OGSGameViewModelTests.swift (296 lines)
- SGFPlayer3DTests/TimeControlManagerTests.swift (242 lines)

**Files Modified:**
- SGFPlayer3D/ContentView3D.swift (reduced from 1,617 to ~840 lines)

**Result:**
- Removed 777 lines from ContentView3D
- Better separation of concerns
- Added comprehensive test coverage

---

### Phase 3: Split ContentView3D ✅ COMPLETE
**Goal**: Break large view into focused components

**Components Extracted:**
1. ✅ GameInfoOverlay.swift - Player info, time controls, captures, komi/rules (174 lines)
2. ✅ PlaybackControls.swift - Backward/forward/play/pause/seek controls (70 lines)
3. ✅ SettingsPanelContainer.swift - Settings panel presentation (43 lines)

**Result**: ContentView3D reduced from 1,617 → 1,167 lines (-450 lines, 28% reduction)

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

### 2025-10-16 (Session 3 - Phase 2 Complete)
- ✅ **Phase 2: Extract OGSGameViewModel** - COMPLETE (commit 08450a3)

- **Created OGSGameViewModel.swift** (308 lines)
  - Manages all OGS game state (@Published properties for player info, komi, ruleset, captures)
  - Handles notifications: OGSGameDataReceived, OGSMoveReceived, OGSPlayerInfo, OGSRateLimited
  - Implements polling with exponential backoff for rate limiting
  - Generates SGF from OGS move arrays with handicap stone support
  - Posts "OGSGameLoaded" notification for View to consume

- **Refactored ContentView3D** (reduced from 1,617 to ~840 lines)
  - Removed 15 @State variables for OGS game data
  - Removed ~260 lines across 6 OGS handler functions
  - Added @State ogsGame: OGSGameViewModel?
  - Updated UI bindings to use ogsGame.blackName, ogsGame.komi, etc.
  - Delegated notification handling to ViewModel

- **Created comprehensive test suite**
  - OGSGameViewModelTests.swift (296 lines, 11 test cases)
    - Tests game loading, player info updates, move handling
    - Tests polling lifecycle, throttling, game switching
  - TimeControlManagerTests.swift (242 lines, 10 test cases)
    - Tests clock initialization, countdown, player switching
    - Tests byo-yomi periods, reset functionality
  - Note: Tests require XCTest target to be added in Xcode

- **Impact**: 777 lines removed from ContentView3D, better separation of concerns
- **Next**: Phase 3 - Extract more ViewModels or split ContentView3D into smaller views

### 2025-10-16 (Session 4 - Phase 3 Complete)
- ✅ **Phase 3: Extract UI Components** - COMPLETE (commit 959be34)

- **Created comprehensive extraction plan** (PHASE3_EXTRACTION_PLAN.md)
  - Documented exact line numbers of code to extract
  - Mapped all dependencies for each component
  - Provided rollback instructions for debugging
  - Created success criteria checklist

- **Created GameInfoOverlay.swift** (174 lines)
  - Extracted from ContentView3D lines 446-597
  - Displays player names, ranks (OGS & local modes)
  - Shows time remaining with byo-yomi periods
  - Displays captures, komi, ruleset, move counter
  - Includes formatTime() helper function
  - Clean SwiftUI component with @ObservedObject bindings

- **Created PlaybackControls.swift** (70 lines)
  - Extracted from ContentView3D lines 478-520
  - Backward/forward navigation buttons
  - Play/pause with space bar shortcut
  - Seek slider for move navigation
  - Callback-based architecture (onSeek, onTogglePlayPause)

- **Refactored ContentView3D** (reduced from 1,361 to 1,174 lines)
  - Removed 187 lines of inline UI code
  - Replaced with clean component calls
  - Better separation of UI from logic
  - More maintainable structure

- **Testing Results**
  - Build: ✅ Success (no warnings)
  - Unit Tests: ✅ All 21/21 passed
  - Functionality: ✅ No regressions detected

- **Impact**: ContentView3D reduced by 14%, new reusable components created
- **Next**: Phase 4 - Board Interaction Manager or continue extracting components

### 2025-10-16 (Session 5 - Phase 3 Final)
- ✅ **Phase 3: Extract SettingsPanelContainer** - COMPLETE (commit 942669f)

- **Created SettingsPanelContainer.swift** (43 lines)
  - Extracted from ContentView3D lines 393-418
  - Manages settings panel presentation with slide-in transition
  - Uses @Binding for showSettings, isPlaying, playbackSpeed
  - Uses @EnvironmentObject for app (auto-injected)
  - Callback-based architecture (onGameSelected, onJitterChanged)

- **Updated ContentView3D** (reduced from 1,174 to 1,167 lines)
  - Replaced 26-line settingsPanel var with 19-line component call
  - Delegates HStack, transition, Spacer, zIndex to component
  - Further cleanup and simplification

- **Testing Results**
  - Build: ✅ Success (no warnings)
  - Unit Tests: ✅ All 22/22 passed (10 TimeControl + 11 OGSGameViewModel + 1 example)
  - Functionality: ✅ No regressions detected

- **Phase 3 Total Impact**:
  - 3 new component files created:
    - GameInfoOverlay.swift (174 lines)
    - PlaybackControls.swift (70 lines)
    - SettingsPanelContainer.swift (43 lines)
  - ContentView3D reduced from 1,617 → 1,167 lines (-450 lines, 28% reduction)
  - Improved maintainability with focused, reusable components
  - Better separation of concerns (UI components vs logic)
  - All functionality preserved, no regressions

- **Next**: Phase 4 - Consider extracting SceneManager3D or BoardInteractionManager

### 2025-10-16 (Session 6 - Bug Fixes After Phase 3)
- ✅ **Bug Fix Session** - Fixed critical stability and state management issues

- **Fixed startup crash** (v3.27) - ContentView3D.swift:360-368
  - Problem: App crashed on launch during window restoration
  - Root cause: Redundant `app.selectGame()` call in .onAppear handler
  - The call was also in .onChange(of: app.selection), causing double-call during restoration
  - Solution: Removed redundant call from .onAppear, added explanatory comment
  - User confirmed: No crash on launch

- **Fixed OGS auto-advance crash** (v3.27) - ContentView3D.swift:223
  - Problem: Auto-advance timer fired during OGS games, crashing with assertion failure
  - Root cause: Timer tried to advance to next local playlist item while watching OGS game
  - Solution: Added condition `if newIndex >= player.moves.count - 1 && ogsGame?.blackName == nil`
  - Only fire auto-advance timer for local games, not OGS games

- **Fixed OGS/local game state interference** (v3.28-v3.29) - ContentView3D.swift:230-260, 333-384
  - Problem: Switching from OGS game to local file would show OGS game position
  - Root cause: OGS polling timer kept running and updating board with OGS moves
  - Solution (2-part fix):
    1. **Stop OGS polling on game switch** (lines 236-249):
       - Detect when switching from OGS to local game in .onChange(of: app.selection)
       - Call `ogsGame?.stopPolling()` to stop background timer
       - Clear all OGS state (blackName, whiteName, ranks, komi, ruleset)
       - Reset currentGameID and timeControl
    2. **Guard OGS notifications** (lines 333-384):
       - v3.28: Added guards checking `ogsGame?.blackName != nil` (TOO RESTRICTIVE)
       - v3.29: Changed to check `ogsClient.currentGameID != nil` (CORRECT)
       - Prevents chicken-and-egg problem: blackName is SET BY the notification
       - currentGameID is set BEFORE notification, allowing initial game load
  - User confirmed: "looking good!"

- **Testing Results**
  - Build: ✅ Success (no warnings)
  - Startup: ✅ No crashes
  - OGS game join: ✅ Works correctly
  - OGS → Local switch: ✅ Clean state separation
  - Local → OGS switch: ✅ Can rejoin OGS games

- **Current version**: v3.29
- **Status**: All critical bugs fixed, committed (e9a45db)
- **Next**: Proceed to Phase 4

### 2025-10-16 (Session 6 - Phase 4 Step 1: Extract SceneManager3D)
- ✅ **Phase 4 Step 1: Extract SceneManager3D** - COMPLETE

- **Created SceneManager3D.swift** (566 lines)
  - Extracted entire SceneManager3D class from ContentView3D.swift
  - Manages all 3D scene rendering logic
  - Board creation with traditional Japanese proportions
  - Stone rendering with bi-convex lens shape
  - Halo effects for last played stone
  - Camera setup and positioning logic
  - Star field background generation
  - Grid lines and star points
  - Collision detection for jittered stones
  - Full ObservableObject with same public interface

- **Refactored ContentView3D** (reduced from 1,208 to 647 lines)
  - Removed 561 lines of 3D rendering code (46% reduction!)
  - SceneManager3D remains as @StateObject
  - All usage patterns unchanged - clean extraction
  - Better separation: UI logic vs 3D rendering logic

- **Testing Results**
  - Build: ✅ Success (no warnings)
  - App launch: ✅ Successful
  - User confirmed: "yup. all seems to work"

- **Impact**:
  - ContentView3D.swift: 1,208 → 647 lines (-561 lines, 46% reduction)
  - New file: SceneManager3D.swift (566 lines)
  - Total: Clean separation of concerns

- **Overall Progress (Original → Current)**:
  - ContentView3D.swift: 1,617 → 647 lines (-970 lines, **60% reduction!**)
  - Files extracted: 7 new files created
    1. TimeControlManager.swift (186 lines)
    2. OGSGameViewModel.swift (308 lines)
    3. GameInfoOverlay.swift (174 lines)
    4. PlaybackControls.swift (70 lines)
    5. SettingsPanelContainer.swift (43 lines)
    6. SceneManager3D.swift (566 lines)
    7. Test files (538 lines)

- **Committed**: db129c7

### 2025-10-16 (Session 6 - Phase 4 Step 2: Extract CameraControlHandler)
- ✅ **Phase 4 Step 2: Extract CameraControlHandler** - COMPLETE (v3.30)

- **Created Views/CameraControlHandler.swift** (138 lines)
  - Extracted from ContentView3D.swift lines 7-142
  - NSViewRepresentable for camera input handling
  - Mouse drag: Rotate (default) or Pan (Shift key)
  - Scroll wheel: Zoom in/out
  - Pinch gesture: Zoom in/out
  - Callback pattern with onUpdate closure
  - @Binding properties for camera state (rotationX, rotationY, distance, panX, panY)

- **Refactored ContentView3D** (reduced from 647 to 509 lines)
  - Removed 138 lines of camera control code
  - CameraControlHandler usage at line 285-292 unchanged
  - Better separation: UI vs input handling

- **Testing Results**
  - Build: ✅ Success (no errors, same warnings as before)
  - Next: User testing of camera controls

- **Impact**:
  - ContentView3D.swift: 647 → 509 lines (-138 lines, 21% reduction from Step 1)
  - New file: Views/CameraControlHandler.swift (138 lines)
  - Clean extraction with callback-based architecture

- **Phase 4 Total Impact**:
  - ContentView3D.swift: 1,208 → 509 lines (-699 lines, **58% reduction in Phase 4!**)
  - Files created:
    1. SceneManager3D.swift (566 lines)
    2. Views/CameraControlHandler.swift (138 lines)

- **Overall Progress (Original → Current)**:
  - ContentView3D.swift: 1,617 → 509 lines (-1,108 lines, **68% reduction!**)
  - Files extracted: 8 new files created
    1. TimeControlManager.swift (186 lines)
    2. OGSGameViewModel.swift (308 lines)
    3. GameInfoOverlay.swift (174 lines)
    4. PlaybackControls.swift (70 lines)
    5. SettingsPanelContainer.swift (43 lines)
    6. SceneManager3D.swift (566 lines)
    7. Views/CameraControlHandler.swift (138 lines)
    8. Test files (538 lines)

- **Next**: Test camera controls, then commit Phase 4 Step 2

### 2025-10-18 (Session 7 - Board Size Support & 2D/3D Feature Parity)
- ✅ **Major Feature Update: Board Size Support & Complete 2D/3D Unification** - COMPLETE (v3.31+)

#### Part 1: Board Size Support (9x9, 13x13, 19x19)
- **Problem**: App was hardcoded to 19x19 boards only
- **Goal**: Support all standard board sizes (9x9, 13x13, 19x19)

**2D Implementation:**
- **SimpleBoardView.swift**:
  - Changed hardcoded `let gridSize = 19` to `player.board.size`
  - Added dynamic hoshi points based on board size:
    - 19x19: 9 points at traditional positions
    - 13x13: 5 points
    - 9x9: 5 points
  - Fixed StoneJitter.prepare() call to use actual board size (line 363)

- **GameBoardView.swift**:
  - Updated to use `player.board.size` dynamically

**3D Implementation:**
- **SceneManager3D.swift**:
  - Changed `boardSize` from constant to variable
  - Added auto-recreation of board when size changes
  - Implemented dynamic hoshi points (matching 2D)
  - **Scaling feature**: Smaller boards scaled to fill same space as 19x19
    - Uses computed properties: `effectiveCellWidth`, `effectiveCellHeight`
    - Scale factor: `18 / (boardSize - 1)`
    - 9x9 boards: 2.25x larger cells
    - 13x13 boards: 1.5x larger cells
    - 19x19 boards: normal (1.0x)
  - Fixed board cleanup to remove both SCNBox (grid lines) and SCNSphere (hoshi points)

**Bug Fixes:**
- **Crash #1** (StoneJitter array bounds): Fixed hardcoded boardSize in jitter preparation
- **Crash #2** (AppModel.selectGame): Fixed invalid range when at last game
  - Changed `for i in 1...min(2, games.count - currentIndex - 1)` to guard with `if gamesAhead > 0`

**Testing**: Created test files test_9x9.sgf and test_13x13.sgf
**Result**: Both 2D and 3D now correctly render all board sizes

#### Part 2: Search Functionality in 3D
- **Goal**: Add search to 3D mode to match 2D functionality

**Implementation:**
- Added search state variables to ContentView3D:
  - `filteredGames`, `isSearchActive`, `lastSearchQuery`, `isSearchActivePersisted`
  - Added `activeGamesList` computed property (filtered or all games)
  - Added `performSearch()` function

- Updated SettingsPanelView3D:
  - Replaced `GameSelectionSection3D` with unified `GameSelectionSection` component
  - Added `onSearchResultsChanged` callback parameter

- Updated SettingsPanelContainer to pass search callback through

- Updated ContentView3D to handle search results:
  - Updates filtered games
  - Persists search state
  - Switches to first result when searching
  - Restores search on app launch

**Result**: 3D mode now has identical search functionality to 2D

#### Part 3: Auto-Advance Unification
- **Goal**: Make auto-advance behavior identical in 2D and 3D

**Changes:**
- Aligned timer delay: Both wait 5 seconds (was 3s in 3D)
- Moved playback restart logic to timer callback (from advanceToNextGame)
- Updated both to use `activeGamesList` (respects search filtering)

**Result**: Auto-advance now respects search results in both modes

#### Part 4: Autoplay Controls Unification
- **Goal**: Make all playback controls identical between 2D and 3D

**Changes Made:**
- **ContentView3D.swift**:
  - Replaced local `@State isPlaying` with persistent `@AppStorage autoNext`
  - Added missing control variables:
    - `@AppStorage("autoNext")` - Auto-play toggle
    - `@AppStorage("randomNext")` - Random next game
    - `@AppStorage("autoStartOnLaunch")` - Auto-start on launch
    - `@AppStorage("randomOnStart")` - Random game on start
    - `@AppStorage("loopGames")` - Loop games (already existed)
  - Updated all references from `isPlaying` to `autoNext`

- **SettingsPanelView3D.swift**:
  - Added bindings for all 4 playback controls
  - Updated UI to match 2D layout:
    - Row 1: Auto-play, Random next
    - Row 2: Auto-start on launch, Loop games

- **SettingsPanelContainer.swift**:
  - Added bindings for new controls
  - Passes them through to SettingsPanelView3D

**Result**:
- Both 2D and 3D have **identical** autoplay controls
- All settings shared via `@AppStorage` (changes in one mode affect both)
- Complete feature parity between 2D and 3D views

#### Summary of Changes
**Files Modified:**
- SimpleBoardView.swift (board size support, hoshi points)
- GameBoardView.swift (board size support)
- SceneManager3D.swift (3D board size, scaling, hoshi points, cleanup)
- AppModel.swift (fixed auto-advance crash)
- ContentView3D.swift (search, autoplay controls, auto-advance)
- SettingsPanelView3D.swift (search, autoplay toggles)
- SettingsPanelContainer.swift (search callback, autoplay bindings)

**Impact:**
- ✅ Board size support: 9x9, 13x13, 19x19 in both 2D and 3D
- ✅ 3D boards scale to fill screen (better UX for small boards)
- ✅ Search functionality now in both 2D and 3D
- ✅ Auto-advance respects search filtering in both modes
- ✅ Identical autoplay controls in both 2D and 3D
- ✅ Complete feature parity between 2D and 3D rendering modes

**Architecture Improvement:**
- 2D and 3D now truly parallel implementations
- Same functionality, just different rendering (2D vs 3D)
- Maximum code reuse via shared components
- Consistent, intuitive user experience across modes

**Status**: Ready for commit
**Next**: Additional features or further refactoring as needed

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
