import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class UploadState {
  final int chatId;
  final Uint8List? previewBytes;
  final bool isVideo;
  final double progress; // 0.0 – 1.0
  final CancelToken cancelToken;

  const UploadState({
    required this.chatId,
    required this.previewBytes,
    required this.isVideo,
    required this.progress,
    required this.cancelToken,
  });

  UploadState copyWith({double? progress, Uint8List? previewBytes}) => UploadState(
        chatId: chatId,
        previewBytes: previewBytes ?? this.previewBytes,
        isVideo: isVideo,
        progress: progress ?? this.progress,
        cancelToken: cancelToken,
      );
}

class UploadService {
  UploadService._();
  static final UploadService instance = UploadService._();

  // chatId → текущая загрузка
  final Map<int, ValueNotifier<UploadState?>> _notifiers = {};

  ValueNotifier<UploadState?> notifierFor(int chatId) =>
      _notifiers.putIfAbsent(chatId, () => ValueNotifier(null));

  UploadState? stateFor(int chatId) => _notifiers[chatId]?.value;

  Future<void> upload({
    required int chatId,
    required Uint8List bytes,
    required String filename,
    required bool isVideo,
    required Uint8List? previewBytes,
    int? replyToId,
    String? caption,
    String? customPath,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    final cancelToken = CancelToken();
    final notifier = notifierFor(chatId);
    notifier.value = UploadState(
      chatId: chatId,
      previewBytes: previewBytes,
      isVideo: isVideo,
      progress: 0,
      cancelToken: cancelToken,
    );

    final path = customPath ?? '/chats/$chatId/media';
    final dio = Dio();
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
        if (replyToId != null) 'reply_to_id': '$replyToId',
        if (caption != null && caption.isNotEmpty) 'text': caption,
      });

      await dio.post(
        '${ApiService.baseUrl}$path',
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
        cancelToken: cancelToken,
        onSendProgress: (sent, total) {
          if (total <= 0) return;
          final current = notifier.value;
          if (current != null) {
            notifier.value = current.copyWith(progress: sent / total);
          }
        },
      );
    } on DioException catch (e) {
      if (!CancelToken.isCancel(e)) rethrow;
    } finally {
      notifier.value = null;
    }
  }

  void updatePreview(int chatId, Uint8List preview) {
    final n = _notifiers[chatId];
    if (n?.value != null) n!.value = n.value!.copyWith(previewBytes: preview);
  }

  void cancel(int chatId) {
    _notifiers[chatId]?.value?.cancelToken.cancel();
  }
}
