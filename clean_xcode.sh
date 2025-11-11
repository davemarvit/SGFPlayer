#!/bin/bash
# Clean Xcode project caches and rebuild

echo "Cleaning Xcode workspace data..."
rm -rf ./SGFPlayer/SGFPlayer.xcodeproj/project.xcworkspace/xcuserdata
rm -rf ./SGFPlayer/SGFPlayer.xcodeproj/xcuserdata

echo "Cleaning build folder..."
rm -rf ./SGFPlayer/build

echo "Cleaning all derived data..."
rm -rf ~/Library/Developer/Xcode/DerivedData/SGFPlayer-*

echo "Done! Now:"
echo "1. Close Xcode if it's open"
echo "2. Reopen the project"
echo "3. Clean Build Folder (Cmd+Shift+K)"
echo "4. Build (Cmd+B)"
