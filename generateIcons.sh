#!/bin/bash

set -e

# Step 1: Generate icons using flutter_launcher_icons
echo "Running flutter_launcher_icons..."
flutter pub run flutter_launcher_icons

# Step 2: Fix iOS icons - remove alpha and apply background color
IOS_ICON_PATH="./ios/Runner/Assets.xcassets/AppIcon.appiconset"
BG_COLOR="#f4ead2"

echo "Processing iOS icons in: $IOS_ICON_PATH"

find "$IOS_ICON_PATH" -name "*.png" | while read -r img; do
  echo "Fixing $img"
  magick "$img" -background "$BG_COLOR" -alpha remove -alpha off "$img"
done

echo "✅ All done. iOS icons now have no alpha and use background color $BG_COLOR"
