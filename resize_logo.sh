#!/bin/bash

# Jumpz Logo Resizing Script
# This script resizes the logo for all Android screen densities

echo "🎨 Resizing Jumpz logo for Android app icons..."

# Check if ImageMagick is installed
if ! command -v convert &> /dev/null; then
    echo "❌ ImageMagick not found. Installing via Homebrew..."
    if command -v brew &> /dev/null; then
        brew install imagemagick
    else
        echo "Please install ImageMagick first: https://imagemagick.org/script/download.php"
        exit 1
    fi
fi

# Create the density folders if they don't exist
mkdir -p android/app/src/main/res/mipmap-mdpi
mkdir -p android/app/src/main/res/mipmap-hdpi  
mkdir -p android/app/src/main/res/mipmap-xhdpi
mkdir -p android/app/src/main/res/mipmap-xxhdpi
mkdir -p android/app/src/main/res/mipmap-xxxhdpi

# Resize the logo for each density
echo "📱 Creating app icons for all screen densities..."

# mdpi (48x48)
convert logo.png -resize 48x48 android/app/src/main/res/mipmap-mdpi/ic_launcher.png
echo "✅ Created mdpi icon (48x48)"

# hdpi (72x72)  
convert logo.png -resize 72x72 android/app/src/main/res/mipmap-hdpi/ic_launcher.png
echo "✅ Created hdpi icon (72x72)"

# xhdpi (96x96)
convert logo.png -resize 96x96 android/app/src/main/res/mipmap-xhdpi/ic_launcher.png
echo "✅ Created xhdpi icon (96x96)"

# xxhdpi (144x144)
convert logo.png -resize 144x144 android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png
echo "✅ Created xxhdpi icon (144x144)"

# xxxhdpi (192x192)
convert logo.png -resize 192x192 android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png
echo "✅ Created xxxhdpi icon (192x192)"

echo "🎉 Logo resizing complete!"
echo "📱 All Android app icons have been created in the correct folders."
echo "🚀 Your app will now display the custom Jumpz logo!"


