import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

final _cache = <String, ({Uint8List? bytes, bool deleted})>{};

Future<({Uint8List? bytes, bool deleted})> generateVideoThumbnail(String videoUrl) async {
  if (_cache.containsKey(videoUrl)) return _cache[videoUrl]!;
  try {
    final bytes = await VideoThumbnail.thumbnailData(
      video: videoUrl,
      imageFormat: ImageFormat.JPEG,
      maxWidth: 320,
      quality: 75,
      timeMs: 1000,
    );
    final result = (bytes: bytes, deleted: bytes == null);
    _cache[videoUrl] = result;
    return result;
  } catch (_) {
    final result = (bytes: null, deleted: false);
    _cache[videoUrl] = result;
    return result;
  }
}

Future<Uint8List?> generateLocalVideoThumbnail(String localPath) async {
  try {
    return await VideoThumbnail.thumbnailData(
      video: localPath,
      imageFormat: ImageFormat.JPEG,
      maxWidth: 320,
      quality: 75,
      timeMs: 1000,
    );
  } catch (_) {
    return null;
  }
}
