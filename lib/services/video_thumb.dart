import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

// In-memory кэш результатов проверки (url -> deleted/bytes)
final _cache = <String, ({Uint8List? bytes, bool deleted})>{};

Future<({Uint8List? bytes, bool deleted})> generateVideoThumbnail(String videoUrl) async {
  if (_cache.containsKey(videoUrl)) return _cache[videoUrl]!;

  // HEAD проверка доступности
  try {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    final req = await client.headUrl(Uri.parse(videoUrl));
    final resp = await req.close();
    client.close();
    if (resp.statusCode == 403 || resp.statusCode == 404) {
      final result = (bytes: null, deleted: true);
      _cache[videoUrl] = result;
      return result;
    }
  } catch (_) {
    final result = (bytes: null, deleted: false);
    _cache[videoUrl] = result;
    return result;
  }

  try {
    final dir = await getTemporaryDirectory();
    final outPath = '${dir.path}/thumb_${videoUrl.hashCode.abs()}.jpg';
    final cached = File(outPath);
    if (await cached.exists()) {
      final result = (bytes: await cached.readAsBytes(), deleted: false);
      _cache[videoUrl] = result;
      return result;
    }

    final res = await Process.run('ffmpeg', [
      '-i', videoUrl, '-ss', '00:00:01', '-vframes', '1',
      '-vf', 'scale=320:-1', '-y', outPath,
    ]);

    if (res.exitCode == 0 && await cached.exists()) {
      final result = (bytes: await cached.readAsBytes(), deleted: false);
      _cache[videoUrl] = result;
      return result;
    }
  } catch (_) {}

  final result = (bytes: null, deleted: false);
  _cache[videoUrl] = result;
  return result;
}

Future<Uint8List?> generateLocalVideoThumbnail(String localPath) async {
  try {
    final dir = await getTemporaryDirectory();
    final outPath = '${dir.path}/thumb_local_${localPath.hashCode.abs()}.jpg';
    final cached = File(outPath);
    if (await cached.exists()) return await cached.readAsBytes();

    final res = await Process.run('ffmpeg', [
      '-i', localPath, '-ss', '00:00:01', '-vframes', '1',
      '-vf', 'scale=320:-1', '-y', outPath,
    ]);
    if (res.exitCode == 0 && await cached.exists()) return await cached.readAsBytes();
  } catch (_) {}
  return null;
}
