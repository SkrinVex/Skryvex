// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:async';

final _cache = <String, ({Uint8List? bytes, bool deleted})>{};

Future<({Uint8List? bytes, bool deleted})> generateVideoThumbnail(String videoUrl) async {
  if (_cache.containsKey(videoUrl)) return _cache[videoUrl]!;
  try {
    final bytes = await _captureFrame(videoUrl);
    final result = (bytes: bytes, deleted: false);
    _cache[videoUrl] = result;
    return result;
  } catch (_) {
    final result = (bytes: null, deleted: false);
    _cache[videoUrl] = result;
    return result;
  }
}

Future<Uint8List?> generateLocalVideoThumbnail(String localPath) async {
  return _captureFrame(localPath);
}

Future<Uint8List?> _captureFrame(String src) async {
  final completer = Completer<Uint8List?>();
  final video = html.VideoElement()
    ..src = src
    ..crossOrigin = 'anonymous'
    ..muted = true
    ..currentTime = 1.0;

  video.onSeeked.first.then((_) {
    try {
      final canvas = html.CanvasElement(width: 320, height: 180);
      canvas.context2D.drawImageScaled(video, 0, 0, 320, 180);
      canvas.toBlob('image/jpeg', 0.75).then((blob) {
        final reader = html.FileReader();
        reader.readAsArrayBuffer(blob);
        reader.onLoad.first.then((_) {
          completer.complete(Uint8List.fromList(reader.result as List<int>));
        });
      });
    } catch (_) {
      completer.complete(null);
    }
  });

  video.onError.first.then((_) => completer.complete(null));
  Future.delayed(const Duration(seconds: 5), () {
    if (!completer.isCompleted) completer.complete(null);
  });

  return completer.future;
}
