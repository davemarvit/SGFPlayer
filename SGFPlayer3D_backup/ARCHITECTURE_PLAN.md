# SGFPlayer3D Architecture Transformation Plan

**Master Document - Version 1.0**
**Date Started**: 2025-10-16
**Current Status**: Phase 1 Complete, Starting Phase 2

---

## Table of Contents
1. [Vision & Goals](#vision--goals)
2. [Current State](#current-state)
3. [Target Architecture](#target-architecture)
4. [Refactoring Phases](#refactoring-phases)
5. [Progress Tracker](#progress-tracker)
6. [Recovery Instructions](#recovery-instructions)
7. [Design Decisions](#design-decisions)

---

## Vision & Goals

### Primary Goal
Transform SGFPlayer3D from a **game viewer** into a **full-featured OGS game client** capable of:
- Finding and accepting games
- Playing moves interactively
- Managing multiple simultaneous games
- Real-time communication with opponents
- Analysis and review

### Architecture Goals
1. **Maintainability**: No file over 800 lines
2. **Testability**: Clear separation of concerns
3. **Scalability**: Easy to add new features
4. **Performance**: Smooth 60fps 3D rendering
5. **Recoverability**: Clear documentation for session recovery

---

## Current State

### Current File Structure (as of v3.26)
```
SGFPlayer3D/
├── ContentView3D.swift         1,617 lines  ⚠️ TOO LARGE
│   └── Contains: UI layout, OGS state, playback, camera, settings
├── OGSClient.swift             1,173 lines  ✓ Acceptable (networking)
├── TimeControlManager.swift      186 lines  ✓ Good (Phase 1 complete)
└── SceneManager3D.swift         ~600 lines  ✓ Good (3D rendering)
```

### Current Problems
1. **ContentView3D is a God Object**: 1,617 lines doing everything
   - UI layout
   - OGS game state management
   - Playback control
   - Camera control
   - Settings management
   - Event handling

2. **No board interaction**: Can't click to place stones
3. **No game management**: Can't find/start/manage games
4. **Mixed responsibilities**: View logic + business logic + state management

### What Works Well
- ✅ WebSocket connection to OGS
- ✅ Authentication system
- ✅ Game data parsing from REST API
- ✅ 3D board rendering with SceneKit
- ✅ Camera controls (rotate, zoom, pan)
- ✅ Live clock countdown (Phase 1)
- ✅ Stone placement with jitter
- ✅ Handicap stone support
- ✅ Move playback

---

## Target Architecture

### Target File Structure
```
SGFPlayer3D/
├── ViewModels/
│   ├── OGSGameViewModel.swift         ~300 lines  [Phase 2]
│   │   └── Manages: Game state, challenges, finding games
│   └── TimeControlManager.swift        186 lines  [Phase 1] ✓ DONE
│       └── Manages: Clock countdown, time controls
│
├── Managers/
│   ├── BoardInteractionManager.swift  ~200 lines  [Phase 4]
│   │   └── Handles: Click detection, move validation, preview
│   ├── SceneManager3D.swift           ~700 lines  [Enhanced in Phase 4]
│   │   └── Handles: 3D rendering, animations, visual effects
│   └── GameStateManager.swift         ~250 lines  [Phase 5 - Future]
│       └── Handles: Local game state, SGF generation, undo/redo
│
├── Views/
│   ├── ContentView3D.swift            ~500 lines  [Phase 3]
│   │   └── Main container, coordinates subviews
│   ├── GameInfoOverlay.swift          ~150 lines  [Phase 3]
│   │   └── Player info, captures, komi, time display
│   ├── PlaybackControls.swift         ~100 lines  [Phase 3]
│   │   └── Play/pause, seek slider, navigation
│   ├── SettingsPanelContainer.swift    ~50 lines  [Phase 3]
│   │   └── Settings panel presentation
│   ├── GameControlButtons.swift       ~150 lines  [Phase 6 - Future]
│   │   └── Pass, Resign, Request Analysis, Score Est
│   ├── GameFinderView.swift           ~200 lines  [Phase 7 - Future]
│   │   └── Quick match, custom game, open games list
│   └── ChatPanel.swift                ~150 lines  [Phase 8 - Future]
│       └── Game chat, spectator chat
│
├── Network/
│   └── OGSClient.swift                ~1200 lines [Existing, stable]
│       └── WebSocket, REST API, authentication
│
└── Models/
    ├── OGSGame.swift                   ~100 lines  [Phase 5 - Future]
    ├── Challenge.swift                  ~80 lines  [Phase 7 - Future]
    └── GameSettings.swift               ~60 lines  [Phase 7 - Future]
```

### Architecture Principles

#### 1. MVVM Pattern
- **Models**: Data structures (OGSGame, Challenge, GameSettings)
- **ViewModels**: Business logic, state management (OGSGameViewModel, TimeControlManager)
- **Views**: UI only, no business logic (ContentView3D, GameInfoOverlay, etc.)

#### 2. Single Responsibility
- Each file has ONE clear purpose
- No file over 800 lines
- Manager classes handle specific domains (board interaction, scene rendering, time control)

#### 3. Clear Data Flow
```
OGSClient (WebSocket)
    ↓
OGSGameViewModel (state management)
    ↓
ContentView3D (coordinator)
    ↓
Child Views (display)
```

#### 4. Separation of Concerns
- **Networking**: OGSClient handles all network communication
- **State**: ViewModels hold application state
- **Presentation**: Views render UI based on state
- **Interaction**: Managers handle user input and convert to state changes
- **Rendering**: SceneManager3D handles all 3D graphics

---

## Refactoring Phases

### ✅ Phase 1: Extract TimeControlManager (COMPLETE - v3.26)
**Status**: DONE
**Commit**: 8b1f1e0

**What was done:**
- Created TimeControlManager.swift (186 lines)
- Extracted clock countdown logic from ContentView3D
- Fixed clock switching between players
- Fixed game switching bug (stop old polling timer)
- Added latency compensation
- Added dual clock monitoring

**Files changed:**
- NEW: TimeControlManager.swift
- MODIFIED: ContentView3D.swift (-30 lines net)
- MODIFIED: OGSClient.swift (+38 lines for latency)
- NEW: REFACTORING_STATUS.md

---

### 🔄 Phase 2: Extract OGSGameViewModel (IN PROGRESS)
**Status**: NEXT UP
**Target**: Reduce ContentView3D by ~200 lines
**Estimated time**: 2-3 hours

**Goals:**
1. Create new `ViewModels/OGSGameViewModel.swift`
2. Move all OGS-related state from ContentView3D
3. Move OGS game management logic
4. Keep existing functionality working

**What to extract:**

```swift
class OGSGameViewModel: ObservableObject {
    // Current game state (from ContentView3D)
    @Published var currentGameID: Int?
    @Published var blackName: String?
    @Published var whiteName: String?
    @Published var blackRank: String?
    @Published var whiteRank: String?
    @Published var komi: String?
    @Published var ruleset: String?
    @Published var blackCaptured: Int = 0
    @Published var whiteCaptured: Int = 0

    // Polling state (from ContentView3D)
    private var pollingTimer: Timer?
    private var lastMoveCount: Int = 0
    private var backoffDelay: TimeInterval = 1.0
    private var pollingInterval: TimeInterval = 1.0
    private var isThrottled: Bool = false

    // Reference to OGSClient
    private let ogsClient: OGSClient

    // Functions to extract:
    func loadGame(gameID: Int)
    func startPolling(gameID: Int)
    func stopPolling()
    func handleGameData(_ data: [String: Any])
    func handleMove(_ data: [String: Any])
    func handlePlayerInfo(_ data: [String: Any])
    func handleThrottling()
}
```

**ContentView3D changes:**
```swift
// Before:
@State private var ogsBlackName: String?
@State private var ogsWhiteName: String?
// ... 8 more OGS state variables

// After:
@StateObject private var ogsGame = OGSGameViewModel(client: ogsClient)

// Before: 150 lines of OGS handling code
// After: ogsGame.loadGame(gameID)
```

**Step-by-step plan:**
1. Create `SGFPlayer3D/ViewModels/OGSGameViewModel.swift`
2. Copy OGS state variables from ContentView3D
3. Copy OGS functions: `handleOGSGameData`, `handleOGSMove`, `handleOGSPlayerInfo`, `handleThrottling`, `startOGSPolling`, `stopOGSPolling`
4. Update ContentView3D to use `@StateObject var ogsGame`
5. Update notification handlers to call `ogsGame.handleX()`
6. Test game loading and switching
7. Build and verify

**Files to create/modify:**
- NEW: `SGFPlayer3D/ViewModels/OGSGameViewModel.swift` (~300 lines)
- MODIFY: `ContentView3D.swift` (remove ~200 lines)

**Success criteria:**
- ✅ Game loading still works
- ✅ Game switching still works
- ✅ Polling still works
- ✅ Player info displays correctly
- ✅ Build succeeds with no warnings

---

### 📋 Phase 3: Split ContentView3D into Components (PLANNED)
**Status**: After Phase 2
**Target**: Reduce ContentView3D to ~500 lines
**Estimated time**: 2-3 hours

**Components to extract:**

#### 3A: GameInfoOverlay.swift (~150 lines)
Extract lines 441-582 of ContentView3D:
- Player names and ranks
- Time remaining display
- Captures display
- Komi and ruleset
- Move counter

```swift
struct GameInfoOverlay: View {
    @ObservedObject var ogsGame: OGSGameViewModel
    @ObservedObject var timeControl: TimeControlManager
    @ObservedObject var player: SGFPlayer

    var body: some View {
        VStack(alignment: .trailing) {
            // Player info
            // Time display
            // Captures
            // Komi/Rules
            // Move counter
        }
    }
}
```

#### 3B: PlaybackControls.swift (~100 lines)
Extract lines 607-656 of ContentView3D:
- Play/pause button
- Forward/backward buttons
- Seek slider

```swift
struct PlaybackControls: View {
    @ObservedObject var player: SGFPlayer
    @Binding var isPlaying: Bool
    let onSeek: (Int) -> Void

    var body: some View {
        HStack {
            Button(action: backward) { ... }
            Button(action: playPause) { ... }
            Button(action: forward) { ... }
            Slider(...)
        }
    }
}
```

#### 3C: SettingsPanelContainer.swift (~50 lines)
Extract lines 389-415 of ContentView3D:
- Settings panel presentation
- Background overlay

```swift
struct SettingsPanelContainer: View {
    @Binding var showSettings: Bool
    @EnvironmentObject var app: AppModel
    @ObservedObject var player: SGFPlayer
    // ... other dependencies

    var body: some View {
        HStack {
            SettingsPanelView3D(...)
            Spacer()
        }
    }
}
```

**ContentView3D after Phase 3:**
```swift
struct ContentView3D: View {
    // StateObjects
    @StateObject private var sceneManager = SceneManager3D()
    @StateObject private var timeControl = TimeControlManager()
    @StateObject private var ogsGame: OGSGameViewModel

    var body: some View {
        ZStack {
            sceneView

            if showSettings {
                SettingsPanelContainer(...)
            }

            VStack {
                topBar
                Spacer()
                GameInfoOverlay(...)
                PlaybackControls(...)
            }
        }
    }
}
```

**Files to create:**
- NEW: `SGFPlayer3D/Views/GameInfoOverlay.swift`
- NEW: `SGFPlayer3D/Views/PlaybackControls.swift`
- NEW: `SGFPlayer3D/Views/SettingsPanelContainer.swift`
- MODIFY: `ContentView3D.swift` (reduce by ~300 lines → ~1000 lines total)

---

### 📋 Phase 4: Board Interaction Manager (PLANNED)
**Status**: Before implementing click-to-play
**Estimated time**: 2-3 hours

**Goal**: Add ability to detect clicks on board and validate moves

**Create BoardInteractionManager.swift:**
```swift
class BoardInteractionManager: ObservableObject {
    @Published var previewStone: BoardPosition?
    @Published var previewColor: Stone = .black
    @Published var selectedIntersection: BoardPosition?

    private let sceneManager: SceneManager3D
    private let player: SGFPlayer

    // Raycast from screen point to board intersection
    func handleClick(at point: CGPoint, in sceneView: SCNView) -> BoardPosition?

    // Check if move is legal (no suicide, no ko)
    func isLegalMove(at position: BoardPosition, color: Stone) -> Bool

    // Show ghost stone preview
    func showPreview(at position: BoardPosition, color: Stone)
    func clearPreview()

    // Convert between screen and board coordinates
    func screenToBoard(point: CGPoint, sceneView: SCNView) -> BoardPosition?
}
```

**Enhance SceneManager3D:**
```swift
// Add to SceneManager3D:
func addPreviewStone(at: BoardPosition, color: Stone)
func removePreviewStone()
func highlightIntersection(at: BoardPosition)
func clearHighlight()
```

**Files to create/modify:**
- NEW: `SGFPlayer3D/Managers/BoardInteractionManager.swift` (~200 lines)
- MODIFY: `SceneManager3D.swift` (+100 lines for preview/highlight)

---

### 📋 Phase 5: Game State Manager (FUTURE)
**Status**: Before implementing move submission
**Estimated time**: 3-4 hours

**Goal**: Manage local game state independent of network

This is needed when:
- User plays a move (update local board immediately)
- Network is slow (optimistic updates)
- Undo/redo functionality
- Analysis mode (local variations)

**Create GameStateManager.swift:**
```swift
class GameStateManager: ObservableObject {
    @Published var localBoard: Board
    @Published var moveHistory: [Move]
    @Published var pendingMove: Move?

    func applyMove(x: Int, y: Int, color: Stone) -> Bool
    func undoLastMove()
    func redoMove()
    func generateSGF() -> String
    func enterAnalysisMode()
    func exitAnalysisMode()
}
```

---

### 📋 Phase 6: Game Control Buttons (FUTURE)
**Status**: After Phase 4 (interaction working)
**Estimated time**: 2-3 hours

**Create GameControlButtons.swift:**
```swift
struct GameControlButtons: View {
    let onPass: () -> Void
    let onResign: () -> Void
    let onRequestAnalysis: () -> Void
    let onScoreEstimate: () -> Void

    @ObservedObject var ogsGame: OGSGameViewModel

    var body: some View {
        HStack {
            Button("Pass") { onPass() }
            Button("Resign") { onResign() }
            // ...
        }
    }
}
```

**Add to OGSGameViewModel:**
```swift
func submitMove(x: Int, y: Int)
func pass()
func resign()
func requestAnalysis()
```

---

### 📋 Phase 7: Game Finder (FUTURE)
**Status**: Major feature addition
**Estimated time**: 5-6 hours

Create UI for finding and starting games:
- Quick match button
- Custom game dialog
- Open games list
- Challenge system

**Files to create:**
- `Views/GameFinderView.swift`
- `Views/CustomGameDialog.swift`
- `Views/OpenGamesList.swift`
- `Models/GameSettings.swift`
- `Models/Challenge.swift`

---

### 📋 Phase 8: Chat & Communication (FUTURE)
**Status**: After Phase 7
**Estimated time**: 4-5 hours

**Files to create:**
- `Views/ChatPanel.swift`
- `ViewModels/ChatViewModel.swift`
- Enhance OGSClient for chat messages

---

## Progress Tracker

### Completed
- [x] **Phase 1**: TimeControlManager extraction (v3.26)
  - Commit: 8b1f1e0
  - Date: 2025-10-16
  - Files: +2 new, 2 modified
  - Lines: +442, -21

### In Progress
- [ ] **Phase 2**: OGSGameViewModel extraction
  - Status: Starting
  - Branch: layout-refactor-option-a
  - Expected completion: [Date TBD]

### Planned (Not Started)
- [ ] **Phase 3**: Split ContentView3D components
- [ ] **Phase 4**: Board Interaction Manager
- [ ] **Phase 5**: Game State Manager
- [ ] **Phase 6**: Game Control Buttons
- [ ] **Phase 7**: Game Finder
- [ ] **Phase 8**: Chat System

### Future (Not Planned Yet)
- Tournament support
- Teaching features
- Conditional moves
- Advanced analysis tools

---

## Recovery Instructions

### If Session is Interrupted

#### Step 1: Check Status
```bash
cd "/Users/Dave/Go/SGFPlayer Code/SGFPlayer3D"

# Check git status
git status
git log --oneline -5

# Check branch
git branch

# Read this file
cat ARCHITECTURE_PLAN.md
cat REFACTORING_STATUS.md  # For detailed Phase 1 notes
```

#### Step 2: Identify Current Phase
Look at the **Progress Tracker** section above to see:
- What phases are completed
- What phase is "In Progress"
- Last commit message and date

#### Step 3: Check for Uncommitted Work
```bash
# See what files have changes
git status

# See the actual changes
git diff

# Check if changes compile
xcodebuild -project SGFPlayer3D.xcodeproj -scheme SGFPlayer3D -configuration Debug build
```

#### Step 4: Decision Tree

**If changes compile and tests pass:**
1. Review the changes with `git diff`
2. Check against the current phase goals (see above)
3. If goals are met: Complete the phase, commit, move to next phase
4. If goals not met: Continue working on current phase

**If changes don't compile or are broken:**
1. Review `git diff` to see what was attempted
2. Options:
   - Fix the compilation errors and continue
   - Revert with `git restore .` and restart the phase
   - Commit work-in-progress with `git stash` and start fresh

**If no uncommitted changes:**
1. Look at last commit message
2. Check Progress Tracker to see what phase was completed
3. Start the next phase in sequence

#### Step 5: Resume Work
Based on the current phase, follow the detailed step-by-step plan in that phase's section above.

---

## Design Decisions

### Why MVVM?
- Clear separation: View logic vs. business logic
- Testability: ViewModels can be unit tested without UI
- SwiftUI compatibility: Works naturally with @Published and @ObservableObject

### Why Extract OGSGameViewModel First?
- Biggest impact on ContentView3D size
- OGS logic is complex and growing
- Needed before adding game management features

### Why Extract UI Components Third (Not Second)?
- UI components are easier to extract than business logic
- Business logic (OGSGameViewModel) is more critical for future features
- Can live with large ContentView3D temporarily, but not with tangled state

### Why BoardInteractionManager as Separate Class?
- Board interaction is complex (raycasting, coordinate conversion)
- Will be reused by analysis mode, teaching mode
- SceneManager3D should only handle rendering, not input

### Why Keep OGSClient Separate?
- Networking is a distinct concern
- Already well-structured at 1,200 lines
- Stable - not changing much

---

## Build & Test Commands

```bash
# Full clean build
cd "/Users/Dave/Go/SGFPlayer Code/SGFPlayer3D"
xcodebuild -project SGFPlayer3D.xcodeproj -scheme SGFPlayer3D -configuration Debug clean build

# Quick build (incremental)
xcodebuild -project SGFPlayer3D.xcodeproj -scheme SGFPlayer3D -configuration Debug build

# Run the app
open "/Users/dave/Library/Developer/Xcode/DerivedData/SGFPlayer3D-clytobqxdmoqeccwzekaxegwfyjh/Build/Products/Debug/SGFPlayer3D.app"

# Check for errors
git status
git diff

# View architecture plan
cat ARCHITECTURE_PLAN.md | less
```

---

## Version History

- **v1.0** (2025-10-16): Initial architecture plan created
  - Documented current state (v3.26)
  - Defined target architecture
  - Planned 8 refactoring phases
  - Created recovery instructions

---

## Notes for Future Developers

### Things That Work Well (Don't Break These)
- WebSocket connection to OGS
- Authentication with keychain storage
- 3D board rendering with SceneKit
- Camera controls (rotate, zoom, pan)
- Stone jitter and placement
- TimeControlManager (Phase 1)

### Known Issues to Be Aware Of
- WebSocket clock events not being received (using REST polling instead)
- Need to manually stop polling timer when switching games
- SceneManager3D has some collision detection code that may need refinement

### Performance Considerations
- Keep 3D rendering at 60fps
- Board updates should be smooth (use animations)
- Don't block main thread with heavy computations
- Consider using background queue for SGF parsing

### Testing Strategy
After each phase:
1. Build succeeds without warnings
2. Can load an OGS game
3. Can switch between multiple games
4. Clock countdown works
5. 3D rendering is smooth
6. No memory leaks (use Instruments if unsure)

---

**End of Architecture Plan v1.0**
