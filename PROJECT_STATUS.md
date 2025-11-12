# SGFPlayer Project Status

**Last Updated:** 2025-11-12
**Current Branch:** `claude/fix-phantom-stones-display-011CV2iu1sEoATxcvodkPs2J`
**Project Version:** 3.86+ (Post-WebSocket migration)

---

## Current Status

### Active Task
Repository reorganization completed. Ready for next development phase.

### Recent Changes
- **2025-11-12**: Reorganized repository structure, moved experimental projects to `_archived/`
- **2025-11-11**: Fixed phantom stones display issues in 2D and 3D modes
- **2025-11-11**: Converted from Socket.io to plain WebSocket protocol (v3.86)
- **2025-11-11**: Fixed challenge keep-alive timer threading issue

---

## Project Architecture

### Main Application Structure
```
SGFPlayer/
├── SGFPlayer/                      # Main app source
│   ├── SGFPlayerApp.swift         # App entry point
│   ├── AppModel.swift             # Central app state, file management
│   ├── ContentView.swift          # Main UI (needs refactoring - 694 lines)
│   │
│   ├── ViewModels/                # MVVM Architecture (partially implemented)
│   │   ├── SGFPlayerViewModel.swift    # Game playback control
│   │   ├── SettingsViewModel.swift     # User preferences
│   │   ├── UIStateViewModel.swift      # Window/UI state
│   │   └── PhysicsViewModel.swift      # Stone positioning
│   │
│   ├── Views/                     # UI Components
│   │   ├── GameBoardView.swift        # 2D board rendering
│   │   ├── SettingsPanelView.swift    # Settings panel (764 lines - needs refactoring)
│   │   └── [other view files]
│   │
│   ├── Physics/                   # Stone positioning system
│   │   ├── PhysicsEngine.swift        # Strategy pattern engine
│   │   ├── SpiralPhysicsModel.swift
│   │   ├── GroupDropPhysicsModel.swift
│   │   └── EnergyMinimizationModel.swift
│   │
│   ├── Integration/               # Legacy compatibility layer
│   │   ├── PhysicsIntegration.swift   # Bridge to new physics
│   │   └── CompatibilityLayer.swift
│   │
│   ├── Models/                    # Data models
│   │   ├── GameStateCache.swift
│   │   └── LastMoveIndicatorStyle.swift
│   │
│   └── ARCHITECTURE.md            # Detailed architecture documentation
│   └── REFACTORING_PROGRESS.md    # Refactoring status
│
├── SGFPlayerScreensaver/          # Screensaver target
└── Sources/                       # Shared packages
    └── GoCore/                    # Domain models package
        └── Domain/
            ├── Game.swift
            ├── Board.swift
            ├── Move.swift
            ├── Stone.swift
            └── SGFParser.swift
```

---

## Key Components & File Locations

### Core Game Engine
- **SGFPlayerEngine.swift**: `SGFPlayer/SGFPlayer/SGFPlayerEngine.swift`
  - Functions: `loadGame()`, `stepForward()`, `stepBackward()`, `play()`, `pause()`
  - Manages game state, move execution, capture logic

### Application State Management
- **AppModel.swift**: `SGFPlayer/SGFPlayer/AppModel.swift`
  - Functions: `promptForFolder()`, `selectGame()`, `loadGames()`
  - Manages SGF file discovery, game library, security-scoped bookmarks

### 2D Board Rendering
- **GameBoardView.swift**: `SGFPlayer/SGFPlayer/Views/GameBoardView.swift`
  - Functions: Board grid rendering, stone placement, coordinate conversion
  - Renders 2D board with captured stones in bowls

### Physics System
- **PhysicsEngine.swift**: `SGFPlayer/SGFPlayer/Physics/PhysicsEngine.swift`
  - Functions: `computeStonePositions()`, model switching
  - Three models: Spiral (fast), GroupDrop (balanced), EnergyMinimization (realistic)

### Physics Integration Layer
- **PhysicsIntegration.swift**: `SGFPlayer/SGFPlayer/Integration/PhysicsIntegration.swift`
  - Functions: `updateStonePositions()`, `setBowlPositions()`
  - Bridges legacy and new physics systems

### OGS Client (Live Play)
- **OGSClient.swift**: `SGFPlayer/SGFPlayer/OGSClient.swift`
  - Functions: WebSocket connection, authentication, game synchronization
  - Real-time game updates from Online-Go.com

### ViewModels (MVVM Refactoring)
- **SGFPlayerViewModel.swift**: Game loading, playback, move navigation
- **UIStateViewModel.swift**: Window state, fullscreen, mouse tracking
- **PhysicsViewModel.swift**: Physics model selection, layout caching
- **SettingsViewModel.swift**: User preferences, physics parameters

---

## Bug Tracking

### Active Bugs
None currently known.

### Recently Fixed Bugs

#### Bug #1: Phantom Stones Display (FIXED - 2025-11-11)
**Description**: Extra stones appearing in bowls when navigating moves
**Location**: `PhysicsIntegration.swift`, `GameBoardView.swift`
**Root Cause**: Incorrect `gamePhase` and `playerColor` parameters passed to bowl physics

**Attempts**:
1. ❌ Modified stone counting logic - didn't address root cause
2. ❌ Adjusted bowl physics calculations - stones still appeared incorrectly
3. ✅ **Fixed by correcting gamePhase and playerColor parameters**

**Solution** (Commit: 1cd5c39):
- Updated `PhysicsIntegration.swift:142-152` to use `nextToPlayStone` for correct player color
- Set `gamePhase` to `.endgame` during move playback
- Modified `updateForCurrentMove()` to pass correct parameters to bowl rendering

**Files Modified**:
- `SGFPlayer/SGFPlayer/Integration/PhysicsIntegration.swift`
- `SGFPlayer/SGFPlayer/Views/GameBoardView.swift`

---

#### Bug #2: Challenge Keep-Alive Timer Threading Issue (FIXED - 2025-11-11)
**Description**: Timer-related crashes in challenge management
**Location**: OGS challenge handling code
**Root Cause**: Timer access from wrong thread

**Solution** (Commit: 02c3d75):
- Added proper thread safety for timer operations

**Files Modified**:
- OGS challenge management code

---

#### Bug #3: WebSocket Protocol Migration (COMPLETED - 2025-11-11)
**Description**: Needed to migrate from Socket.io to plain WebSocket protocol
**Location**: `OGSClient.swift`
**Implementation**: v3.86 (Option B)

**Solution** (Commit: 6ff61a2):
- Replaced Socket.io with native URLSessionWebSocketTask
- Implemented custom Socket.io protocol encoding/decoding
- Maintained backward compatibility with OGS API

**Files Modified**:
- `SGFPlayer/SGFPlayer/OGSClient.swift`

---

### Historical Issues (Pre-Refactoring)

#### Known Technical Debt
1. **ContentView.swift God Object** (694 lines, 26+ @State properties)
   - Status: Partially addressed with ViewModel extraction
   - Next: Complete ViewModel integration

2. **SettingsPanelView.swift Monolith** (764 lines)
   - Status: Not yet refactored
   - Plan: Extract into smaller components

3. **Mixed Responsibilities**
   - Physics integration spread across multiple files
   - Some business logic still in views

---

## Testing & Validation

### Test Locations
- Unit Tests: `SGFPlayer/Sources/GoCore/Tests/`
- Integration Tests: (To be added)

### Manual Testing Checklist
- [ ] Load SGF file and verify board display
- [ ] Navigate moves forward/backward
- [ ] Check captured stones in bowls (no phantom stones)
- [ ] Test physics model switching
- [ ] Verify autoplay functionality
- [ ] Test fullscreen mode
- [ ] Check settings panel
- [ ] Verify OGS live game connection (if applicable)

---

## Development Guidelines

### Before Making Changes
1. Read `ARCHITECTURE.md` for system design
2. Read `REFACTORING_PROGRESS.md` for current refactoring status
3. Check this file for known bugs and recent changes

### After Fixing a Bug
1. Update this document with:
   - Bug description and location
   - Root cause analysis
   - All attempts made (successful and failed)
   - Final solution and commit hash
   - Files modified
2. Run manual testing checklist
3. Commit with clear message referencing bug number

### Commit Message Format
```
[Category]: Brief description

Detailed explanation of changes.

Fixes Bug #N
Files: list of modified files
```

Categories: Fix, Feature, Refactor, Docs, Test

---

## Next Steps / Roadmap

### Immediate Tasks
1. Continue MVVM refactoring (Session 3)
   - Complete ViewModel integration in ContentView
   - Reduce ContentView from 694 lines to ~200 lines
   - Remove remaining @State properties

2. Refactor SettingsPanelView
   - Break into smaller components
   - Extract settings sections

### Future Enhancements (from ARCHITECTURE.md)
1. OGS Client replacement with video conferencing
2. 3D board visualization improvements
3. AI integration (KaTrain-style analysis)
4. Cross-platform migration (iOS, Android, Windows)

---

## Dependencies

### Swift Packages
- GoCore (local package): Domain models for Go game logic

### System Requirements
- macOS 12.0+
- Xcode 14.0+
- Swift 5.7+

### External Services
- OGS (Online-Go.com) API for live games

---

## Notes

### Repository Reorganization (2025-11-12)
Moved experimental projects to `_archived/`:
- OGS-Client (web client)
- SGFPlayer3D (3D version with more features)
- RealityKitStoneTest
- SGFTests
- UnityGoStoneTest

Main SGFPlayer app remains in `SGFPlayer/` directory.

### Important Files
- **ARCHITECTURE.md**: Complete system architecture documentation
- **REFACTORING_PROGRESS.md**: Detailed refactoring status and strategy
- **PROJECT_STATUS.md**: This file - running project status

---

**Last Commit**: da625fd - "Reorganize repository: Move non-essential files to _archived/"
