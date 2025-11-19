# SGFPlayer Screensaver

A macOS screensaver that plays Go (Weiqi/Baduk) game replays with realistic stone physics, extracted from the SGFPlayer application.

## Features

- **Full-screen Go game playback** with automatic move progression
- **Realistic stone physics** using the same engine as SGFPlayer
- **Multiple physics models**: Spiral, Group Drop, and Energy Minimization
- **Embedded demo games** to avoid file system permission issues
- **Configurable playback speed** via settings panel
- **Sequoia v15.5 compatible** with proper permission handling

## Installation on macOS Sequoia v15.5

### Building from Source

1. **Clone the repository** (if not already available):
   ```bash
   cd SGFPlayerScreensaver
   ```

2. **Check dependencies**:
   ```bash
   make check-deps
   ```

3. **Build the screensaver**:
   ```bash
   make all
   ```

4. **Install the screensaver**:
   ```bash
   make install
   ```

### macOS Sequoia v15.5 Installation Notes

Due to Apple's changes in Sequoia, screensaver installation requires additional steps:

1. **Initial Installation**:
   - Run `make install` to copy the screensaver to your Library
   - The system may block the unsigned screensaver

2. **Permission Handling**:
   - Go to **System Settings > Privacy & Security**
   - Scroll to the bottom and look for "SGFPlayerScreensaver was blocked"
   - Click **"Open Anyway"**

3. **Activation**:
   - Open **System Settings > Wallpaper**
   - Click the **Screen Saver** button (not in a separate preference pane anymore)
   - Select **"SGF Player"** from the list
   - Configure settings as desired

### Alternative Installation (Manual)

If the Makefile approach doesn't work:

1. **Build manually**:
   ```bash
   swiftc -target x86_64-apple-macos12.0 \
          -swift-version 5.0 \
          -O \
          -module-name SGFPlayerScreensaver \
          -emit-executable \
          -framework ScreenSaver \
          -framework Cocoa \
          -framework CoreGraphics \
          -framework Foundation \
          -o build/SGFPlayerScreensaver.saver/Contents/MacOS/SGFPlayerScreensaver \
          Sources/**/*.swift
   ```

2. **Copy manually**:
   ```bash
   cp -R build/SGFPlayerScreensaver.saver ~/Library/Screen\ Savers/
   ```

## Configuration

The screensaver includes a configuration panel accessible through System Settings:

### Available Settings

- **Game Speed**: Controls how fast moves are played (0.5x to 5.0x speed)
- **Physics Model**:
  - **Spiral**: Fast, deterministic stone arrangement
  - **Group Drop**: Balanced realism and performance (default)
  - **Energy Minimization**: Maximum realism, higher CPU usage

### Demo Games

The screensaver includes embedded demo games to avoid file system permissions:

1. **Tactical Sequence**: Small tactical exchanges demonstrating basic Go
2. **Corner Joseki**: Common corner pattern sequences

## Technical Architecture

### Core Components

- **SGFPlayerScreensaver**: Main ScreenSaverView subclass
- **Physics Engine**: Stone physics simulation with multiple models
- **Layout Service**: Responsive layout calculation for different screen sizes
- **Game Engine**: SGF parsing and game state management

### File Structure

```
SGFPlayerScreensaver/
├── Sources/
│   ├── Core/
│   │   ├── SGFPlayerScreensaver.swift     # Main screensaver implementation
│   │   ├── ScreensaverExtensions.swift    # Compatibility layer
│   │   ├── SGFKit.swift                   # SGF parsing
│   │   ├── SGFPlayerEngine.swift          # Game logic
│   │   ├── StoneJitter.swift              # Stone positioning
│   │   ├── BowlPhysics.swift              # Bowl stone physics
│   │   └── BowlView.swift                 # Bowl rendering
│   ├── Physics/
│   │   ├── PhysicsEngine.swift            # Physics orchestration
│   │   ├── SpiralPhysicsModel.swift       # Simple spiral arrangement
│   │   ├── GroupDropPhysicsModel.swift    # Realistic clustering
│   │   └── EnergyMinimizationModel.swift  # Advanced simulation
│   ├── Services/
│   │   └── LayoutService.swift            # Responsive layout
│   ├── Models/
│   │   └── GameStateCache.swift           # Game state caching
│   └── Views/
│       └── SimpleBoardView.swift          # Board rendering components
├── Info.plist                             # Bundle configuration
├── Makefile                               # Build system
└── README.md                              # This file
```

## Sequoia v15.5 Compatibility Notes

### Changes in Sequoia

1. **Screen Saver Preference Pane Removed**: Screen saver settings are now accessed through System Settings > Wallpaper
2. **Increased Security Restrictions**: Third-party screensavers face additional scrutiny
3. **Permission Dialog Changes**: New "Open Anyway" workflow required
4. **Modal Interface**: Screen saver selection is now a modal dialog, not resizable

### Known Issues

1. **First Launch**: May require "Open Anyway" permission grant
2. **Preview Mode**: Some physics features may be disabled in preview
3. **Performance**: Energy Minimization model may cause brief pauses on older hardware

### Troubleshooting

**Screensaver doesn't appear in list:**
- Ensure installation completed without errors
- Check ~/Library/Screen Savers/ contains SGFPlayerScreensaver.saver
- Restart System Settings if necessary

**"Cannot be opened" error:**
- Go to System Settings > Privacy & Security
- Look for SGFPlayerScreensaver in blocked applications
- Click "Open Anyway"

**Screensaver appears black/frozen:**
- Check Console.app for error messages
- Ensure all Swift source files compiled correctly
- Try rebuilding with `make clean && make all`

## Development

### Building for Development

```bash
make dev-build    # Clean build
make dev-install  # Build and install
make clean       # Remove build artifacts
```

### Adding Custom Games

To add your own SGF games:

1. Modify `createDemoGames()` in SGFPlayerScreensaver.swift
2. Add SGF content as string literals
3. Rebuild and reinstall

### Extending Physics Models

New physics models can be added by:

1. Creating a new file in Sources/Physics/
2. Implementing the PhysicsModel protocol
3. Adding to PhysicsEngine.models array
4. Updating configuration UI

## License

This screensaver is derived from the SGFPlayer project and maintains the same architectural principles and code quality standards.

## Credits

- Based on SGFPlayer by Dave
- Physics simulation algorithms adapted from SGFPlayer
- Built for compatibility with macOS Sequoia v15.5
- Generated with Claude Code assistance