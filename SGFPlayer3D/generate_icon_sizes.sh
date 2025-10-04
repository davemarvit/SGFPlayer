#!/bin/bash

ICON_DIR="SGFPlayer3D/Assets.xcassets/AppIcon.appiconset"
SOURCE="SGFPlayer3D_Icon.png"

# Generate all required sizes
sips -z 16 16 "$SOURCE" --out "$ICON_DIR/icon_16x16.png"
sips -z 32 32 "$SOURCE" --out "$ICON_DIR/icon_16x16@2x.png"
sips -z 32 32 "$SOURCE" --out "$ICON_DIR/icon_32x32.png"
sips -z 64 64 "$SOURCE" --out "$ICON_DIR/icon_32x32@2x.png"
sips -z 128 128 "$SOURCE" --out "$ICON_DIR/icon_128x128.png"
sips -z 256 256 "$SOURCE" --out "$ICON_DIR/icon_128x128@2x.png"
sips -z 256 256 "$SOURCE" --out "$ICON_DIR/icon_256x256.png"
sips -z 512 512 "$SOURCE" --out "$ICON_DIR/icon_256x256@2x.png"
sips -z 512 512 "$SOURCE" --out "$ICON_DIR/icon_512x512.png"
sips -z 1024 1024 "$SOURCE" --out "$ICON_DIR/icon_512x512@2x.png"

echo "All icon sizes generated"
