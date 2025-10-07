#!/usr/bin/env python3
"""
Jumpz Logo Resizing Script
Creates Android app icons in all required densities
"""

import os
from PIL import Image

def resize_logo():
    print("🎨 Resizing Jumpz logo for Android app icons...")
    
    # Check if logo exists
    if not os.path.exists('logo.png'):
        print("❌ logo.png not found in current directory")
        return False
    
    # Create the density folders
    densities = [
        ('mipmap-mdpi', 48),
        ('mipmap-hdpi', 72),
        ('mipmap-xhdpi', 96),
        ('mipmap-xxhdpi', 144),
        ('mipmap-xxxhdpi', 192)
    ]
    
    try:
        # Open the original logo
        with Image.open('logo.png') as img:
            print(f"📱 Original logo size: {img.size}")
            
            for folder, size in densities:
                # Create folder if it doesn't exist
                folder_path = f"android/app/src/main/res/{folder}"
                os.makedirs(folder_path, exist_ok=True)
                
                # Resize the image
                resized = img.resize((size, size), Image.Resampling.LANCZOS)
                
                # Save the resized image
                output_path = f"{folder_path}/ic_launcher.png"
                resized.save(output_path, 'PNG')
                
                print(f"✅ Created {folder} icon ({size}x{size})")
            
            print("🎉 Logo resizing complete!")
            print("📱 All Android app icons have been created in the correct folders.")
            print("🚀 Your app will now display the custom Jumpz logo!")
            return True
            
    except Exception as e:
        print(f"❌ Error resizing logo: {e}")
        return False

if __name__ == "__main__":
    resize_logo()


