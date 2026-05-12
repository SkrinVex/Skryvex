import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/download_service.dart';
import '../theme.dart';

String _defaultPathHint() {
  if (kIsWeb) return 'Папка загрузок браузера';
  if (Platform.isAndroid) return 'Внутренняя память / Download / Skryvex';
  if (Platform.isIOS) return 'Документы приложения / Skryvex';
  if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
    return 'Загрузки / Skryvex';
  }
  return 'Загрузки / Skryvex';
}

/// Показывает диалог выбора пути и запускает скачивание.
/// Плашка прогресса появляется поверх контента и не закрывается свайпом/кнопкой назад.
Future<void> showDownloadSheet(BuildContext context, {
  required String url,
  required String filename,
}) async {
  // Спрашиваем путь
  final choice = await showDialog<_PathChoice>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text('Сохранить файл', style: TextStyle(color: AppTheme.textPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Куда сохранить файл?', style: TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.folder_outlined, color: AppTheme.orange, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'По умолчанию: ${_defaultPathHint()}',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, _PathChoice.cancel),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, _PathChoice.custom),
          child: const Text('Выбрать папку'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, _PathChoice.defaults),
          child: Text('По умолчанию', style: TextStyle(color: AppTheme.orange)),
        ),
      ],
    ),
  );

  if (choice == null || choice == _PathChoice.cancel) return;

  String? customDir;
  if (choice == _PathChoice.custom) {
    customDir = await DownloadService.pickDirectory();
    if (customDir == null) return; // пользователь отменил выбор
  }

  if (!context.mounted) return;

  // Запускаем скачивание (не await — фоновое)
  DownloadService.instance.download(url: url, filename: filename, customDir: customDir)
      .catchError((_) {});

  // Показываем плашку прогресса — нельзя закрыть назад/свайпом
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: _DownloadProgressDialog(url: url, filename: filename),
    ),
  );
}

enum _PathChoice { defaults, custom, cancel }

class _DownloadProgressDialog extends StatefulWidget {
  final String url;
  final String filename;
  const _DownloadProgressDialog({required this.url, required this.filename});

  @override
  State<_DownloadProgressDialog> createState() => _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<_DownloadProgressDialog> {
  late final ValueNotifier<DownloadState?> _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = DownloadService.instance.notifierFor(widget.url);
    _notifier.addListener(_onUpdate);
  }

  @override
  void dispose() {
    _notifier.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (_notifier.value == null && mounted) {
      Navigator.of(context).pop(); // скачивание завершено
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _notifier.value;
    final progress = state?.progress ?? 0;
    final label = state != null && state.total > 0
        ? '${state.receivedMb} / ${state.totalMb}'
        : 'Подключение...';

    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.filename,
              style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 80, height: 80,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: progress > 0 ? progress : null,
                      color: AppTheme.orange,
                      strokeWidth: 5,
                      backgroundColor: AppTheme.surfaceVariant,
                    ),
                  ),
                  Text(
                    progress > 0 ? '${(progress * 100).toInt()}%' : '',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                DownloadService.instance.cancel(widget.url);
                Navigator.of(context).pop();
              },
              child: const Text('Отмена', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ),
      ),
    );
  }
}
