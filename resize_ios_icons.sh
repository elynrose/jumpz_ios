#!/bin/bash

# Jumpz iOS App Icon Resizing Script
# This script resizes the logo for all iOS app icon sizes

echo "🎨 Resizing Jumpz logo for iOS app icons..."

# Check if ImageMagick is installed
if ! command -v magick &> /dev/null; then
    echo "❌ ImageMagick not found. Please install ImageMagick first."
    exit 1
fi

# iOS app icon sizes
declare -A ios_sizes=(
    ["Icon-App-20x20@1x.png"]="20x20"
    ["Icon-App-20x20@2x.png"]="40x40"
    ["Icon-App-20x20@3x.png"]="60x60"
    ["Icon-App-29x29@1x.png"]="29x29"
    ["Icon-App-29x29@2x.png"]="58x58"
    ["Icon-App-29x29@3x.png"]="87x87"
    ["Icon-App-40x40@1x.png"]="40x40"
    ["Icon-App-40x40@2x.png"]="80x80"
    ["Icon-App-40x40@3x.png"]="120x120"
    ["Icon-App-60x60@2x.png"]="120x120"
    ["Icon-App-60x60@3x.png"]="180x180"
    ["Icon-App-76x76@1x.png"]="76x76"
    ["Icon-App-76x76@2x.png"]="152x152"
    ["Icon-App-83.5x83.5@2x.png"]="167x167"
    ["Icon-App-1024x1024@1x.png"]="1024x1024"
)

# Create iOS app icons
echo "📱 Creating iOS app icons..."

for filename in "${!ios_sizes[@]}"; do
    size="${ios_sizes[$filename]}"
    output_path="ios/Runner/Assets.xcassets/AppIcon.appiconset/$filename"
    
    magick logo.png -resize "${size}!" "$output_path"
    echo "✅ Created $filename ($size)"
done

echo "🎉 iOS app icon resizing complete!"
echo "📱 All iOS app icons have been created."
echo "🚀 Your iOS app will now display the custom Jumpz logo!"
