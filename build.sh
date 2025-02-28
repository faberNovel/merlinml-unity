#!/bin/bash

# Build MerlinML static library
xcodebuild -project MerlinML.xcodeproj -scheme MerlinML -configuration Release -sdk iphoneos CONFIGURATION_BUILD_DIR=.

echo "Build completed!"
