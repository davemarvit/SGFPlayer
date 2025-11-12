# Phantom Stone Display Fixes - Applied

## Date: 2025-11-12

## Issues Fixed

### 1. No Phantom Stone During SGF Playback
**Problem:** Phantom stones only appeared during live OGS games, not when viewing SGF files.

**Root Cause:** Both 2D and 3D modes had guards checking `ogsClient.isMyTurn && ogsClient.gamePhase == .playing` before showing phantom stones.

**Solution:** Removed these guards from the hover/mouse move handlers. Phantom stones now appear whenever the user hovers over an empty intersection, regardless of whether it's a live game or SGF playback.

### 2. Wrong Color Phantom Stone
**Problem:** The phantom stone showed the wrong color (e.g., white dot when black should play).

**Root Cause:** The code used `ogsClient.playerColor` (the player's assigned color in a live OGS game) instead of `ogsClient.currentPlayerColor` (whose turn it currently is).

**Solution:** Changed all phantom stone color determinations to use `ogsClient.currentPlayerColor`.

## Files Modified

### 1. BoardInteractionOverlay.swift (2D Mode)
**Location:** `/SGFPlayer3D/SGFPlayer3D/Views/BoardInteractionOverlay.swift`

**Changes:**
- Line 66-67: Removed OGS-only guard, added comment explaining phantom stones show always
- Line 47-49: Simplified phantom stone rendering condition (removed OGS checks)
- Line 162-166: Changed from `ogsClient.playerColor ?? .black` to `ogsClient.currentPlayerColor`

**Key Code Changes:**
```swift
// BEFORE:
guard ogsClient.isMyTurn, ogsClient.gamePhase == .playing else {
    phantomStonePosition = nil
    return
}

// AFTER:
// ALWAYS show phantom stone on hover (even during SGF playback)
// This provides visual feedback for where a stone would be placed
```

```swift
// BEFORE:
let stoneColor = ogsClient.playerColor ?? .black

// AFTER:
let stoneColor = ogsClient.currentPlayerColor
```

### 2. ContentView3D.swift (3D Mode)
**Location:** `/SGFPlayer3D/SGFPlayer3D/ContentView3D.swift`

**Changes:**
- Line 822-823: Removed OGS-only guard, added comment
- Line 831-834: Changed from `ogsClient.playerColor ?? .black` to `ogsClient.currentPlayerColor`

**Key Code Changes:**
```swift
// BEFORE:
guard ogsClient.isMyTurn, ogsClient.gamePhase == .playing else {
    sceneManager.hidePhantomStone()
    phantomStonePosition = nil
    return
}
let stoneColor = ogsClient.playerColor ?? .black

// AFTER:
// ALWAYS show phantom stone on hover (even during SGF playback)
// This provides visual feedback for where a stone would be placed
let stoneColor = ogsClient.currentPlayerColor
```

## Behavior Changes

### Before Fixes:
1. **SGF Playback:** No phantom stone appeared when hovering over the board
2. **Live OGS Games:** Phantom stone appeared, but showed wrong color if player was assigned white
3. **Mouse Down:** In 2D mode, white dot appeared even when black's turn

### After Fixes:
1. **SGF Playback:** Phantom stone appears on hover, showing the correct color for whose turn it is
2. **Live OGS Games:** Phantom stone appears with correct color (whose turn, not player's assigned color)
3. **Mouse Down:** Correct color stone appears (slightly more transparent when mouse is down)

## Important Notes

### Move Placement Still Restricted
The `handleMouseUp()` functions in both modes STILL correctly restrict actual move placement:
- Moves can only be sent during live OGS games
- Only when it's the player's turn
- This prevents accidental move placement during SGF review

**Code preserved:**
```swift
guard ogsClient.isMyTurn,
      ogsClient.gamePhase == .playing,
      let position = phantomStonePosition,
      let gameID = ogsClient.currentGameID else {
    // Clear phantom and return
}
```

### Visual Feedback Only
The phantom stone changes affect ONLY visual feedback during hover. They do not change:
- When moves can be placed
- Game logic or rules
- OGS integration behavior

## Testing Recommendations

1. **SGF Playback Mode:**
   - Hover over empty intersections → should see translucent stone of correct color
   - Advance through moves → phantom stone color should change with whose turn it is
   - Mouse down → stone should become slightly more transparent
   - Mouse up → nothing should happen (can't place moves in playback mode)

2. **Live OGS Game (as Black):**
   - When it's your turn: hover → see translucent black stone
   - When it's opponent's turn: hover → see translucent white stone
   - Mouse up on your turn → move should be sent to server

3. **Live OGS Game (as White):**
   - When it's your turn: hover → see translucent white stone
   - When it's opponent's turn: hover → see translucent black stone
   - Mouse up on your turn → move should be sent to server

4. **Both 2D and 3D Modes:**
   - All of the above should work identically in both modes
   - No differences in behavior between SimpleBoardView and 3D view

## Git Branch
These changes were developed on branch: `claude/fix-phantom-stones-display-011CV2iu1sEoATxcvodkPs2J`
