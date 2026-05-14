import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/app_state.dart';
import '../theme.dart';

const _apkUrl = 'https://storage.yandexcloud.kz/skryvex-vendor-files/app-release.apk';
const _linuxUrl = 'https://storage.yandexcloud.kz/skryvex-vendor-files/Skryvex-linux.tar.xz';

class UpdateScreen extends StatefulWidget {
  const UpdateScreen({super.key});
  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  double? _progress;
  String _status = '';
  bool _done = false;
  String? _installPath;
  late TextEditingController _pathCtrl;

  bool get _isAndroid => !kIsWeb && Platform.isAndroid;
  bool get _isLinux => !kIsWeb && Platform.isLinux;

  @override
  void initState() {
    super.initState();
    _pathCtrl = TextEditingController(text: Platform.isLinux ? '${Platform.environment['HOME'] ?? ''}/skryvex' : '');
  }

  @override
  void dispose() {
    _pathCtrl.dispose();
    super.dispose();
  }

  Future<void> _download() async {
    if (_isAndroid) {
      await _downloadAndInstallApk();
    } else if (_isLinux) {
      await _downloadAndExtractLinux();
    }
  }

  Future<void> _downloadAndInstallApk() async {
    setState(() { _progress = 0; _status = 'Загрузка...'; });
    try {
      // Запрашиваем разрешение на установку из неизвестных источников
      if (!await Permission.requestInstallPackages.isGranted) {
        final status = await Permission.requestInstallPackages.request();
        if (!status.isGranted) {
          if (mounted) setState(() { _progress = -1; _status = 'Нет разрешения на установку приложений.\nРазрешите установку из неизвестных источников в настройках.'; });
          return;
        }
      }
      final dir = await getExternalStorageDirectory() ?? await getTemporaryDirectory();
      final file = File('${dir.path}/skryvex-update.apk');
      await _downloadFile(_apkUrl, file);
      if (!mounted) return;
      setState(() { _status = 'Запуск установки...'; });
      await OpenFile.open(file.path, type: 'application/vnd.android.package-archive');
      // НЕ сбрасываем флаг — система перезапустит приложение после установки
      // Если пользователь отменил установку — показываем кнопку повторить
      if (mounted) setState(() { _progress = null; _status = ''; });
    } catch (e) {
      if (mounted) setState(() { _progress = -1; _status = 'Ошибка: $e'; });
    }
  }

  Future<void> _downloadAndExtractLinux() async {
    final dir = _pathCtrl.text.trim();
    if (dir.isEmpty) return;
    _installPath = dir;

    setState(() { _progress = 0; _status = 'Загрузка...'; });
    try {
      final tmp = await getTemporaryDirectory();
      final archivePath = '${tmp.path}/skryvex-update.tar.xz';
      await _downloadFile(_linuxUrl, File(archivePath));
      if (!mounted) return;
      setState(() { _status = 'Подготовка...'; _progress = null; });

      final scriptPath = '${tmp.path}/skryvex_install.sh';
      await File(scriptPath).writeAsString(
        '#!/bin/sh\nsleep 1\nmkdir -p "$dir"\ntar -xJf "$archivePath" -C "$dir" --overwrite\nchmod +x "$dir/skryvex" 2>/dev/null || true\nrm -f "$archivePath" "$scriptPath"\n'
            .replaceAll(r'$dir', dir),
      );
      await Process.run('chmod', ['+x', scriptPath]);
      await Process.start('sh', [scriptPath], mode: ProcessStartMode.detached);

      if (!mounted) return;
      setState(() { _done = true; });
    } catch (e) {
      if (mounted) setState(() { _progress = -1; _status = 'Ошибка: $e'; });
    }
  }

  Future<void> _downloadFile(String url, File dest) async {
    final req = http.Request('GET', Uri.parse(url));
    final resp = await req.send();
    final total = resp.contentLength ?? 0;
    var received = 0;
    final sink = dest.openWrite();
    await for (final chunk in resp.stream) {
      sink.add(chunk);
      received += chunk.length;
      if (total > 0 && mounted) setState(() => _progress = received / total);
    }
    await sink.close();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return _DoneScreen(path: _installPath!);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.system_update_rounded, size: 64, color: AppTheme.orange),
                const SizedBox(height: 20),
                const Text('Доступно обновление', style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                const Text('Для продолжения работы необходимо обновить приложение.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                const SizedBox(height: 28),
                if (kIsWeb)
                  const Text('Обновление устанавливается автоматически.\nПожалуйста, подождите и обновите страницу.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary, fontSize: 14))
                else if (_progress == null && !_done) ...[
                  if (_isLinux) ...[
                    TextField(
                      controller: _pathCtrl,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Папка установки',
                        labelStyle: TextStyle(color: AppTheme.textSecondary),
                        hintText: '/home/user/skryvex',
                        hintStyle: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  ElevatedButton.icon(
                    onPressed: _download,
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Скачать и установить'),
                  ),
                ] else if (_progress == -1) ...[
                  Text(_status, style: const TextStyle(color: Colors.redAccent, fontSize: 13), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: () => setState(() { _progress = null; _status = ''; }), child: const Text('Повторить')),
                ] else ...[
                  if (_progress != null) ...[
                    LinearProgressIndicator(value: _progress, color: AppTheme.orange, backgroundColor: AppTheme.surfaceVariant),
                    const SizedBox(height: 10),
                    Text('${((_progress ?? 0) * 100).toStringAsFixed(0)}%', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  ] else
                    CircularProgressIndicator(color: AppTheme.orange),
                  const SizedBox(height: 8),
                  Text(_status, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DoneScreen extends StatelessWidget {
  final String path;
  const _DoneScreen({required this.path});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_outline_rounded, size: 64, color: Colors.green),
                const SizedBox(height: 20),
                const Text('Готово к установке', style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppTheme.surfaceVariant, borderRadius: BorderRadius.circular(8)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('После закрытия файлы распакуются в:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(path, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                    const SizedBox(height: 10),
                    const Text('Затем запустите:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('$path/skryvex', style: TextStyle(color: AppTheme.orange, fontSize: 13, fontFamily: 'monospace')),
                  ]),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () { AppState.instance.clearUpdateRequired(); exit(0); },
                  child: const Text('Закрыть'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
