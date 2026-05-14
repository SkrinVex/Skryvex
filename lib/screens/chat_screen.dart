import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/video_thumb.dart';
import '../services/upload_service.dart';
import '../theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import 'media_viewer.dart';
import 'download_sheet.dart';
import 'reactions_widget.dart';
import 'media_caption_sheet.dart';
import 'adaptive_layout.dart';
import 'user_profile_screen.dart';

class ChatScreen extends StatefulWidget {
  final int chatId;
  final String partnerName;
  final String? partnerAvatar;
  final int? partnerId;
  final bool isSelf;
  final bool isSystem;

  const ChatScreen({super.key, required this.chatId, required this.partnerName, this.partnerAvatar, this.partnerId, this.isSelf = false, this.isSystem = false});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final Map<int, GlobalKey> _msgKeys = {};

  final List<MessageModel> _messages = [];
  WebSocketChannel? _ws;
  int? _myId;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _showScrollDown = false;
  static const _pageSize = 40;
  MessageModel? _replyTo;
  int? _highlightedId;
  bool _uploading = false;
  double _uploadProgress = 0;
  Uint8List? _uploadPreviewBytes;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _msgCtrl.addListener(() {
      final has = _msgCtrl.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
    initializeDateFormatting('ru', null).then((_) => _init());
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userJson = prefs.getString('user');
    if (userJson != null) {
      _myId = (jsonDecode(userJson) as Map<String, dynamic>)['id'] as int?;
    }
    await _loadInitial();
    // Восстанавливаем состояние загрузки если она идёт в фоне
    final existing = UploadService.instance.stateFor(widget.chatId);
    if (existing != null && mounted) {
      setState(() {
        _uploading = true;
        _uploadProgress = existing.progress;
        _uploadPreviewBytes = existing.previewBytes;
      });
      final notifier = UploadService.instance.notifierFor(widget.chatId);
      void onProgress() {
        final s = notifier.value;
        if (!mounted) return;
        if (s == null) {
          setState(() { _uploading = false; _uploadProgress = 0; _uploadPreviewBytes = null; });
        } else {
          setState(() {
            _uploadProgress = s.progress;
            if (s.previewBytes != null) _uploadPreviewBytes = s.previewBytes;
          });
        }
      }
      notifier.addListener(onProgress);
    }
    _scrollCtrl.addListener(_onScroll);
    if (token != null) {
      _ws = WebSocketChannel.connect(Uri.parse('${ApiService.wsBase}?token=$token'));
      _ws!.sink.add(jsonEncode({'type': 'join', 'chatId': widget.chatId}));
      _ws!.stream.listen(_onWsMessage, onError: (_) {}, onDone: () {});
    }
  }

  void _onScroll() {
    // reverse:true — верх списка = большой offset, низ = 0
    // Догрузка при прокрутке к верху
    if (_scrollCtrl.position.pixels > _scrollCtrl.position.maxScrollExtent - 200 && !_loadingMore && _hasMore) {
      _loadMore();
    }
    // Кнопка прокрутки вниз — показываем когда далеко от низа (offset > 400)
    final show = _scrollCtrl.position.pixels > 400;
    if (show != _showScrollDown) setState(() => _showScrollDown = show);
  }

  Future<void> _loadInitial() async {
    try {
      final data = await ApiService.get(
        '/chats/${widget.chatId}/messages?limit=$_pageSize',
      ) as List<dynamic>;
      await CacheService.saveMessages(widget.chatId, data);
      final msgs = data.map((e) => MessageModel.fromJson(e as Map<String, dynamic>)).toList();
      if (!mounted) return;
      for (final m in msgs) { _msgKeys[m.id] = GlobalKey(); }
      setState(() {
        _messages.clear();
        _messages.addAll(msgs);
        _loading = false;
        _hasMore = msgs.length == _pageSize;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _messages.isEmpty) return;
    setState(() => _loadingMore = true);
    final beforeId = _messages.first.id;
    try {
      final data = await ApiService.get(
        '/chats/${widget.chatId}/messages?limit=$_pageSize&before=$beforeId',
      ) as List<dynamic>;
      final msgs = data.map((e) => MessageModel.fromJson(e as Map<String, dynamic>)).toList();
      if (!mounted) return;
      for (final m in msgs) { _msgKeys[m.id] = GlobalKey(); }
      // reverse:true — вставка в начало списка = добавление вверху экрана
      // позиция скролла не прыгает автоматически
      setState(() {
        _messages.insertAll(0, msgs);
        _hasMore = msgs.length == _pageSize;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onWsMessage(dynamic raw) {
    final msg = jsonDecode(raw as String) as Map<String, dynamic>;
    if (msg['type'] == 'message') {
      final m = MessageModel.fromJson(msg);
      if (m.chatId == widget.chatId) {
        // Если это наше медиа-сообщение — скрываем bubble только после добавления в список
        final wasUploading = _uploading && m.senderId == _myId && m.mediaType != null;
        setState(() {
          _messages.add(m);
          _msgKeys[m.id] = GlobalKey();
          if (wasUploading) { _uploading = false; _uploadProgress = 0; _uploadPreviewBytes = null; }
        });
        _scrollToBottom();
        CacheService.invalidateMessages(widget.chatId);
        CacheService.invalidateChats();
      }
    }
    if (msg['type'] == 'message_deleted') {
      final id = msg['id'] as int;
      setState(() => _messages.removeWhere((m) => m.id == id));
      CacheService.invalidateMessages(widget.chatId);
    }
    if (msg['type'] == 'reaction_update') {
      final msgId = msg['message_id'] as int;
      final reactions = (msg['reactions'] as List).map((e) => ReactionModel.fromJson(e as Map<String, dynamic>)).toList();
      final idx = _messages.indexWhere((m) => m.id == msgId);
      if (idx != -1 && mounted) setState(() => _messages[idx] = _messages[idx].copyWithReactions(reactions));
    }
  }

  void _scrollToBottom({bool jump = false}) {
    if (!_scrollCtrl.hasClients) return;
    if (jump) {
      _scrollCtrl.jumpTo(0);
    } else {
      _scrollCtrl.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  Future<void> _scrollToMessage(int messageId) async {
    // reverse:true — ищем индекс в перевёрнутом списке
    final idx = _messages.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;
    final reversedIdx = _messages.length - 1 - idx;
    final key = _msgKeys[messageId];
    if (key?.currentContext == null) {
      // Элемент вне viewport — прыгаем к краю и ждём рендера
      _scrollCtrl.jumpTo(reversedIdx < _messages.length / 2
          ? 0
          : _scrollCtrl.position.maxScrollExtent);
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;
    }
    final k = _msgKeys[messageId];
    if (k?.currentContext == null) return;
    await Scrollable.ensureVisible(k!.currentContext!,
        duration: const Duration(milliseconds: 350), curve: Curves.easeOut, alignment: 0.3);
    setState(() => _highlightedId = messageId);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) setState(() => _highlightedId = null);
  }

  void _send() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _ws == null) return;
    _ws!.sink.add(jsonEncode({
      'type': 'message',
      'text': text,
      if (_replyTo != null) 'reply_to_id': _replyTo!.id,
    }));
    _msgCtrl.clear();
    setState(() => _replyTo = null);
  }

  Future<void> _pickAndSendMedia(ImageSource source, {bool video = false}) async {
    final picker = ImagePicker();
    final file = video
        ? await picker.pickVideo(source: source, maxDuration: const Duration(minutes: 5))
        : await picker.pickImage(source: source, imageQuality: 85);
    if (file == null) return;

    final bytes = await file.readAsBytes();

    // Показываем диалог подписи
    if (!mounted) return;
    final result = await showMediaCaptionSheet(
      context,
      isVideo: video,
      preview: video
          ? Container(height: 200, color: Colors.black, child: const Center(child: Icon(Icons.videocam, color: AppTheme.textSecondary, size: 48)))
          : Image.memory(bytes, fit: BoxFit.contain),
    );
    if (result == null) return; // отмена

    final replyToId = _replyTo?.id;
    setState(() { _replyTo = null; _uploading = true; _uploadProgress = 0; });

    Uint8List? preview;
    if (!video) {
      preview = bytes;
      _uploadPreviewBytes = bytes;
    } else {
      _generateLocalVideoThumb(file.path);
    }
    _scrollToBottom();

    // Слушаем прогресс из сервиса
    final notifier = UploadService.instance.notifierFor(widget.chatId);
    void onProgress() {
      final s = notifier.value;
      if (!mounted) return;
      if (s == null) {
        setState(() { _uploading = false; _uploadProgress = 0; _uploadPreviewBytes = null; });
      } else {
        setState(() {
          _uploadProgress = s.progress;
          if (s.previewBytes != null) _uploadPreviewBytes = s.previewBytes;
        });
      }
    }
    notifier.addListener(onProgress);

    try {
      await UploadService.instance.upload(
        chatId: widget.chatId,
        bytes: bytes,
        filename: file.name,
        isVideo: video,
        previewBytes: preview,
        replyToId: replyToId,
        caption: result.caption.isNotEmpty ? result.caption : null,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка отправки файла')),
        );
      }
    } finally {
      notifier.removeListener(onProgress);
      if (mounted) setState(() { _uploading = false; _uploadProgress = 0; _uploadPreviewBytes = null; });
    }
  }

  Future<void> _deleteMessage(MessageModel msg) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Удалить сообщение?', style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text('Сообщение будет удалено для всех участников.',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService.delete('/chats/${widget.chatId}/messages/${msg.id}');
      setState(() => _messages.removeWhere((m) => m.id == msg.id));
      CacheService.invalidateMessages(widget.chatId);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка удаления')),
        );
      }
    }
  }

  void _showMessageMenu(BuildContext context, MessageModel msg) {
    // Системные сообщения (sender_id = null) — только копирование текста
    if (msg.senderId == null) {
      if (msg.text != null && msg.text!.isNotEmpty) {
        Clipboard.setData(ClipboardData(text: msg.text!));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Скопировано')));
      }
      return;
    }
    final isMe = msg.senderId == _myId;
    final hasMedia = msg.mediaUrl != null && !msg.mediaDeleted;
    showReactionPickerWithMenu(
      context,
      menuItems: [
        ListTile(
          leading: Icon(Icons.reply, color: AppTheme.orange),
          title: const Text('Ответить', style: TextStyle(color: AppTheme.textPrimary)),
          onTap: () { Navigator.pop(context); setState(() => _replyTo = msg); },
        ),
        if (msg.text != null && msg.text!.isNotEmpty) ListTile(
          leading: Icon(Icons.copy, color: AppTheme.orange),
          title: const Text('Копировать', style: TextStyle(color: AppTheme.textPrimary)),
          onTap: () { Navigator.pop(context); Clipboard.setData(ClipboardData(text: msg.text!)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сообщение скопировано'))); },
        ),
        if (hasMedia) ListTile(
          leading: Icon(Icons.download, color: AppTheme.orange),
          title: const Text('Сохранить', style: TextStyle(color: AppTheme.textPrimary)),
          onTap: () { Navigator.pop(context); showDownloadSheet(context, url: msg.mediaUrl!, filename: '${msg.mediaType}_${msg.id}.${msg.mediaType == 'video' ? 'mp4' : 'jpg'}'); },
        ),
        if (isMe) ListTile(
          leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
          title: const Text('Удалить', style: TextStyle(color: Colors.redAccent)),
          onTap: () { Navigator.pop(context); _deleteMessage(msg); },
        ),
      ],
    ).then((emoji) { if (emoji != null) _toggleReaction(msg.id, emoji); });
  }

  Future<void> _toggleReaction(int messageId, String emoji) async {
    try {
      final data = await ApiService.post('/chats/${widget.chatId}/messages/$messageId/react', {'emoji': emoji});
      final reactions = (data['reactions'] as List).map((e) => ReactionModel.fromJson(e as Map<String, dynamic>)).toList();
      final idx = _messages.indexWhere((m) => m.id == messageId);
      if (idx != -1 && mounted) setState(() => _messages[idx] = _messages[idx].copyWithReactions(reactions));
    } catch (_) {}
  }

  Future<void> _resolveAction(MessageModel msg, String action) async {
    try {
      await ApiService.post('/chats/${widget.chatId}/messages/${msg.id}/action', {'action': action});
      final idx = _messages.indexWhere((m) => m.id == msg.id);
      if (idx != -1 && mounted) {
        setState(() => _messages[idx] = _messages[idx].copyWithActionResolved());
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ошибка')));
    }
  }

  void _cancelUpload() {
    UploadService.instance.cancel(widget.chatId);
  }

  Future<void> _generateLocalVideoThumb(String path) async {
    final thumb = await generateLocalVideoThumbnail(path);
    if (thumb != null) {
      UploadService.instance.updatePreview(widget.chatId, thumb);
      if (mounted) setState(() => _uploadPreviewBytes = thumb);
    }
  }

  void _showMediaPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo, color: AppTheme.orange),
              title: const Text('Фото из галереи', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () { Navigator.pop(context); _pickWithTtlWarning(ImageSource.gallery); },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt, color: AppTheme.orange),
              title: const Text('Сделать фото', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () { Navigator.pop(context); _pickWithTtlWarning(ImageSource.camera); },
            ),
            ListTile(
              leading: Icon(Icons.videocam, color: AppTheme.orange),
              title: const Text('Видео из галереи', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () { Navigator.pop(context); _pickWithTtlWarning(ImageSource.gallery, video: true); },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickWithTtlWarning(ImageSource source, {bool video = false}) async {
    final shown = await CacheService.hasShownMediaTtlWarning();
    if (!shown && mounted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('Важно о медиафайлах', style: TextStyle(color: AppTheme.textPrimary)),
          content: const Text(
            'Фотографии и видео автоматически удаляются через 7 дней.\n\n'
            'Чтобы сохранить файл, зажмите на сообщение и выберите «Сохранить».',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Понятно', style: TextStyle(color: AppTheme.orange)),
            ),
          ],
        ),
      );
      if (confirmed == true) await CacheService.setMediaTtlWarningShown();
    }
    if (mounted) _pickAndSendMedia(source, video: video);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _ws?.sink.close();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        title: GestureDetector(
          onTap: (!widget.isSelf && !widget.isSystem && widget.partnerId != null)
              ? () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => UserProfileScreen(userId: widget.partnerId),
                  ))
              : null,
          child: Row(
          children: [
            if (widget.isSelf)
              CircleAvatar(
                radius: 18,
                backgroundColor: accent.withValues(alpha: 0.15),
                child: Icon(Icons.bookmark, color: accent, size: 18),
              )
            else if (widget.isSystem)
              CircleAvatar(
                radius: 18,
                backgroundColor: accent.withValues(alpha: 0.15),
                child: Icon(Icons.notifications, color: accent, size: 18),
              )
            else
              CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.surfaceVariant,
                backgroundImage: widget.partnerAvatar != null
                    ? CachedNetworkImageProvider(widget.partnerAvatar!, cacheKey: 'avatar_${widget.chatId}_partner')
                    : null,
                child: widget.partnerAvatar == null
                    ? Text(widget.partnerName.isNotEmpty ? widget.partnerName[0].toUpperCase() : '?',
                        style: TextStyle(color: AppTheme.orange, fontSize: 14, fontWeight: FontWeight.w600))
                    : null,
              ),
            const SizedBox(width: 10),
            Text(widget.isSelf ? 'Избранное' : widget.partnerName),
          ],
        ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
          padding: const EdgeInsets.only(left: 8),
        ),
        backgroundColor: AppTheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
      ),
      body: Center(
        child: SizedBox(
          width: isDesktop(context) ? 760 : double.infinity,
          child: Column(
          children: [
          Expanded(
            child: Stack(
              children: [
                _loading
                ? Center(child: CircularProgressIndicator(color: AppTheme.orange))
                : _messages.isEmpty
                    ? Center(
                        child: Text('Начните переписку',
                            style: TextStyle(color: AppTheme.textSecondary)))
                    : ListView.builder(
                          controller: _scrollCtrl,
                          reverse: true,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          itemCount: _messages.length + (_uploading ? 1 : 0) + (_loadingMore ? 1 : 0),
                          itemBuilder: (_, i) {
                            // reverse:true — i=0 это последнее (новое) сообщение
                            // Первый элемент (i=0) — превью загружаемого файла
                            if (_uploading && i == 0) {
                              return GestureDetector(
                                onLongPress: _cancelUpload,
                                child: _UploadingBubble(
                                  previewBytes: _uploadPreviewBytes,
                                  progress: _uploadProgress,
                                ),
                              );
                            }
                            final uploadOffset = _uploading ? 1 : 0;
                            // Последний элемент — индикатор загрузки старых сообщений (вверху)
                            if (_loadingMore && i == _messages.length + uploadOffset) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppTheme.orange, strokeWidth: 2))),
                              );
                            }
                            // Индекс в _messages: reverse — новые в конце списка, i=0 = последнее
                            final msgIdx = _messages.length - 1 - (i - uploadOffset);
                            if (msgIdx < 0 || msgIdx >= _messages.length) return const SizedBox.shrink();
                            final msg = _messages[msgIdx];
                            final showDate = msgIdx == 0 ||
                                !_sameDay(_messages[msgIdx - 1].createdAt, msg.createdAt);
                            return _SwipeableMessage(
                              key: _msgKeys[msg.id],
                              message: msg,
                              isMe: msg.senderId == _myId,
                              showDate: showDate,
                              isHighlighted: _highlightedId == msg.id,
                              onReply: () => setState(() => _replyTo = msg),
                              onLongPress: () => _showMessageMenu(context, msg),
                              onTapReply: msg.replyToId != null
                                  ? () => _scrollToMessage(msg.replyToId!)
                                  : null,
                              onReact: (emoji) => _toggleReaction(msg.id, emoji),
                              onAction: msg.actionData != null
                                  ? (action) => _resolveAction(msg, action)
                                  : null,
                            );
                          },
                        ),
                // Кнопка прокрутки вниз
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  bottom: _showScrollDown ? 12 : -56,
                  right: 12,
                  child: FloatingActionButton.small(
                    backgroundColor: AppTheme.surface,
                    onPressed: _scrollToBottom,
                    child: Icon(Icons.keyboard_arrow_down, color: AppTheme.orange),
                  ),
                ),
              ],
            ),
          ),
          if (_replyTo != null) _ReplyPreview(
            message: _replyTo!,
            isMe: _replyTo!.senderId == _myId,
            onCancel: () => setState(() => _replyTo = null),
            onTap: () => _scrollToMessage(_replyTo!.id),
          ),
          if (!widget.isSystem) _InputBar(
            controller: _msgCtrl,
            onSend: _send,
            onAttach: _showMediaPicker,
            hasText: _hasText,
            hasReply: _replyTo != null,
          ),
        ],
      ),
        ),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ── Swipeable message ──────────────────────────────────────────────────────

class _SwipeableMessage extends StatefulWidget {
  final MessageModel message;
  final bool isMe;
  final bool showDate;
  final bool isHighlighted;
  final VoidCallback onReply;
  final VoidCallback onLongPress;
  final VoidCallback? onTapReply;
  final void Function(String)? onReact;
  final void Function(String action)? onAction;

  const _SwipeableMessage({
    super.key,
    required this.message,
    required this.isMe,
    required this.showDate,
    required this.isHighlighted,
    required this.onReply,
    required this.onLongPress,
    this.onTapReply,
    this.onReact,
    this.onAction,
  });

  @override
  State<_SwipeableMessage> createState() => _SwipeableMessageState();
}

class _SwipeableMessageState extends State<_SwipeableMessage>
    with SingleTickerProviderStateMixin {
  double _dragX = 0;
  bool _triggered = false;
  late AnimationController _snapCtrl;
  late Animation<double> _snapAnim;

  @override
  void initState() {
    super.initState();
    _snapCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _snapAnim = Tween<double>(begin: 0, end: 0).animate(_snapCtrl);
    _snapCtrl.addListener(() => setState(() => _dragX = _snapAnim.value));
  }

  @override
  void dispose() {
    _snapCtrl.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    final dx = d.delta.dx;
    // Свайп вправо для чужих сообщений, влево для своих
    final isCorrectDirection = widget.isMe ? dx < 0 : dx > 0;
    if (!isCorrectDirection && _dragX == 0) return;

    final newX = (_dragX + dx).clamp(
      widget.isMe ? -70.0 : 0.0,
      widget.isMe ? 0.0 : 70.0,
    );
    setState(() => _dragX = newX);

    if (_dragX.abs() >= 65 && !_triggered) {
      _triggered = true;
      HapticFeedback.lightImpact();
      widget.onReply();
    }
  }

  void _onDragEnd(DragEndDetails _) {
    _triggered = false;
    _snapAnim = Tween<double>(begin: _dragX, end: 0).animate(
      CurvedAnimation(parent: _snapCtrl, curve: Curves.easeOut),
    );
    _snapCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm').format(widget.message.createdAt.toLocal());

    // Системное сообщение (sender_id = null) — центрированный bubble
    if (widget.message.senderId == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showDate)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(_formatDate(widget.message.createdAt),
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ),
            ),
          GestureDetector(
            onLongPress: widget.onLongPress,
            child: Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.message.text != null)
                      Text(widget.message.text!, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                    if (widget.message.actionData != null &&
                        widget.message.actionData!['type'] == 'join_request' &&
                        widget.message.actionData!['resolved'] != true)
                      _JoinRequestActions(message: widget.message, onAction: widget.onAction),
                    if (widget.message.actionData != null && widget.message.actionData!['resolved'] == true)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('Обработано', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      ),
                    const SizedBox(height: 4),
                    Text(time, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showDate)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(_formatDate(widget.message.createdAt),
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ),
          ),
        GestureDetector(
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          onLongPress: widget.onLongPress,
          behavior: HitTestBehavior.translucent,
          child: Transform.translate(
            offset: Offset(_dragX, 0),
            child: Stack(
              children: [
                // Reply arrow hint
                Positioned(
                  left: widget.isMe ? null : 0,
                  right: widget.isMe ? 0 : null,
                  top: 0,
                  bottom: 0,
                  child: AnimatedOpacity(
                    opacity: (_dragX.abs() / 50).clamp(0.0, 1.0),
                    duration: const Duration(milliseconds: 50),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        Icons.reply_rounded,
                        color: AppTheme.orange,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.72),
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: widget.isHighlighted
                          ? AppTheme.orange.withValues(alpha: 0.3)
                          : widget.isMe
                              ? AppTheme.orangeDim
                              : AppTheme.surfaceVariant,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(widget.isMe ? 16 : 4),
                        bottomRight: Radius.circular(widget.isMe ? 4 : 16),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Reply preview inside bubble
                        if (widget.message.replyToId != null)
                          GestureDetector(
                            onTap: widget.onTapReply,
                            child: Container(
                              margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: widget.isMe
                                    ? Colors.black.withValues(alpha: 0.15)
                                    : AppTheme.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border(
                                  left: BorderSide(color: AppTheme.orange, width: 3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.message.replySenderName ?? '',
                                    style: TextStyle(
                                      color: AppTheme.orange,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _replyBubbleText(widget.message),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(                                      color: widget.isMe
                                          ? AppTheme.bg.withValues(alpha: 0.7)
                                          : AppTheme.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Медиа
                              if (widget.message.mediaType != null)
                                _MediaContent(
                                  message: widget.message,
                                  isMe: widget.isMe,
                                ),
                              // Текст
                              if (widget.message.text != null && widget.message.text!.isNotEmpty)
                                _LinkText(
                                  text: widget.message.text!,
                                  textColor: widget.isMe ? AppTheme.bg : AppTheme.textPrimary,
                                ),
                              // Кнопки действий (заявки в группу)
                              if (widget.message.actionData != null &&
                                  widget.message.actionData!['type'] == 'join_request' &&
                                  widget.message.actionData!['resolved'] != true)
                                _JoinRequestActions(
                                  message: widget.message,
                                  onAction: widget.onAction,
                                ),
                              const SizedBox(height: 3),
                              Text(
                                time,
                                style: TextStyle(
                                  color: widget.isMe
                                      ? AppTheme.bg.withValues(alpha: 0.6)
                                      : AppTheme.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Реакции под bubble
        if (widget.message.reactions.isNotEmpty)
          Align(
            alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: ChatReactionsRow(
              reactions: widget.message.reactions,
              onTap: (emoji) => widget.onReact?.call(emoji),
            ),
          ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final local = dt.toLocal();
    if (local.year == now.year && local.month == now.month && local.day == now.day) {
      return 'Сегодня';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (local.year == yesterday.year &&
        local.month == yesterday.month &&
        local.day == yesterday.day) { return 'Вчера'; }
    return DateFormat('d MMMM', 'ru').format(local);
  }
}

// ── Uploading bubble (локальный превью) ────────────────────────────────────

class _UploadingBubble extends StatelessWidget {
  final Uint8List? previewBytes;
  final double progress;
  const _UploadingBubble({this.previewBytes, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: AppTheme.orangeDim,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          ),
          child: Stack(
            children: [
              // Превью файла
              if (previewBytes != null)
                Image.memory(
                  previewBytes!,
                  width: 220,
                  height: 160,
                  fit: BoxFit.cover,
                )
              else
                Container(
                  width: 220,
                  height: 100,
                  color: Colors.black38,
                  child: const Center(
                    child: Icon(Icons.videocam, color: AppTheme.textSecondary, size: 36),
                  ),
                ),
              // Оверлей с прогрессом
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.45),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 52, height: 52,
                        child: CircularProgressIndicator(
                          value: progress > 0 ? progress : null,
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      ),
                      if (progress > 0) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Video thumbnail widget ─────────────────────────────────────────────────

class _VideoThumbnail extends StatefulWidget {
  final String url;
  final bool isMe;
  const _VideoThumbnail({required this.url, required this.isMe});

  @override
  State<_VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<_VideoThumbnail> {
  Uint8List? _thumb;
  bool _deleted = false;

  @override
  void initState() {
    super.initState();
    generateVideoThumbnail(widget.url).then((result) {
      if (mounted) {
        setState(() {
          _thumb = result.bytes;
          _deleted = result.deleted;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_deleted) {
      return GestureDetector(
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Медиафайл удалён — срок хранения истёк (7 дней)')),
        ),
        child: _deletedMedia(isMe: widget.isMe),
      );
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => VideoPlayerScreen(
          url: widget.url,
          onError: () {
            if (mounted) setState(() => _deleted = true);
          },
        )),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 220,
          height: 140,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_thumb != null)
                Image.memory(_thumb!, fit: BoxFit.cover)
              else
                Container(
                  color: Colors.black54,
                  child: Center(
                    child: SizedBox(
                      width: 24, height: 24,
                      child: CircularProgressIndicator(color: AppTheme.orange, strokeWidth: 2),
                    ),
                  ),
                ),
              Center(
                child: Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _deletedMedia({required bool isMe}) {
  return Container(
    width: 220,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.delete_outline, size: 18,
            color: isMe ? AppTheme.bg.withValues(alpha: 0.5) : AppTheme.textSecondary),
        const SizedBox(width: 6),
        Text('Медиа удалено',
            style: TextStyle(
              color: isMe ? AppTheme.bg.withValues(alpha: 0.5) : AppTheme.textSecondary,
              fontSize: 13,
              fontStyle: FontStyle.italic,
            )),
      ],
    ),
  );
}

// ── Media content ──────────────────────────────────────────────────────────

class _MediaContent extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  const _MediaContent({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    if (message.mediaDeleted) {
      return GestureDetector(
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Медиафайл удалён — срок хранения истёк (7 дней)'),
            duration: Duration(seconds: 3),
          ),
        ),
        child: _deletedMedia(isMe: isMe),
      );
    }

    if (message.mediaType == 'image' && message.mediaUrl != null) {
      return GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PhotoViewScreen(
            url: message.mediaUrl!,
            cacheKey: 'msg_img_${message.id}',
          )),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: message.mediaUrl!,
            cacheKey: 'msg_img_${message.id}',
            width: 220,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              width: 220, height: 160,
              color: Colors.black26,
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.orange, strokeWidth: 2),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              width: 220, height: 80,
              color: Colors.black26,
              child: const Center(child: Icon(Icons.broken_image, color: AppTheme.textSecondary)),
            ),
          ),
        ),
      );
    }

    if (message.mediaType == 'video' && message.mediaUrl != null) {
      return _VideoThumbnail(url: message.mediaUrl!, isMe: isMe);
    }

    return const SizedBox.shrink();
  }
}

String _replyPreviewText(MessageModel m) {
  if (m.mediaDeleted) return '🗑 Медиа удалено';
  if (m.mediaType == 'image') return '📷 Фото';
  if (m.mediaType == 'video') return '🎥 Видео';
  return m.text ?? '';
}

String _replyBubbleText(MessageModel m) {
  if (m.replyMediaDeleted) return '🗑 Медиа удалено';
  if (m.replyMediaType == 'image') return '📷 Фото';
  if (m.replyMediaType == 'video') return '🎥 Видео';
  return m.replyText ?? '';
}

// ── Reply preview bar ──────────────────────────────────────────────────────

class _ReplyPreview extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final VoidCallback onCancel;
  final VoidCallback onTap;

  const _ReplyPreview({
    required this.message,
    required this.isMe,
    required this.onCancel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Container(width: 3, height: 36, color: AppTheme.orange,
                margin: const EdgeInsets.only(right: 10)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isMe ? 'Вы' : (message.senderName ?? 'Система'),
                    style: TextStyle(
                        color: AppTheme.orange, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    _replyPreviewText(message),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: AppTheme.textSecondary, size: 20),
              onPressed: onCancel,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Input bar ──────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final bool hasText;
  final bool hasReply;

  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.onAttach,
    required this.hasText,
    required this.hasReply,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: hasReply
            ? BorderRadius.zero
            : const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.attach_file, color: AppTheme.textSecondary),
              onPressed: onAttach,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                style: const TextStyle(color: AppTheme.textPrimary),
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Сообщение...',
                  // Убираем обводку фокуса
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: hasText ? onSend : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: hasText ? AppTheme.orange : AppTheme.surfaceVariant,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.send_rounded,
                  color: hasText ? AppTheme.bg : AppTheme.textSecondary,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Link-aware text ────────────────────────────────────────────────────────

final _urlRegex = RegExp(
  r'https?://[^\s<>"]+|www\.[^\s<>"]+|[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}|(?<![@\w])[a-zA-Z0-9](?:[a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)+(?:/[^\s<>"]*)?',
  caseSensitive: false,
);

class _LinkText extends StatelessWidget {
  final String text;
  final Color textColor;
  const _LinkText({required this.text, required this.textColor});

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    int last = 0;
    for (final m in _urlRegex.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      final url = m.group(0)!;
      spans.add(WidgetSpan(
        child: GestureDetector(
          onTap: () => _showLinkDialog(context, url),
          child: Text(
            url,
            style: TextStyle(
              color: AppTheme.orange,
              fontSize: 15,
              decoration: TextDecoration.underline,
              decorationColor: AppTheme.orange,
            ),
          ),
        ),
      ));
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));

    return RichText(
      text: TextSpan(
        style: TextStyle(color: textColor, fontSize: 15),
        children: spans,
      ),
    );
  }

  void _showLinkDialog(BuildContext context, String url) {
    final isEmail = RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$').hasMatch(url);
    final fullUrl = isEmail ? 'mailto:$url' : (url.startsWith('http') ? url : 'https://$url');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        content: Text(url, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Clipboard.setData(ClipboardData(text: url));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(isEmail ? 'Email скопирован' : 'Ссылка скопирована')),
              );
            },
            child: const Text('Копировать'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final uri = Uri.parse(fullUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: Text(isEmail ? 'Написать' : 'Открыть', style: TextStyle(color: AppTheme.orange)),
          ),
        ],
      ),
    );
  }
}

// ── Join request action buttons ────────────────────────────────────────────

class _JoinRequestActions extends StatelessWidget {
  final MessageModel message;
  final void Function(String action)? onAction;

  const _JoinRequestActions({required this.message, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: TextButton(
              onPressed: () => onAction?.call('reject'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.redAccent,
                backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text('Отклонить', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextButton(
              onPressed: () => onAction?.call('accept'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: AppTheme.orange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text('Принять', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
