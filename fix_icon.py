#!/usr/bin/env python3
"""
Script to fix app icon transparency issue by removing alpha channel
"""
from PIL import Image
import os

def fix_icon_transparency():
    icon_path = "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png"
    
    if os.path.exists(icon_path):
        # Open the image
        img = Image.open(icon_path)
        
        # Convert to RGB to remove alpha channel
        if img.mode in ('RGBA', 'LA'):
            # Create a white background
            background = Image.new('RGB', img.size, (255, 255, 255))
            if img.mode == 'RGBA':
                background.paste(img, mask=img.split()[-1])  # Use alpha channel as mask
            else:
                background.paste(img)
            img = background
        elif img.mode != 'RGB':
            img = img.convert('RGB')
        
        # Save without alpha channel
        img.save(icon_path, 'PNG')
        print(f"✅ Fixed transparency in {icon_path}")
    else:
        print(f"❌ Icon file not found: {icon_path}")

if __name__ == "__main__":
    fix_icon_transparency()
