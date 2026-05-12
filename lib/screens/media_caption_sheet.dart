import 'package:flutter/material.dart';
import '../theme.dart';

class MediaCaptionResult {
  final String caption;
  const MediaCaptionResult(this.caption);
}

/// Показывает превью медиа + поле подписи. Нельзя закрыть кнопкой назад.
/// Возвращает [MediaCaptionResult] при отправке, null при отмене.
Future<MediaCaptionResult?> showMediaCaptionSheet(
  BuildContext context, {
  required bool isVideo,
  required Widget preview,
}) {
  return showDialog<MediaCaptionResult>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: _MediaCaptionDialog(isVideo: isVideo, preview: preview),
    ),
  );
}

class _MediaCaptionDialog extends StatefulWidget {
  final bool isVideo;
  final Widget preview;
  const _MediaCaptionDialog({required this.isVideo, required this.preview});

  @override
  State<_MediaCaptionDialog> createState() => _MediaCaptionDialogState();
}

class _MediaCaptionDialogState extends State<_MediaCaptionDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Dialog(
      backgroundColor: AppTheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Превью
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
              child: widget.preview,
            ),
          ),
          // Поле подписи + кнопки
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(children: [
              // Отмена
              IconButton(
                icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                onPressed: () => Navigator.pop(context, null),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              const SizedBox(width: 8),
              // Поле ввода
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  maxLines: 3, minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Подпись...',
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Отправить
              GestureDetector(
                onTap: () => Navigator.pop(context, MediaCaptionResult(_ctrl.text.trim())),
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                  child: Icon(Icons.send_rounded, color: AppTheme.bg, size: 20),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
