import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../theme.dart';

class PhotoViewScreen extends StatelessWidget {
  final String url;
  final String? cacheKey;
  const PhotoViewScreen({super.key, required this.url, this.cacheKey});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: SafeArea(
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: PhotoView(
        imageProvider: CachedNetworkImageProvider(url, cacheKey: cacheKey),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 4,
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        loadingBuilder: (_, event) => Center(
          child: CircularProgressIndicator(
            value: event?.expectedTotalBytes != null
                ? event!.cumulativeBytesLoaded / event.expectedTotalBytes!
                : null,
            color: AppTheme.orange,
          ),
        ),
      ),
    );
  }
}

class VideoPlayerScreen extends StatefulWidget {
  final String url;
  final VoidCallback? onError;
  const VideoPlayerScreen({super.key, required this.url, this.onError});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final Player _player;
  late final VideoController _controller;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _player = Player();
    _controller = VideoController(_player);

    _player.stream.error.listen((error) {
      if (error.isNotEmpty && mounted) {
        Navigator.pop(context);
        widget.onError?.call();
      }
    });

    _player.open(Media(widget.url));
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MaterialVideoControlsTheme(
            normal: MaterialVideoControlsThemeData(
              seekBarThumbColor: AppTheme.orange,
              seekBarPositionColor: AppTheme.orange,
              bottomButtonBarMargin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            ),
            fullscreen: MaterialVideoControlsThemeData(
              seekBarThumbColor: AppTheme.orange,
              seekBarPositionColor: AppTheme.orange,
              bottomButtonBarMargin: EdgeInsets.fromLTRB(
                16, 0, 16,
                MediaQuery.of(context).padding.bottom + 24,
              ),
            ),
            child: Video(
              controller: _controller,
              controls: MaterialVideoControls,
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 4,
            left: 4,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}
