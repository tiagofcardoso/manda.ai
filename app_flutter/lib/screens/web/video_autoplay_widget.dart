import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoAutoplayWidget extends StatefulWidget {
  final String assetPath;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const VideoAutoplayWidget({
    super.key,
    required this.assetPath,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  State<VideoAutoplayWidget> createState() => _VideoAutoplayWidgetState();
}

class _VideoAutoplayWidgetState extends State<VideoAutoplayWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(widget.assetPath)
      ..initialize().then((_) {
        // Mute is required for autoplay on most browsers
        _controller.setVolume(0);
        _controller.setLooping(true);
        _controller.play();
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
      }).catchError((error) {
        debugPrint("Video Error: $error");
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Container(
        width: widget.width,
        height: widget.height ?? 200,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: widget.borderRadius ?? BorderRadius.circular(16),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.circular(16),
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _controller.value.size.width,
            height: _controller.value.size.height,
            child: VideoPlayer(_controller),
          ),
        ),
      ),
    );
  }
}
