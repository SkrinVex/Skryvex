import 'dart:io';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class DownloadState {
  final String url;
  final String filename;
  final int received;
  final int total;
  final CancelToken cancelToken;

  const DownloadState({
    required this.url,
    required this.filename,
    required this.received,
    required this.total,
    required this.cancelToken,
  });

  double get progress => total > 0 ? received / total : 0;
  String get receivedMb => '${(received / 1024 / 1024).toStringAsFixed(1)} МБ';
  String get totalMb => '${(total / 1024 / 1024).toStringAsFixed(1)} МБ';
}

class DownloadService {
  DownloadService._();
  static final DownloadService instance = DownloadService._();

  // url → notifier
  final Map<String, ValueNotifier<DownloadState?>> _notifiers = {};

  ValueNotifier<DownloadState?> notifierFor(String url) =>
      _notifiers.putIfAbsent(url, () => ValueNotifier(null));

  bool isDownloading(String url) => _notifiers[url]?.value != null;

  /// [customDir] — путь выбранный пользователем, null = Downloads/Skryvex
  Future<void> download({
    required String url,
    required String filename,
    String? customDir,
  }) async {
    if (isDownloading(url)) return;

    String savePath;
    if (customDir != null) {
      savePath = '$customDir/$filename';
    } else {
      savePath = await _defaultPath(filename);
    }

    final cancelToken = CancelToken();
    final notifier = notifierFor(url);
    notifier.value = DownloadState(
      url: url,
      filename: filename,
      received: 0,
      total: 0,
      cancelToken: cancelToken,
    );

    final dio = Dio();
    try {
      await dio.download(
        url,
        savePath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          notifier.value = DownloadState(
            url: url,
            filename: filename,
            received: received,
            total: total,
            cancelToken: cancelToken,
          );
        },
      );
    } on DioException catch (e) {
      if (!CancelToken.isCancel(e)) rethrow;
    } finally {
      notifier.value = null;
    }
  }

  void cancel(String url) => _notifiers[url]?.value?.cancelToken.cancel();

  Future<String> _defaultPath(String filename) async {
    if (kIsWeb) return filename;
    if (Platform.isAndroid) {
      if (await Permission.storage.request().isGranted ||
          await Permission.manageExternalStorage.request().isGranted) {
        return '/storage/emulated/0/Download/Skryvex/$filename';
      }
      final dir = await getExternalStorageDirectory();
      return '${dir!.path}/$filename';
    }
    if (Platform.isIOS) {
      final dir = await getApplicationDocumentsDirectory();
      return '${dir.path}/Skryvex/$filename';
    }
    // Linux / Windows / macOS
    final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    return '${dir.path}/Skryvex/$filename';
  }

  /// Показывает диалог выбора пути, возвращает выбранный путь или null (отмена)
  static Future<String?> pickDirectory() async {
    return FilePicker.platform.getDirectoryPath();
  }
}
