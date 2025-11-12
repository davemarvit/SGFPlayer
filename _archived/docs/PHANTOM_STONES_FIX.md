# Phantom Stones Display Fix

## Issue
Phantom stones were not appearing in either 2D or 3D modes when clicking on the board during OGS games. In 2D mode, a dot would appear briefly on click but vanish on mouse-up without showing a stone. In 3D mode, nothing would happen on click.

## Root Cause
The board views had `.allowsHitTesting(false)` set everywhere, which prevented any mouse interaction. There was no phantom stone logic implemented at all.

## Solution Implemented

### 1. Created BoardInteractionOverlay.swift (2D Mode)
- New view component that handles mouse interactions for the 2D board
- Captures hover, drag, and click events
- Shows semi-transparent phantom stones during hover/drag
- Converts screen coordinates to board positions
- Sends moves to OGS via `ogsClient.sendMove()`
- Only shows phantom stones when it's the player's turn and the game is in progress

Key features:
- Opacity changes: 0.7 during hover, 0.5 during mouse-down
- Validates positions are empty before showing phantom stone
- Uses proper SGF notation for move submission
- Respects traditional Go board cell ratio (15:14)

### 2. Updated SimpleBoardView.swift (2D Mode)
- Added `ogsClient` parameter to enable move sending
- Integrated `BoardInteractionOverlay` on top of board rendering
- Kept board content rendering without hit testing (as before)
- Overlay handles all mouse interactions

### 3. Updated ContentView.swift (2D Mode)
- Passes `ogsClient` to `SimpleBoardView` for move handling

### 4. Enhanced SceneManager3D.swift (3D Mode)
- Added `phantomStoneNode` property to track phantom stone
- Implemented `showPhantomStone(at:color:opacity:)` method
  - Creates semi-transparent 3D stone at board position
  - Uses same stone geometry as regular stones
  - Configurable opacity (default 0.5)
- Implemented `hidePhantomStone()` method
  - Removes phantom stone from scene
- Implemented `hitTestBoard(screenPoint:viewSize:)` method
  - Converts screen coordinates to board positions using ray casting
  - Unprojected camera rays to find board intersection
  - Returns board coordinates (x, y) or nil if out of bounds

### 5. Updated ContentView3D.swift (3D Mode)
- Added phantom stone state tracking
- Added `isMouseDown` state for opacity control
- Modified `sceneView` to wrap in `GeometryReader` for size info
- Added board interaction overlay with gesture handlers
- Implemented `handle3DMouseMove()` for hover/drag
  - Shows phantom stone at hover position
  - Updates opacity based on mouse state (0.5 hover, 0.3 pressed)
  - Only shows when it's player's turn and game is playing
- Implemented `handle3DMouseUp()` for click
  - Sends move to OGS when valid position is clicked
  - Clears phantom stone after move
- Implemented `boardPositionToSGF()` helper
  - Converts (x,y) coordinates to SGF notation

## Technical Details

### 2D Mode Interaction Flow
1. User hovers over board → `BoardInteractionOverlay` detects hover
2. Overlay converts screen point to board coordinates
3. If position is valid and empty, shows phantom stone at 70% opacity
4. User clicks (mouse down) → Opacity changes to 50%
5. User releases (mouse up) → Move is sent to OGS via `sendMove()`
6. Phantom stone is cleared

### 3D Mode Interaction Flow
1. User hovers over board → `handle3DMouseMove()` called
2. Hit test converts screen point to 3D ray, intersects board plane
3. Ray intersection converted to board coordinates
4. If position is valid and empty, `SceneManager3D.showPhantomStone()` called
5. Semi-transparent 3D stone rendered at 50% opacity
6. User clicks (mouse down) → Opacity changes to 30%
7. User releases (mouse up) → `handle3DMouseUp()` sends move to OGS
8. Phantom stone is cleared via `hidePhantomStone()`

### Hit Testing Algorithm (3D)
Uses camera unprojection to create a ray from camera through screen point:
1. Convert AppKit coordinates (top-left origin) to SceneKit (bottom-left)
2. Unproject near and far points to create ray
3. Calculate ray-plane intersection where y = board top surface
4. Convert 3D world coordinates to grid coordinates
5. Round to nearest intersection
6. Validate bounds and return board position

## Conditions for Phantom Stone Display
Phantom stones only appear when ALL of the following are true:
- `ogsClient.isMyTurn` is true (it's the player's turn)
- `ogsClient.gamePhase == .playing` (game is in progress, not pre-game/scoring/finished)
- Mouse is hovering over a valid board position
- The board position is empty (no stone already placed there)

## Files Modified
1. `/SGFPlayer3D/SGFPlayer3D/Views/BoardInteractionOverlay.swift` (NEW)
2. `/SGFPlayer3D/SGFPlayer3D/Views/SimpleBoardView.swift`
3. `/SGFPlayer3D/SGFPlayer3D/ContentView.swift`
4. `/SGFPlayer3D/SGFPlayer3D/SceneManager3D.swift`
5. `/SGFPlayer3D/SGFPlayer3D/ContentView3D.swift`

## Testing Instructions
1. Build and run the application
2. Connect to OGS and start/join a game
3. Wait for your turn
4. **2D Mode**: Hover mouse over empty board intersection → should see semi-transparent stone
5. **2D Mode**: Click and hold → stone opacity should change
6. **2D Mode**: Release → move should be sent, stone should disappear, real stone should appear after OGS confirms
7. Switch to 3D view (Cmd+3)
8. **3D Mode**: Hover over board → should see semi-transparent 3D stone
9. **3D Mode**: Click and hold → stone opacity should change
10. **3D Mode**: Release → move should be sent, phantom clears, real stone appears

## Expected Behavior
- Phantom stones appear ONLY during your turn
- Phantom stones follow mouse cursor over empty intersections
- Phantom stones disappear when hovering over occupied positions
- Clicking sends the move to OGS
- After move is sent, phantom stone disappears immediately
- Real stone appears after OGS confirms the move (via polling)

## Debug Logging
The implementation includes extensive NSLog statements:
- `BoardInteraction: 🎯 Sending move:` - 2D move submission
- `DEBUG3D: 👻 Showing phantom stone at` - 3D phantom creation
- `DEBUG3D: 👻 Hiding phantom stone` - 3D phantom removal
- `DEBUG3D: 🎯 Hit test: screen(...) -> board(...)` - 3D coordinate conversion
- `DEBUG3D: 🎯 Sending move:` - 3D move submission

Check Console.app for these logs during testing.
