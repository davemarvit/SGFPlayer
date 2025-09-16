# SGF Player Testing Knowledge Base

## Overview
This document captures all discovered bugs, failure modes, and testing requirements to maximize autonomous development and prevent regressions.

## Critical Test Coverage Areas

### 1. SGF File Loading & Parsing
**Test Cases:**
```swift
func testSGFParsingBasicGame()
func testSGFParsingWithSetupStones()
func testSGFParsingWithCapturesAndKo()
func testSGFParsingWithComments()
func testSGFParsingWithVariations()
func testSGFParsingWithInvalidMoves()
func testSGFParsingWithEmptyFile()
func testSGFParsingWithCorruptedFile()
```

**Known Issues/Edge Cases:**
- Files with non-standard SGF properties
- Games with setup stones (AB/AW properties)
- Coordinate systems (SGF uses letter coordinates)
- Pass moves represented as empty coordinates

### 2. Game Playback Engine
**Test Cases:**
```swift
func testGamePlaybackFromBeginning()
func testGamePlaybackStepForward()
func testGamePlaybackStepBackward()
func testGamePlaybackSeekToMove()
func testGamePlaybackAutoPlay()
func testGamePlaybackPauseResume()
func testGamePlaybackEndOfGame()
```

**Known Issues:**
- Arrow key navigation stops autoplay but icon doesn't update (FIXED in Working Version 1)
- Seeking during autoplay can cause timer conflicts

### 3. Board State & Rules
**Test Cases:**
```swift
func testBoardInitialization()
func testStoneCaptures()
func testKoRule()
func testSuicideRule()
func testTerritoryCalculation()
func testCaptureCountAccuracy()
```

**Known Issues:**
- Complex capture scenarios need validation
- Ko rule implementation correctness
- Territory scoring algorithms

### 4. UI Rendering & Display
**Test Cases:**
```swift
func testHoshiPointsPositioning()
func testStoneRenderingOnIntersections()
func testBoardScalingAndAspectRatio()
func testPhysicsVisualization()
func testUIStateConsistency()
```

**Known Issues:**
- Hoshi points ForEach ID collision (FIXED in Working Version 1)
- Z-ordering of stones vs star points
- Hit-testing conflicts preventing UI interaction

### 5. Physics Integration
**Test Cases:**
```swift
func testPhysicsModelSwitching()
func testStonePhysicsPositioning()
func testPhysicsParameterChanges()
func testPhysicsPerformance()
```

**Known Issues:**
- Multiple physics integration approaches causing confusion
- Performance with large numbers of stones
- Physics state synchronization with game state

### 6. Settings & Persistence
**Test Cases:**
```swift
func testSettingsPersistence()
func testPhysicsParameterStorage()
func testGameSelectionPersistence()
func testFolderSelectionMemory()
```

**Known Issues:**
- Settings scattered across multiple storage mechanisms
- AppStorage synchronization timing

### 7. File System Integration
**Test Cases:**
```swift
func testFolderSelectionAndScanning()
func testSGFFileDetection()
func testFileSystemPermissions()
func testLargeDirectoryPerformance()
```

**Known Issues:**
- Sandboxing permissions on macOS
- Performance with large SGF collections

## Manual Testing Checklist

### Core Functionality
- [ ] Load SGF folder and see game list
- [ ] Select game and see board display
- [ ] Use arrow keys for navigation
- [ ] Test autoplay start/stop
- [ ] Verify capture counts display
- [ ] Test physics visualization
- [ ] Open/close settings panel
- [ ] Modify physics parameters
- [ ] Test fullscreen mode

### Edge Cases
- [ ] Load empty SGF file
- [ ] Load corrupted SGF file
- [ ] Load very large game (500+ moves)
- [ ] Test with handicap games
- [ ] Test with games containing variations
- [ ] Navigate very quickly through moves
- [ ] Change physics model during playback

## Regression Prevention

### Key Areas to Monitor
1. **UI State Synchronization** - Autoplay icon, move counters, capture counts
2. **Performance** - Large files, complex physics, rapid navigation
3. **Visual Rendering** - Hoshi points, stone positions, board scaling
4. **Input Handling** - Arrow keys, mouse clicks, settings changes

### Automated Test Strategy
- Unit tests for all business logic (domain models, game rules)
- Integration tests for file loading and game engine
- UI tests for critical user flows
- Performance benchmarks for large games

## Bug Discovery Log

### Bugs Found and Fixed
1. **Hoshi Points Rendering (2025-09-16)**
   - Issue: Only 3 of 9 star points visible
   - Cause: ForEach ID collision using only x-coordinate
   - Fix: Use enumerated array with unique offset identifiers
   - Test Added: `testHoshiPointsRendering()`

2. **Autoplay Icon Sync (2025-09-16)**
   - Issue: Icon doesn't update when arrow keys stop autoplay
   - Cause: Arrow keys call seek() which pauses timer, but UI state not updated
   - Fix: Set autoNext = false in arrow key handlers
   - Test Added: `testAutoplayIconSync()`

### Active Bugs
- None currently known

### Suspected Issues (Need Investigation)
- Physics performance with 300+ stones
- Memory usage with large SGF collections
- Settings panel layout on small screens

## Test Implementation Status

### Implemented Tests
- [✅] **Core domain model tests (Session 1)** - 30 comprehensive unit tests
  - Stone enum (opposite, SGF codes, descriptions)
  - Position struct (creation, SGF coordinates, validation, neighbors)
  - Move/MoveAction (creation, pass moves, legacy conversion)
  - MoveSequence (adding moves, subscript access)
  - Board (stone placement, groups, liberties, captures, rule application)
  - Game (creation, board state progression, navigation)
  - GameState (navigation, progress tracking, move references)
  - Performance tests (large games, group detection)
- [ ] SGF parsing tests (partial - included in domain tests)
- [ ] Game playback tests
- [ ] UI rendering tests

### Next Priority Tests
1. Board rules and capture logic
2. Physics integration
3. Settings persistence
4. File system integration

## Automation Targets

As refactoring progresses, aim for:
- 90%+ unit test coverage for business logic
- Key user flow integration tests
- Automated regression testing
- Performance benchmarks