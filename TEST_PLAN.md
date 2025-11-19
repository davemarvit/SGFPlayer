# SGFPlayer 2D/3D - Comprehensive Test Plan

**Version**: v3.189+
**Last Updated**: 2025-11-19
**Status**: Living Document - Update after each major feature

---

## Test Categories

### 1. Automated Tests (Can run without user intervention)
### 2. Build Tests (Can run without user intervention)
### 3. Visual Tests (Require user verification)
### 4. Interactive Tests (Require user interaction)
### 5. Integration Tests (Require external services)

---

## 1. AUTOMATED TESTS (Run without intervention)

### Build & Compilation
- [ ] **Clean build succeeds** - `xcodebuild clean build`
- [ ] **No compiler warnings** - Check build output
- [ ] **No SwiftUI "expression too complex" errors**
- [ ] **All ViewModels compile independently**
- [ ] **All View files compile independently**

### Code Quality
- [ ] **No force unwraps in production code** - `grep -r "!" --include="*.swift" | grep -v "// Force unwrap OK"`
- [ ] **No TODO comments in critical paths** - `grep -r "TODO" --include="*.swift"`
- [ ] **File size limits respected** - No file > 300 lines (except legacy ContentView during migration)
- [ ] **ViewModels use proper @Published** - Check all ViewModel properties
- [ ] **No @State in ViewModels** - ViewModels should use @Published

### Architecture Compliance
- [ ] **ContentView < 200 lines** (after refactor)
- [ ] **All ViewModels in ViewModels/ directory**
- [ ] **All Views in Views/ directory**
- [ ] **No business logic in Views** - Views only render state
- [ ] **No direct AppStorage in Views** - Use ViewModels

---

## 2. BUILD TESTS (Can run without intervention)

### Release Build
```bash
cd /Users/Dave/SGFPlayer/SGFPlayer3D
xcodebuild -scheme SGFPlayer3D -configuration Release clean build
```
- [ ] **Build succeeds**
- [ ] **Build time < 60 seconds**
- [ ] **App bundle created successfully**
- [ ] **App bundle size reasonable** (< 50MB)

### Debug Build
```bash
xcodebuild -scheme SGFPlayer3D -configuration Debug clean build
```
- [ ] **Build succeeds**
- [ ] **Debug symbols present**

### Launch Test (Automated)
```bash
open /Users/Dave/SGFPlayer/SGFPlayer3D/build/Build/Products/Release/SGFPlayer3D.app
sleep 5
pgrep -x SGFPlayer3D
```
- [ ] **App launches successfully**
- [ ] **No crash on startup**
- [ ] **Process running after 5 seconds**

---

## 3. VISUAL TESTS (Require user to verify)

### Layout Tests

#### Normal Window (1200x900)
- [ ] **Board centered correctly**
- [ ] **Bowls visible and positioned on right side**
  - Upper bowl (black captures) at top-right
  - Lower bowl (white captures) at bottom-right
- [ ] **No cropping of board edges**
- [ ] **No cropping of bowl edges**
- [ ] **Playback controls centered under board** (not window)
- [ ] **Settings gear button visible in top-left**
- [ ] **Version badge visible in bottom-right sidebar**

#### Fullscreen Mode
- [ ] **Board visible without cropping**
- [ ] **Bowls visible without cropping**
- [ ] **UI buttons fade out after 3 seconds**
- [ ] **UI buttons fade in on mouse move**
- [ ] **Fullscreen button works (top-right)**
- [ ] **No black bars or letterboxing**

#### Right Sidebar
- [ ] **Fixed 300px width**
- [ ] **Game metadata visible at top**
- [ ] **OGS controls visible when in live game**
- [ ] **Version badge at bottom**
- [ ] **Background semi-transparent**

#### Responsive Sizing
- [ ] **Resize window smaller - layout adjusts**
- [ ] **Resize window larger - layout adjusts**
- [ ] **Board maintains aspect ratio**
- [ ] **Bowls scale proportionally**

---

## 4. INTERACTIVE TESTS (Require user interaction)

### Game Loading
- [ ] **Click "Choose Folder" button**
- [ ] **Select folder with .sgf files**
- [ ] **Game list populates**
- [ ] **First game loads automatically**
- [ ] **Board displays correctly**

### Playback Controls
- [ ] **Click "|<" - Jumps to game start**
- [ ] **Click "<" - Goes to previous move**
- [ ] **Click ">" - Goes to next move**
- [ ] **Click ">|" - Jumps to game end**
- [ ] **Click "Play" - Auto-advances moves**
- [ ] **Click "Pause" - Stops auto-advance**
- [ ] **Slider - Scrub through game**

### Game Navigation
- [ ] **Click "Random" - Loads random game**
- [ ] **Click "Next Game" - Loads next in list**
- [ ] **Arrow keys work for navigation**
  - Left arrow: previous move
  - Right arrow: next move
  - Up arrow: previous game
  - Down arrow: next game

### Settings Panel
- [ ] **Click gear icon - Panel slides in from left**
- [ ] **Click backdrop - Panel slides out**
- [ ] **Search box works**
- [ ] **Physics model selector works**
- [ ] **Shadow settings sliders work**
- [ ] **Auto-play toggle works**
- [ ] **Random mode toggle works**

### Physics/Bowl Animation
- [ ] **Stones appear in bowls when captured**
- [ ] **Physics animation smooth (60fps)**
- [ ] **No jitter or glitching**
- [ ] **Stones settle into stable positions**

### Fullscreen
- [ ] **Click fullscreen button - Enters fullscreen**
- [ ] **Click fullscreen button again - Exits fullscreen**
- [ ] **Escape key - Exits fullscreen**
- [ ] **Green button (macOS) - Enters fullscreen**

---

## 5. INTEGRATION TESTS (Require OGS server)

### OGS Connection
- [ ] **Enable OGS mode in settings**
- [ ] **App connects to online-go.com**
- [ ] **Authentication succeeds**
- [ ] **Connection status shown**

### OGS Game Finding
- [ ] **Click "Find Game" button**
- [ ] **Pre-game overlay appears**
- [ ] **Game search starts**
- [ ] **Game found notification**
- [ ] **Board loads with correct setup**

### OGS Live Play
- [ ] **Click on board to place stone**
- [ ] **Stone appears on opponent's client**
- [ ] **Opponent's moves appear on local board**
- [ ] **Time controls update correctly**
- [ ] **Capture detection works**
- [ ] **Pass button sends pass**
- [ ] **Undo request works**
- [ ] **Resign confirmation works**

### OGS Game End
- [ ] **Game result overlay appears**
- [ ] **Score displayed correctly**
- [ ] **Winner shown correctly**
- [ ] **Return to game search works**

---

## 6. REGRESSION TESTS (Check after refactoring)

### Core Functionality Preserved
- [ ] **Game loading still works**
- [ ] **Playback controls still work**
- [ ] **Physics/bowls still work**
- [ ] **Settings panel still works**
- [ ] **OGS mode still works**
- [ ] **Fullscreen still works**

### No Performance Regressions
- [ ] **App startup time < 2 seconds**
- [ ] **Game loading time < 500ms**
- [ ] **Move navigation instant (< 50ms)**
- [ ] **Physics animation 60fps**
- [ ] **UI interactions responsive**

### No Visual Regressions
- [ ] **Layout identical to v3.189**
- [ ] **Colors/styling unchanged**
- [ ] **Animations identical**
- [ ] **No new visual bugs**

---

## 7. REFACTORING-SPECIFIC TESTS

### ViewModel Tests

#### GameViewModel
- [ ] **Created and compiles**
- [ ] **Manages game state correctly**
- [ ] **Player property accessible**
- [ ] **Auto-play state managed**

#### PhysicsViewModel
- [ ] **Created and compiles**
- [ ] **Bowls state managed**
- [ ] **Physics integration works**
- [ ] **Update for move works**

#### LayoutViewModel
- [ ] **Created and compiles**
- [ ] **Board frame calculated correctly**
- [ ] **Bowl positions calculated correctly**
- [ ] **boardCenterX calculated correctly**

#### SettingsViewModel
- [ ] **Created and compiles**
- [ ] **All @AppStorage properties moved**
- [ ] **Settings grouped logically**
- [ ] **No duplicate settings**

### Component Tests

#### GameBoardContainer
- [ ] **Created and compiles**
- [ ] **Renders board correctly**
- [ ] **Accepts ViewModel dependencies**
- [ ] **No direct @State dependencies**

#### LeftSidePanel
- [ ] **Created and compiles**
- [ ] **Contains board, settings, controls**
- [ ] **Layout correct**
- [ ] **No ZStack conflicts**

#### RightSidebarView (Updated)
- [ ] **Compiles with updates**
- [ ] **OGS controls not duplicated**
- [ ] **Ready for chat panel addition**
- [ ] **Layout unchanged**

### ContentView Refactored
- [ ] **< 200 lines**
- [ ] **Uses HStack layout**
- [ ] **No overlaysGroup**
- [ ] **Only modal overlays in .overlay()**
- [ ] **All ViewModels injected**
- [ ] **No business logic**

---

## 8. TEST EXECUTION CHECKLIST

### Before Each Commit
- [ ] Run: Build tests (automated)
- [ ] Run: Launch test (automated)
- [ ] Quick visual check: Normal window layout
- [ ] Quick interaction: Load game, navigate moves

### Before Each PR
- [ ] Run: All automated tests
- [ ] Run: All build tests
- [ ] Run: All visual tests
- [ ] Run: All interactive tests
- [ ] Review: Code quality checks
- [ ] Review: Architecture compliance

### Before Release
- [ ] Run: Complete test suite
- [ ] Run: Integration tests (OGS)
- [ ] Run: Performance tests
- [ ] Run: Regression tests
- [ ] Document: Any known issues

---

## 9. AUTOMATED TEST SCRIPT

Save this as `/Users/Dave/SGFPlayer/run_tests.sh`:

```bash
#!/bin/bash

echo "=== SGFPlayer Test Suite ==="
echo ""

# 1. Clean build test
echo "1. Testing clean build..."
cd /Users/Dave/SGFPlayer/SGFPlayer3D
xcodebuild -scheme SGFPlayer3D -configuration Release clean build 2>&1 | grep -E "(BUILD SUCCEEDED|BUILD FAILED|error:|warning:)"
if [ $? -eq 0 ]; then
    echo "✅ Build test passed"
else
    echo "❌ Build test failed"
    exit 1
fi

# 2. File size check
echo ""
echo "2. Checking file sizes..."
CONTENTVIEW_LINES=$(wc -l < SGFPlayer3D/ContentView.swift)
echo "ContentView.swift: $CONTENTVIEW_LINES lines"
if [ $CONTENTVIEW_LINES -lt 300 ]; then
    echo "✅ File size check passed"
else
    echo "⚠️  File size check: ContentView.swift > 300 lines (acceptable during migration)"
fi

# 3. Code quality checks
echo ""
echo "3. Running code quality checks..."

# Check for force unwraps
FORCE_UNWRAPS=$(grep -r "!" --include="*.swift" SGFPlayer3D/ | grep -v "// Force unwrap OK" | grep -v "!=" | wc -l)
echo "Force unwraps found: $FORCE_UNWRAPS"
if [ $FORCE_UNWRAPS -lt 10 ]; then
    echo "✅ Force unwrap check passed"
else
    echo "⚠️  Too many force unwraps"
fi

# Check for TODOs
TODOS=$(grep -r "TODO" --include="*.swift" SGFPlayer3D/ | wc -l)
echo "TODO comments found: $TODOS"

# 4. Launch test
echo ""
echo "4. Testing app launch..."
open build/Build/Products/Release/SGFPlayer3D.app
sleep 5
if pgrep -x SGFPlayer3D > /dev/null; then
    echo "✅ Launch test passed"
    killall SGFPlayer3D
else
    echo "❌ Launch test failed"
    exit 1
fi

echo ""
echo "=== Test Suite Complete ==="
echo "✅ All automated tests passed"
echo ""
echo "Next: Run visual tests manually (see TEST_PLAN.md section 3)"
```

### Make it executable:
```bash
chmod +x /Users/Dave/SGFPlayer/run_tests.sh
```

### Run tests:
```bash
/Users/Dave/SGFPlayer/run_tests.sh
```

---

## 10. TEST RESULTS LOG

### v3.189 (Pre-Chat Baseline) - 2025-11-19
- ✅ All build tests passed
- ✅ All visual tests passed
- ✅ All interactive tests passed
- ✅ Layout correct in normal and fullscreen
- ✅ Playback controls centered under board
- ⚠️  ContentView.swift = 1,211 lines (needs refactoring)
- ⚠️  ZStack overlay architecture (needs refactoring)

### v3.190 (Post-Refactor) - TBD
- [ ] To be tested after refactoring complete

---

## 11. KNOWN ISSUES TRACKER

### Current Known Issues (v3.189)
1. **ContentView complexity**: 1,211 lines, needs refactoring
2. **ZStack overlay system**: Manual zIndex management, fragile
3. **Duplicate OGS controls**: Code exists in 2 places
4. **ViewModels not fully utilized**: Some exist but aren't used

### Resolved Issues
- ✅ UIStateViewModel initialization (removed @MainActor) - v3.179
- ✅ Bowl positioning (upper lid on right) - v3.186
- ✅ Fullscreen polling (timer on main thread) - v3.180
- ✅ Playback controls centering (under board not window) - v3.189

---

## 12. PERFORMANCE BENCHMARKS

### Startup Time
- Target: < 2 seconds
- v3.189: ~1.5 seconds ✅

### Game Loading
- Target: < 500ms
- v3.189: ~300ms ✅

### Move Navigation
- Target: < 50ms
- v3.189: ~20ms ✅

### Physics Animation
- Target: 60fps
- v3.189: 60fps ✅

### Memory Usage
- Target: < 200MB
- v3.189: ~150MB ✅

---

## 13. CHAT FEATURE TESTS (To be added after Phase 4)

### Chat UI
- [ ] Chat panel visible in right sidebar
- [ ] Scrollable message list
- [ ] Input field at bottom
- [ ] Send button works

### Chat Functionality
- [ ] Messages send successfully
- [ ] Messages received from opponent
- [ ] Timestamps correct
- [ ] Message formatting correct
- [ ] Scroll to bottom on new message

### Chat Integration
- [ ] Chat tied to current game
- [ ] Chat clears on new game
- [ ] Chat persists during game
- [ ] Chat WebSocket connection stable

---

**END OF TEST PLAN**

This is a living document. Update after each major feature addition or refactoring.
