#!/bin/bash

echo "=== NUCLEAR CLEAN - Complete Xcode Cache Wipe ==="
echo ""
echo "This will:"
echo "1. Kill Xcode"
echo "2. Delete ALL Xcode derived data"
echo "3. Delete ALL Xcode caches"
echo "4. Delete project workspace"
echo "5. Delete Swift PM caches"
echo ""

# Kill Xcode
echo "1. Killing Xcode..."
killall Xcode 2>/dev/null && echo "   Killed" || echo "   Not running"

# Clean ALL derived data (not just this project)
echo "2. Cleaning ALL derived data..."
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# Clean Xcode caches
echo "3. Cleaning Xcode caches..."
rm -rf ~/Library/Caches/com.apple.dt.Xcode/*

# Delete workspace completely
echo "4. Deleting project workspace..."
rm -rf ./SGFPlayer3D.xcodeproj/project.xcworkspace
rm -rf ./SGFPlayer3D.xcodeproj/xcuserdata

# Clean build folders
echo "5. Cleaning build folders..."
rm -rf ./build
rm -rf ./.build

# Clean Swift PM
echo "6. Cleaning Swift PM caches..."
rm -rf ~/Library/Caches/org.swift.swiftpm/*
rm -rf ~/Library/org.swift.swiftpm/*

echo ""
echo "=== DONE ==="
echo ""
echo "NOW:"
echo "1. Open Xcode"
echo "2. Let it reindex the project (wait for it to finish)"
echo "3. Product → Clean Build Folder (Cmd+Shift+K)"
echo "4. Build (Cmd+B)"
