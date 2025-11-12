# SGFPlayer3D

A 3D version of SGFPlayer that renders Go boards in 3D using SceneKit, allowing users to view games from different angles.

## Overview

SGFPlayer3D is an experimental fork of the original SGFPlayer project. It maintains all the core SGF parsing and game logic while adding 3D visualization capabilities.

## Features

- **3D Go Board**: Fully rendered 3D board with proper proportions
- **Grid Lines**: Traditional Go board grid with star points
- **Camera Controls**: Adjustable viewing angle and distance
- **Shared Core**: Reuses SGF parsing, game engine, and physics from SGFPlayer
- **Independent Development**: Separate project allows experimentation without affecting the stable 2D version

## Status

This is an early experimental version. Current features:
- ✅ 3D board rendering with grid
- ✅ Camera angle controls
- ⏳ Stone rendering (TODO)
- ⏳ Game playback (TODO)
- ⏳ Move history (TODO)

## Development

The project shares core code with SGFPlayer:
- `SGFKit.swift` - SGF file parsing
- `SGFPlayerEngine.swift` - Game logic and board state
- `AppModel.swift` - File management

New 3D-specific code:
- `ContentView3D.swift` - 3D scene setup and rendering
- `SceneManager3D` - SceneKit scene management

## Building

```bash
cd "/Users/Dave/Go/SGFPlayer Code/SGFPlayer3D"
xcodebuild -project SGFPlayer3D.xcodeproj -scheme SGFPlayer3D -configuration Debug build
```

Or open `SGFPlayer3D.xcodeproj` in Xcode.

## Next Steps

1. Add 3D stone rendering
2. Integrate game playback
3. Add move annotations in 3D space
4. Experiment with different camera modes (orbit, fly-through, etc.)
5. Add lighting effects and shadows

## License

Same as SGFPlayer - see main project for details.
