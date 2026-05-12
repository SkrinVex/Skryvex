import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

import 'video_thumb_mobile.dart' as mobile;
import 'video_thumb_linux.dart' as linux_impl;

Future<({Uint8List? bytes, bool deleted})> generateVideoThumbnail(String videoUrl) {
  if (!kIsWeb && Platform.isLinux) return linux_impl.generateVideoThumbnail(videoUrl);
  return mobile.generateVideoThumbnail(videoUrl);
}

Future<Uint8List?> generateLocalVideoThumbnail(String localPath) {
  if (!kIsWeb && Platform.isLinux) return linux_impl.generateLocalVideoThumbnail(localPath);
  return mobile.generateLocalVideoThumbnail(localPath);
}
