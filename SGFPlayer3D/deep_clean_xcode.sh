#!/bin/bash

echo "=== Deep Clean Xcode Project ==="
echo ""

# Kill Xcode if running
echo "1. Checking for Xcode processes..."
pkill -9 Xcode 2>/dev/null && echo "   Killed Xcode" || echo "   Xcode not running"

# Clean all Xcode caches
echo "2. Cleaning Xcode caches..."
rm -rf ~/Library/Developer/Xcode/DerivedData/SGFPlayer3D-*
rm -rf ~/Library/Caches/com.apple.dt.Xcode
rm -rf ./SGFPlayer3D.xcodeproj/project.xcworkspace
rm -rf ./SGFPlayer3D.xcodeproj/xcuserdata
rm -rf ./build
rm -rf ./.build

# Clean Swift PM caches
echo "3. Cleaning Swift PM caches..."
rm -rf ~/Library/Caches/org.swift.swiftpm
rm -rf ~/Library/org.swift.swiftpm

echo ""
echo "=== Done! ==="
echo "Now:"
echo "1. Open Xcode"
echo "2. Open SGFPlayer3D.xcodeproj"
echo "3. Product → Clean Build Folder (Cmd+Shift+K)"
echo "4. Check Copy Bundle Resources phase"
