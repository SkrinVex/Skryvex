import 'dart:typed_data';

// Conditional import: web uses dart:html, everything else uses dart:io + platform check
import 'video_thumb_io.dart'
    if (dart.library.html) 'video_thumb_web.dart'
    as _platform;

Future<({Uint8List? bytes, bool deleted})> generateVideoThumbnail(String videoUrl) =>
    _platform.generateVideoThumbnail(videoUrl);

Future<Uint8List?> generateLocalVideoThumbnail(String localPath) =>
    _platform.generateLocalVideoThumbnail(localPath);
