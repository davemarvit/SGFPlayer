#!/bin/bash

echo "=== Finding and removing duplicate files ==="
echo ""

cd /Users/Dave/SGFPlayer/SGFPlayer3D

echo "Files that should ONLY be in SGFPlayer3D/ subdirectory:"
echo ""

# Check for audio files at parent level
if [ -f "Capture_multiple.mp3" ]; then
    echo "FOUND: Capture_multiple.mp3 (duplicate)"
    rm -v "Capture_multiple.mp3"
fi

if [ -f "Capture_single.mp3" ]; then
    echo "FOUND: Capture_single.mp3 (duplicate)"
    rm -v "Capture_single.mp3"
fi

if [ -f "Stone_click_1.mp3" ]; then
    echo "FOUND: Stone_click_1.mp3 (duplicate)"
    rm -v "Stone_click_1.mp3"
fi

# Check for backup files at parent level
if [ -f "ViewModels/PhysicsViewModel.swift.backup" ]; then
    echo "FOUND: ViewModels/PhysicsViewModel.swift.backup (duplicate)"
    rm -v "ViewModels/PhysicsViewModel.swift.backup"
fi

if [ -f "Integration/INTEGRATION_SUMMARY.md" ]; then
    echo "FOUND: Integration/INTEGRATION_SUMMARY.md (duplicate)"
    rm -v "Integration/INTEGRATION_SUMMARY.md"
fi

echo ""
echo "=== Cleanup complete ==="
echo ""
echo "Now close Xcode and run:"
echo "./EMERGENCY_FIX.sh"
