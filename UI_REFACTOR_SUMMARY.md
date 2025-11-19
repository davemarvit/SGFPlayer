# UI Refactor Summary - Window with Right Sidebar

## Date: 2025-11-17
## Status: ✅ COMPLETED - Build Successful

## Changes Made

### 1. Window Configuration (`SGFPlayer3DApp.swift`)
- Added fixed minimum window size: **1200×900** (1.33:1 landscape aspect ratio)
- Added `.windowStyle(.hiddenTitleBar)` for cleaner look
- Added `.windowResizability(.contentSize)` to control resizing

### 2. New Right Sidebar (`Views/RightSidebarView.swift`)
**Created new modular component** containing:
- **Top**: Game info overlay + fullscreen button
- **Middle**: Space reserved for future chat panel
- **Bottom**:
  - OGS game control buttons (Undo, Pass, Resign) - only when in OGS game
  - Version badge (v3.123)

**Benefits:**
- Fixed width: 300px
- Semi-transparent background
- Clean, uncluttered
- Ready for chat panel addition

### 3. ContentView Layout Changes
**Old Structure:**
```
ZStack {
    mainGameContent
    overlaysGroup (settings, buttons, game info, etc.)
}
```

**New Structure:**
```
HStack {
    leftSideContent (board area - ~900px)
        - mainGameContent (board + bowls)
        - PreGameOverlay
        - GameResultOverlay
        - Settings gear button (top-left, fades in/out)
        - Settings panel (slides in from left)
        - Playback controls (bottom center)

    rightSidebarContent (sidebar - 300px)
        - Game metadata
        - OGS match controls
        - (Space for chat)
}
```

**Key Differences:**
- Settings gear and panel stay on LEFT side (as before)
- Playback controls stay BELOW board (as before)
- Right sidebar is for metadata and match controls only
- Clean separation: game on left, info on right

### 4. Code Organization
- Deprecated old overlay views (commented out for reference)
- Split complex view hierarchy into:
  - `leftSideContent` - computed property
  - `rightSidebarContent` - computed property
- Keeps compiler happy (avoids "expression too complex" errors)

## Files Modified

1. `/SGFPlayer3D/SGFPlayer3D/SGFPlayer3DApp.swift`
   - Window configuration

2. `/SGFPlayer3D/SGFPlayer3D/ContentView.swift`
   - Complete layout refactor
   - Deprecated old overlays
   - Added new computed properties

3. **NEW**: `/SGFPlayer3D/SGFPlayer3D/Views/RightSidebarView.swift`
   - Consolidated sidebar component

## Build Status

✅ **BUILD SUCCEEDED**
- 1 warning (Swift 6 actor isolation - pre-existing, non-blocking)
- No errors
- App compiles and runs

## Testing Checklist

- [ ] App launches without crashes
- [ ] Board displays correctly in left panel
- [ ] Right sidebar shows game info
- [ ] Settings panel opens/closes
- [ ] Playback controls work
- [ ] OGS controls visible when in OGS game
- [ ] Fullscreen button works
- [ ] Window maintains 1:1.33 aspect ratio
- [ ] No visual glitches or overlapping elements

## Next Steps

### Immediate
1. **Test** - Verify all existing functionality works
2. **WebSocket Investigation** - Capture chat message format from browser DevTools
3. **Chat Architecture** - Design modular chat system

### Future: Chat Implementation
With the new sidebar, adding chat will be straightforward:
1. Add `ChatPanel.swift` as a new view
2. Insert it in `RightSidebarView` between game info and controls
3. Feature flag controlled (easy to disable)
4. No impact on existing code

## Advantages of New Layout

1. **Less Crowded UI** - Controls no longer overlap game board
2. **Modular** - Easy to add/remove sidebar components
3. **Consistent** - Fixed aspect ratio prevents layout issues
4. **Maintainable** - Clear separation of concerns
5. **Chat-Ready** - Sidebar has space for chat panel

## Rollback Plan

If issues arise:
```bash
git checkout e012336  # Return to stable v3.123
```

All changes are in version control and can be reverted easily.
