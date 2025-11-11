#!/bin/bash

echo "=== EMERGENCY FIX FOR DUPLICATE BUILD ISSUE ==="
echo ""
echo "This will completely reset Xcode's build system cache"
echo ""

# Step 1: Kill Xcode
echo "Step 1: Killing Xcode..."
killall Xcode 2>/dev/null && echo "   ✓ Killed" || echo "   (not running)"
sleep 2

# Step 2: Delete the SPECIFIC DerivedData folder Xcode is using
echo "Step 2: Deleting corrupted DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData/SGFPlayer3D-czdwoqmpfwwbijezthaipoozhqwf
rm -rf ~/Library/Developer/Xcode/DerivedData/SGFPlayer3D-*
echo "   ✓ Deleted"

# Step 3: Delete ALL Xcode module caches
echo "Step 3: Deleting module caches..."
rm -rf ~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex
rm -rf ~/Library/Caches/com.apple.dt.Xcode/*
echo "   ✓ Deleted"

# Step 4: Delete project workspace (already done but making sure)
echo "Step 4: Deleting project workspace..."
rm -rf ./SGFPlayer3D.xcodeproj/project.xcworkspace
rm -rf ./SGFPlayer3D.xcodeproj/xcuserdata
echo "   ✓ Deleted"

# Step 5: Delete local build folder
echo "Step 5: Deleting local build folder..."
rm -rf ./build
rm -rf ./.build
echo "   ✓ Deleted"

echo ""
echo "=== ALL CACHES CLEARED ==="
echo ""
echo "NOW DO THIS:"
echo "1. Open Xcode"
echo "2. Open SGFPlayer3D.xcodeproj"
echo "3. Wait for indexing to complete (watch the progress bar at top)"
echo "4. Product → Clean Build Folder (Cmd+Shift+K)"
echo "5. Product → Build (Cmd+B)"
echo ""
echo "The build should now work!"
