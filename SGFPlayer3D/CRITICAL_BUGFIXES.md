# Critical Bug Fixes - Stone Disappearing Issue

## Session: November 2025 - Phantom Stone Preview Implementation

### Bug: Stones Disappearing from Board During OGS Gameplay

**Severity:** CRITICAL - All stones would vanish from the board during active games

**User Report:** "the board suddenly went blank - all of the stones vanished!"

---

## Root Causes Identified and Fixed

### 1. WebSocket Reconnect Clearing Board (PRIMARY CAUSE)

**Commit:** `8483592` - "Fix critical bug: stones disappearing when WebSocket reconnects"

**Problem:**
When the WebSocket connection timed out (after idle periods) and automatically reconnected, the code was clearing the entire board even during active games.

**Evidence from Logs:**
```
✅ Successfully connected to WebSocket (reconnect counter reset)
ContentView: 🔌 OGS connected - clearing local game selection and clearing board
🎨 GAMESTONES BODY - totalStones: 0, grid[0][0]: nil
```

**Files Modified:**
- `ContentView3D.swift:301-315`
- `ContentView.swift:355-366`

**The Bug:**
```swift
.onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OGSConnected"))) { _ in
    player.clear()  // ← This cleared ALL stones on every connection!
    ogsClient.currentGameID = nil  // ← This cleared active game tracking!
}
```

**The Fix:**
```swift
.onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OGSConnected"))) { _ in
    if ogsClient.currentGameID == nil {
        // Initial connection - clear board (correct)
        player.clear()
    } else {
        // Reconnect during active game - preserve board state
        NSLog("OGS reconnected during active game - preserving board state")
    }
}
```

**Result:** Board state now preserved during WebSocket reconnects

---

### 2. Physics Bowl Clearing on Valid Game State

**Commit:** `57a7487` - "Fix critical bug: stones disappearing when no captures exist"

**Problem:**
StonePositionViewModel was clearing bowl stones whenever BOTH capture counts were 0, which is a VALID game state (most games have no captures for many moves). This triggered SwiftUI rendering corruption.

**Files Modified:**
- `StonePositionViewModel.swift:82-98`

**The Bug:**
```swift
if currentMove == 0 || (blackStoneCount == 0 && whiteStoneCount == 0) {
    // This cleared on EVERY move with no captures!
    blackStonePositions.removeAll()
    whiteStonePositions.removeAll()
}
```

**The Fix:**
```swift
// Only clear on move 0. Zero captures is perfectly normal!
if currentMove == 0 {
    blackStonePositions.removeAll()
    whiteStonePositions.removeAll()
}
```

**Evidence from Logs:**
```
🔍 SEEK: Final currentIndex: 38, board stones: 38  ← Board loaded successfully
🎮 UpdatePhysics for move 38: Black captured: 0, White captured: 0
🔄 ViewModel: Force clearing stones for move 38, counts: B=0, W=0  ← BUG!
⚠️ GAMESTONES BODY - totalStones: 38, grid[0][0]: nil  ← Grid corrupted
```

---

### 3. Polling Never Stops for Finished Games

**Commit:** `537facd` - "Add defensive logic to prevent stones disappearing in finished games"

**Problem:**
Polling continued indefinitely even after games finished, causing repeated reloads that could corrupt state.

**Files Modified:**
- `OGSGameViewModel.swift:206-217`

**The Fix:**
```swift
let gamePhase = gameData["phase"] as? String ?? "unknown"
if gamePhase == "finished" {
    NSLog("Game is FINISHED - NOT restarting polling")
} else {
    startPolling(gameID: gameID)
}
```

**Result:** Completed games no longer continuously polled, reducing unnecessary reloads

---

### 4. Defensive Validation Against Corrupted Server Data

**Commit:** `537facd` (same commit as #3)

**Problem:**
If server sent corrupted data (0 moves) for an active game, the code would blindly reload and clear the board.

**Files Modified:**
- `OGSGameViewModel.swift:59-66`

**The Fix:**
```swift
// Validate before reload
if moves.isEmpty && player.currentIndex > 0 {
    NSLog("DEFENSIVE: Server sent 0 moves but board has stones!")
    NSLog("DEFENSIVE: Refusing to reload - this would clear all stones!")
    return
}
```

**Result:** Safety net against server glitches clearing valid board state

---

### 5. Enhanced Logging for Diagnosis

**Commit:** `537facd` (same commit)

**Files Modified:**
- `SGFPlayerEngine.swift:37-49`

**Added Logging:**
```swift
func load(game: SGFGame) {
    print("🔍 LOAD: Previous state: \(prevMoveCount) moves, \(prevStoneCount) stones")
    print("🔍 LOAD: New state: \(game.moves.count) moves")

    if game.moves.isEmpty && prevMoveCount > 0 {
        print("⚠️⚠️⚠️ WARNING: Loading 0 moves over board with stones!")
        print("⚠️⚠️⚠️ Call stack: \(Thread.callStackSymbols)")
    }
}
```

**Result:** Makes it easy to diagnose future issues with detailed logging

---

### 6. Compiler Timeout Fix

**Commit:** `222edc5` - "Fix compiler timeout by breaking up complex ZStack in ContentView"

**Problem:**
Complex ZStack with many overlays caused Swift compiler to timeout during type-checking.

**Files Modified:**
- `ContentView.swift:149-184`

**The Fix:**
Extracted overlays into separate `overlaysGroup` property to reduce complexity:
```swift
private var overlaysGroup: some View {
    Group {
        topButtonsOverlay
        settingsPanelOverlay
        // ... other overlays
    }
}

var body: some View {
    ZStack {
        mainGameContent
        overlaysGroup  // ← Simplified
    }
}
```

---

## Supporting Features Added

### Optimistic Stone Placement

**Commit:** `2039996` - "Implement optimistic stone placement for instant visual feedback"

**Problem:**
Waiting for server confirmation before placing stones caused 100-500ms delay, breaking the tactile feel of placing stones.

**Files Modified:**
- `SGFPlayerEngine.swift:46-61` - Added `playMoveOptimistically()`
- `SimpleBoardView.swift:703-712` - 2D click handler
- `ContentView3D.swift:987-993` - 3D click handler

**The Fix:**
Place stone IMMEDIATELY on click, send to server in background. Server response auto-corrects if move was rejected (rare).

**Result:** Zero-delay stone placement for natural gameplay feel

---

## Testing Results

**Test Duration:** 20+ minutes of idle gameplay including game ending via timeout

**Results:**
- ✅ Stones remained stable during entire session
- ✅ Board preserved through WebSocket reconnects
- ✅ Game ending did not clear board
- ✅ No stone disappearing issues observed

---

## Build Information

**Build Number:** Incremented from 1 → 2 for verification
**Commit:** `2960d12` - "Increment build number to 2 to verify defensive fixes are running"

---

## How to Verify Fixes Are Active

Check logs for these messages:

**WebSocket Reconnect (should preserve board):**
```
🔌 OGS reconnected during active game X - preserving board state
🔌 Board has Y moves - NOT clearing!
```

**Finished Game (should stop polling):**
```
🏁 Game is FINISHED - NOT restarting polling
🏁 Board will remain stable with final position
```

**Defensive Validation (if server sends bad data):**
```
⚠️ DEFENSIVE: Refusing to reload - this would clear all stones!
```

---

## Potential Future Issues

If stones disappear again, check logs for:

1. **Missing new logs?** Old build running - verify Build 2+
2. **Different code path?** New logs will pinpoint the culprit
3. **New server behavior?** Defensive validation will catch it

---

## Summary

The stone disappearing bug had **multiple root causes**:
1. **Primary:** WebSocket reconnects clearing board (FIXED)
2. **Secondary:** Physics clearing on valid 0-capture state (FIXED)
3. **Tertiary:** Continuous polling of finished games (FIXED)

All causes addressed with defensive coding, enhanced logging, and proper state preservation during network events.

**Status:** ✅ RESOLVED - 20+ minutes stable testing with no issues
