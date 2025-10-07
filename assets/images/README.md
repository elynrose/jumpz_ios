# Assets Folder Structure

## Where to place your files:

### For GIFs:
- **Location**: `assets/images/`
- **Example**: `assets/images/fitness_animation.gif`
- **Usage**: `source: 'assets/images/fitness_animation.gif'`

### For Videos:
- **Location**: `assets/videos/`
- **Example**: `assets/videos/motivational_video.mp4`
- **Usage**: `source: 'assets/videos/motivational_video.mp4'`

## File Requirements:

### GIFs:
- **Format**: `.gif`
- **Size**: Recommended under 5MB for performance
- **Dimensions**: Any size (will be scaled to fit)

### Videos:
- **Format**: `.mp4`, `.mov`, `.avi`
- **Size**: Recommended under 50MB for app size
- **Duration**: Short loops work best (5-30 seconds)
- **Resolution**: 720p or 1080p recommended

## Example Usage in Code:

```dart
// For local GIF
AnimatedBackground(
  type: BackgroundType.gif,
  source: 'assets/images/my_fitness_gif.gif',
  overlayColor: Colors.blue,
  overlayOpacity: 0.3,
)

// For local video
AnimatedBackground(
  type: BackgroundType.video,
  source: 'assets/videos/my_motivational_video.mp4',
  overlayColor: Colors.green,
  overlayOpacity: 0.4,
)
```

## Tips:
- Keep file sizes small for better app performance
- Test on device to ensure smooth playback
- Consider using compressed formats
- Use short, loopable content for best results


