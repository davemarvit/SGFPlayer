#!/bin/bash

echo "=== Files that should NOT be in bundle resources ==="
echo ""

cd /home/user/SGFPlayer/SGFPlayer3D/SGFPlayer3D

echo "Build logs:"
find . -maxdepth 1 -name "*.log" | wc -l
echo ""

echo "Backup files:"
find . -maxdepth 1 -name "*.backup" | wc -l
echo ""

echo "3D model files (should be in Assets or Resources folder):"
find . -maxdepth 1 -name "*.obj" -o -name "*.dae" | wc -l
echo ""

echo "Audio files (should be in Assets):"
find . -maxdepth 1 -name "*.mp3" -o -name "*.wav" | wc -l
echo ""

echo "Environment maps:"
find . -maxdepth 1 -name "*.exr" | wc -l
echo ""

echo "=== Full list of files at root level (excluding .swift and .entitlements) ==="
find . -maxdepth 1 -type f ! -name "*.swift" ! -name "*.entitlements" ! -name "Info.plist" ! -name ".*"
