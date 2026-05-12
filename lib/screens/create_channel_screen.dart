import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'adaptive_layout.dart';

class CreateChannelScreen extends StatefulWidget {
  const CreateChannelScreen({super.key});

  @override
  State<CreateChannelScreen> createState() => _CreateChannelScreenState();
}

class _CreateChannelScreenState extends State<CreateChannelScreen> {
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _saving = false;
  String? _error;
  Uint8List? _avatarBytes;
  String? _avatarFilename;

  @override
  void dispose() {
    _nameCtrl.dispose(); _usernameCtrl.dispose(); _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() { _avatarBytes = bytes; _avatarFilename = file.name; });
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    final username = _usernameCtrl.text.trim();
    if (name.isEmpty) { setState(() => _error = 'Введите название'); return; }
    if (username.isEmpty) { setState(() => _error = 'Введите username'); return; }
    setState(() { _saving = true; _error = null; });
    try {
      final data = await ApiService.post('/channels', {
        'name': name, 'username': username,
        if (_descCtrl.text.trim().isNotEmpty) 'description': _descCtrl.text.trim(),
      });
      if (data['error'] != null) { setState(() { _error = data['error'] as String; _saving = false; }); return; }
      var channel = ChannelModel.fromJson(data);
      // Загружаем аватар если выбран
      if (_avatarBytes != null) {
        try {
          final avatarData = await ApiService.uploadFile('/channels/${channel.id}/avatar', _avatarBytes!, _avatarFilename ?? 'avatar.jpg');
          if (avatarData['avatar_url'] != null) {
            channel = channel.copyWith(avatarUrl: avatarData['avatar_url'] as String);
          }
        } catch (_) {}
      }
      if (mounted) Navigator.pop(context, channel);
    } catch (_) {
      setState(() { _error = 'Ошибка создания канала'; _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Новый канал'),
        actions: [TextButton(
          onPressed: _saving ? null : _create,
          child: _saving
              ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: accent, strokeWidth: 2))
              : Text('Создать', style: TextStyle(color: accent)),
        )],
      ),
      body: Builder(builder: (context) {
        final list = ListView(padding: const EdgeInsets.all(24), children: [
          Center(child: GestureDetector(
            onTap: _pickAvatar,
            child: Stack(children: [
              CircleAvatar(
                radius: 44, backgroundColor: AppTheme.surfaceVariant,
                backgroundImage: _avatarBytes != null ? MemoryImage(_avatarBytes!) : null,
                child: _avatarBytes == null ? Icon(Icons.camera_alt, color: accent, size: 28) : null,
              ),
              Positioned(bottom: 0, right: 0, child: Container(
                width: 26, height: 26,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                child: const Icon(Icons.edit, color: AppTheme.bg, size: 14),
              )),
            ]),
          )),
          const SizedBox(height: 24),
          if (_error != null) ...[
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
            const SizedBox(height: 16),
          ],
          const Text('Название', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 6),
          TextField(controller: _nameCtrl, style: const TextStyle(color: AppTheme.textPrimary), maxLength: 100,
            decoration: const InputDecoration(hintText: 'Название канала', counterText: '')),
          const SizedBox(height: 20),
          const Text('Username', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 6),
          TextField(
            controller: _usernameCtrl, style: const TextStyle(color: AppTheme.textPrimary), maxLength: 30,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_]'))],
            decoration: InputDecoration(hintText: 'channel_name', prefixText: '@', prefixStyle: TextStyle(color: accent), counterText: ''),
          ),
          const SizedBox(height: 20),
          const Text('Описание (необязательно)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 6),
          TextField(controller: _descCtrl, style: const TextStyle(color: AppTheme.textPrimary), maxLines: 3, maxLength: 500,
            decoration: const InputDecoration(hintText: 'О чём этот канал?', counterText: '')),
        ]);
        return isDesktop(context) ? Center(child: SizedBox(width: 520, child: list)) : list;
      }),
    );
  }
}

// ── Edit channel screen ────────────────────────────────────────────────────

class EditChannelScreen extends StatefulWidget {
  final ChannelModel channel;
  const EditChannelScreen({super.key, required this.channel});

  @override
  State<EditChannelScreen> createState() => _EditChannelScreenState();
}

class _EditChannelScreenState extends State<EditChannelScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  bool _saving = false;
  bool _uploadingAvatar = false;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.channel.name);
    _descCtrl = TextEditingController(text: widget.channel.description ?? '');
    _avatarUrl = widget.channel.avatarUrl;
  }

  @override
  void dispose() { _nameCtrl.dispose(); _descCtrl.dispose(); super.dispose(); }

  Future<void> _pickAvatar() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _uploadingAvatar = true);
    try {
      final data = await ApiService.uploadFile('/channels/${widget.channel.id}/avatar', bytes, file.name);
      if (data['avatar_url'] != null && mounted) {
        setState(() { _avatarUrl = data['avatar_url'] as String; });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      // Пока просто закрываем — можно добавить PATCH /channels/:id
      if (mounted) Navigator.pop(context, widget.channel.copyWith(avatarUrl: _avatarUrl));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки канала'),
        actions: [TextButton(
          onPressed: _saving ? null : _save,
          child: Text('Готово', style: TextStyle(color: accent)),
        )],
      ),
      body: Builder(builder: (context) {
        final list = ListView(padding: const EdgeInsets.all(24), children: [
          Center(child: GestureDetector(
            onTap: _uploadingAvatar ? null : _pickAvatar,
            child: Stack(children: [
              CircleAvatar(
                radius: 44, backgroundColor: AppTheme.surfaceVariant,
                backgroundImage: _avatarUrl != null ? CachedNetworkImageProvider(_avatarUrl!, cacheKey: 'ch_avatar_${widget.channel.id}') : null,
                child: _avatarUrl == null ? Icon(Icons.camera_alt, color: accent, size: 28) : null,
              ),
              Positioned(bottom: 0, right: 0, child: Container(
                width: 26, height: 26,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                child: _uploadingAvatar
                    ? const Padding(padding: EdgeInsets.all(5), child: CircularProgressIndicator(color: AppTheme.bg, strokeWidth: 2))
                    : const Icon(Icons.edit, color: AppTheme.bg, size: 14),
              )),
            ]),
          )),
          const SizedBox(height: 24),
          const Text('Название', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 6),
          TextField(controller: _nameCtrl, style: const TextStyle(color: AppTheme.textPrimary), maxLength: 100,
            decoration: const InputDecoration(counterText: '')),
          const SizedBox(height: 20),
          const Text('Описание', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 6),
          TextField(controller: _descCtrl, style: const TextStyle(color: AppTheme.textPrimary), maxLines: 3, maxLength: 500,
            decoration: const InputDecoration(counterText: '')),
        ]);
        return isDesktop(context) ? Center(child: SizedBox(width: 520, child: list)) : list;
      }),
    );
  }
}
