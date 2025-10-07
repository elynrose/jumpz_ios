import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// A widget that displays an animated background using either a video or GIF.
/// 
/// This widget provides a seamless animated background that can be used
/// for jump sessions or other screens that need dynamic visual appeal.
class AnimatedBackground extends StatefulWidget {
  /// The type of background to display
  final BackgroundType type;
  
  /// The source URL or asset path for the background
  final String source;
  
  /// Whether the background should loop continuously
  final bool loop;
  
  /// The fit behavior for the background
  final BoxFit fit;
  
  /// Optional overlay color to apply over the background
  final Color? overlayColor;
  
  /// Opacity of the overlay (0.0 to 1.0)
  final double overlayOpacity;

  const AnimatedBackground({
    super.key,
    required this.type,
    required this.source,
    this.loop = true,
    this.fit = BoxFit.cover,
    this.overlayColor,
    this.overlayOpacity = 0.3,
  });

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.type == BackgroundType.video) {
      _initializeVideo();
    }
  }

  Future<void> _initializeVideo() async {
    try {
      // Check if it's a local asset or network URL
      if (widget.source.startsWith('assets/')) {
        _videoController = VideoPlayerController.asset(widget.source);
      } else {
        _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.source));
      }
      
      await _videoController!.initialize();
      
      if (widget.loop) {
        _videoController!.setLooping(true);
      }
      
      _videoController!.play();
      
      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing video: $e');
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        children: [
          // Background content
          Positioned.fill(
            child: _buildBackground(),
          ),
          
          // Overlay
          if (widget.overlayColor != null)
            Positioned.fill(
              child: Container(
                color: widget.overlayColor!.withValues(alpha: widget.overlayOpacity),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    switch (widget.type) {
      case BackgroundType.video:
        return _buildVideoBackground();
      case BackgroundType.gif:
        return _buildGifBackground();
      case BackgroundType.gradient:
        return _buildGradientBackground();
    }
  }

  Widget _buildVideoBackground() {
    if (!_isVideoInitialized || _videoController == null) {
      return _buildGradientBackground(); // Fallback
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: FittedBox(
            fit: BoxFit.cover,
            alignment: Alignment.center,
            child: SizedBox(
              width: _videoController!.value.size.width,
              height: _videoController!.value.size.height,
              child: VideoPlayer(_videoController!),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGifBackground() {
    // Check if it's a local asset or network URL
    if (widget.source.startsWith('assets/')) {
      debugPrint('Loading local asset: ${widget.source}');
      return LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: FittedBox(
              fit: BoxFit.cover,
              alignment: Alignment.center,
              child: Image.asset(
                widget.source,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('Error loading asset: $error');
                  return _buildGradientBackground();
                },
              ),
            ),
          );
        },
      );
    } else {
      debugPrint('Loading network image: ${widget.source}');
      return LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: FittedBox(
              fit: BoxFit.cover,
              alignment: Alignment.center,
              child: CachedNetworkImage(
                imageUrl: widget.source,
                placeholder: (context, url) => _buildGradientBackground(),
                errorWidget: (context, url, error) {
                  debugPrint('Error loading network image: $error');
                  return _buildGradientBackground();
                },
              ),
            ),
          );
        },
      );
    }
  }

  Widget _buildGradientBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1A1A2E),
            Color(0xFF16213E),
            Color(0xFF0F3460),
          ],
        ),
      ),
    );
  }
}

/// Enum to define the type of animated background
enum BackgroundType {
  video,
  gif,
  gradient,
}

/// Predefined background configurations for common use cases
class BackgroundPresets {
  static const String motivationalVideo = 'https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4';
  static const String fitnessGif = 'https://media.giphy.com/media/3o7btPCcdNniyf0ArS/giphy.gif';
  static const String energyGif = 'https://media.giphy.com/media/l0MYt5jPR6QX5pnqM/giphy.gif';
  static const String celebrationGif = 'https://media.giphy.com/media/3o7aTskHEUdg8Hpqg8/giphy.gif';
  
  /// Get a random motivational background
  static AnimatedBackground getRandomMotivational() {
    final backgrounds = [
      AnimatedBackground(
        type: BackgroundType.gif,
        source: fitnessGif,
        overlayColor: Colors.black,
        overlayOpacity: 0.4,
      ),
      AnimatedBackground(
        type: BackgroundType.gif,
        source: energyGif,
        overlayColor: Colors.black,
        overlayOpacity: 0.4,
      ),
    ];
    
    return backgrounds[DateTime.now().millisecond % backgrounds.length];
  }
}
