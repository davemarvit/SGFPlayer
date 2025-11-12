#!/bin/bash

# Create new project using Xcode's template system
cd "/Users/Dave/Go/SGFPlayer Code"

# Remove existing SGFPlayer3D directory if it exists
rm -rf SGFPlayer3D

# Create the project using xcodebuild
mkdir -p SGFPlayer3D
cd SGFPlayer3D

# We'll create a minimal project structure and use Xcode to complete it
mkdir -p SGFPlayer3D.xcodeproj
mkdir -p SGFPlayer3D

echo "Project structure created. Will use Xcode's automation..."
