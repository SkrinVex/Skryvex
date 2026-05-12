import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/upload_service.dart';
import '../theme.dart';
import 'media_viewer.dart';
import 'download_sheet.dart';

import 'media_caption_sheet.dart';
import 'create_channel_screen.dart';

class ChannelScreen extends StatefulWidget {
  final ChannelModel channel;
  const ChannelScreen({super.key, required this.channel});

  @override
  State<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends State<ChannelScreen> {
  final _scrollCtrl = ScrollController();
  final _textCtrl = TextEditingController();
  final List<ChannelPostModel> _posts = [];
  late ChannelModel _channel;
  final Map<int, GlobalKey> _postKeys = {};
  WebSocketChannel? _ws;
  int? _myId;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _isOwner = false;
  bool _uploading = false;
  double _uploadProgress = 0;
  Uint8List? _uploadPreview;
  int? _highlightedId;
  ChannelPostModel? _replyTo;
  static const _pageSize = 40;

  @override
  void initState() {
    super.initState();
    _channel = widget.channel;
    _init();
  }

  Future<void> _init() async {
    await initializeDateFormatting('ru', null);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userJson = prefs.getString('user');
    if (userJson != null) {
      _myId = (jsonDecode(userJson) as Map<String, dynamic>)['id'] as int?;
      _isOwner = _myId == _channel.ownerId;
    }
    await _loadPosts();
    _scrollCtrl.addListener(_onScroll);
    if (token != null) {
      _ws = WebSocketChannel.connect(Uri.parse('${ApiService.wsBase}?token=$token'));
      _ws!.sink.add(jsonEncode({'type': 'join_channel', 'channelId': _channel.id}));
      _ws!.stream.listen(_onWs, onError: (_) {}, onDone: () {});
    }
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels > _scrollCtrl.position.maxScrollExtent - 200 && !_loadingMore && _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadPosts() async {
    try {
      final data = await ApiService.get('/channels/${_channel.id}/posts?limit=$_pageSize') as List;
      if (!mounted) return;
      final posts = data.map((e) => ChannelPostModel.fromJson(e as Map<String, dynamic>)).toList();
      for (final p in posts) { _postKeys[p.id] = GlobalKey(); }
      setState(() { _posts.addAll(posts); _loading = false; _hasMore = posts.length == _pageSize; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _posts.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final data = await ApiService.get('/channels/${_channel.id}/posts?limit=$_pageSize&before=${_posts.first.id}') as List;
      final posts = data.map((e) => ChannelPostModel.fromJson(e as Map<String, dynamic>)).toList();
      if (!mounted) return;
      for (final p in posts) { _postKeys[p.id] = GlobalKey(); }
      setState(() { _posts.insertAll(0, posts); _hasMore = posts.length == _pageSize; _loadingMore = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onWs(dynamic raw) {
    final msg = jsonDecode(raw as String) as Map<String, dynamic>;
    if (msg['type'] == 'channel_post') {
      final p = ChannelPostModel.fromJson(msg);
      if (p.channelId == _channel.id) {
        setState(() { _posts.add(p); _postKeys[p.id] = GlobalKey(); });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollCtrl.hasClients) {
            _scrollCtrl.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
          }
        });
      }
    }
    if (msg['type'] == 'channel_post_deleted') {
      final id = msg['id'] as int;
      setState(() => _posts.removeWhere((p) => p.id == id));
    }
  }

  Future<void> _sendText() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    final replyId = _replyTo?.id;
    setState(() => _replyTo = null);
    try {
      await ApiService.post('/channels/${_channel.id}/posts', {
        'text': text,
        if (replyId != null) 'reply_to_id': replyId,
      });
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ошибка отправки')));
    }
  }

  Future<void> _pickMedia({bool video = false}) async {
    final file = video
        ? await ImagePicker().pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 5))
        : await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();

    if (!mounted) return;
    final result = await showMediaCaptionSheet(
      context,
      isVideo: video,
      preview: video
          ? Container(height: 200, color: Colors.black, child: const Center(child: Icon(Icons.videocam, color: AppTheme.textSecondary, size: 48)))
          : Image.memory(bytes, fit: BoxFit.contain),
    );
    if (result == null) return;

    setState(() { _uploading = true; _uploadProgress = 0; if (!video) _uploadPreview = bytes; });

    final notifier = UploadService.instance.notifierFor(-_channel.id);
    void onProgress() {
      final s = notifier.value;
      if (!mounted) return;
      if (s == null) { setState(() { _uploading = false; _uploadProgress = 0; _uploadPreview = null; }); }
      else { setState(() { _uploadProgress = s.progress; if (s.previewBytes != null) _uploadPreview = s.previewBytes; }); }
    }
    notifier.addListener(onProgress);
    try {
      await UploadService.instance.upload(
        chatId: -_channel.id,
        bytes: bytes, filename: file.name, isVideo: video,
        previewBytes: video ? null : bytes,
        caption: result.caption.isNotEmpty ? result.caption : null,
        customPath: '/channels/${_channel.id}/posts/media',
      );
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ошибка загрузки')));
    } finally {
      notifier.removeListener(onProgress);
      if (mounted) setState(() { _uploading = false; _uploadProgress = 0; _uploadPreview = null; });
    }
  }

  Future<void> _scrollToPost(int postId) async {
    final idx = _posts.indexWhere((p) => p.id == postId);
    if (idx == -1) return;
    final reversedIdx = _posts.length - 1 - idx;
    final key = _postKeys[postId];
    if (key?.currentContext == null) {
      _scrollCtrl.jumpTo(reversedIdx < _posts.length / 2
          ? 0
          : _scrollCtrl.position.maxScrollExtent);
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;
    }
    final k = _postKeys[postId];
    if (k?.currentContext == null) return;
    await Scrollable.ensureVisible(k!.currentContext!,
        duration: const Duration(milliseconds: 350), curve: Curves.easeOut, alignment: 0.3);
    setState(() => _highlightedId = postId);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) setState(() => _highlightedId = null);
  }

  Future<void> _deletePost(ChannelPostModel post) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Удалить пост?', style: TextStyle(color: AppTheme.textPrimary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.delete('/channels/${_channel.id}/posts/${post.id}');
      setState(() => _posts.removeWhere((p) => p.id == post.id));
    } catch (_) {}
  }

  Future<void> _deleteChannel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Удалить канал?', style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
          'Это действие необратимо. Все посты, подписчики и медиафайлы будут удалены навсегда.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.delete('/channels/${_channel.id}');
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ошибка удаления канала')));
    }
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _ws?.sink.close();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _showOwnerMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: Icon(Icons.edit, color: AppTheme.orange),
          title: const Text('Настройки канала', style: TextStyle(color: AppTheme.textPrimary)),
          onTap: () async {
            Navigator.pop(context);
            final updated = await Navigator.push<ChannelModel>(context, MaterialPageRoute(builder: (_) => EditChannelScreen(channel: _channel)));
            if (updated != null && mounted) setState(() => _channel = updated);
          },
        ),
        ListTile(
          leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
          title: const Text('Удалить канал', style: TextStyle(color: Colors.redAccent)),
          onTap: () { Navigator.pop(context); _deleteChannel(); },
        ),
      ])),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        backgroundColor: AppTheme.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(16))),
        title: Row(children: [
          CircleAvatar(
            radius: 18, backgroundColor: AppTheme.surfaceVariant,
            backgroundImage: _channel.avatarUrl != null
                ? CachedNetworkImageProvider(_channel.avatarUrl!, cacheKey: 'ch_avatar_${_channel.id}')
                : null,
            child: _channel.avatarUrl == null
                ? Text(_channel.name[0].toUpperCase(), style: TextStyle(color: accent, fontSize: 14, fontWeight: FontWeight.w600))
                : null,
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(_channel.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Text('${_channel.subscriberCount} подписчиков', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          ]),
        ]),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context), padding: const EdgeInsets.only(left: 8)),
        actions: [
          if (_isOwner) IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showOwnerMenu,
          ),
        ],
      ),
      body: Column(children: [
        Expanded(child: _loading
          ? Center(child: CircularProgressIndicator(color: accent))
          : ListView.builder(
              controller: _scrollCtrl,
              reverse: true,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _posts.length + (_uploading ? 1 : 0) + (_loadingMore ? 1 : 0),
              itemBuilder: (_, i) {
                if (_uploading && i == 0) {
                  return _UploadingPostBubble(previewBytes: _uploadPreview, progress: _uploadProgress);
                }
                final offset = _uploading ? 1 : 0;
                if (_loadingMore && i == _posts.length + offset) {
                  return Padding(padding: const EdgeInsets.all(12), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: accent, strokeWidth: 2))));
                }
                final idx = _posts.length - 1 - (i - offset);
                if (idx < 0 || idx >= _posts.length) return const SizedBox.shrink();
                final post = _posts[idx];
                return _SwipeablePost(
                  key: _postKeys[post.id],
                  post: post,
                  channel: widget.channel,
                  isOwner: _isOwner,
                  isHighlighted: _highlightedId == post.id,
                  onDelete: () => _deletePost(post),
                  onReply: _isOwner ? () => setState(() => _replyTo = post) : null,
                  onTapReply: post.replyToId != null ? () => _scrollToPost(post.replyToId!) : null,
                );
              },
            ),
        ),
        if (_isOwner) ...[
          if (_replyTo != null) _PostReplyPreview(
            post: _replyTo!,
            onCancel: () => setState(() => _replyTo = null),
          ),
          _PostInputBar(
            controller: _textCtrl,
            onSend: _sendText,
            onAttach: () => _showMediaPicker(),
            uploading: _uploading,
            progress: _uploadProgress,
            hasReply: _replyTo != null,
          ),
        ],
      ]),
    );
  }

  void _showMediaPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: Icon(Icons.photo, color: AppTheme.orange), title: const Text('Фото', style: TextStyle(color: AppTheme.textPrimary)),
          onTap: () { Navigator.pop(context); _pickMedia(); }),
        ListTile(leading: Icon(Icons.videocam, color: AppTheme.orange), title: const Text('Видео', style: TextStyle(color: AppTheme.textPrimary)),
          onTap: () { Navigator.pop(context); _pickMedia(video: true); }),
      ])),
    );
  }
}

// ── Post card ──────────────────────────────────────────────────────────────

class _PostCard extends StatelessWidget {
  final ChannelPostModel post;
  final ChannelModel channel;
  final bool isOwner;
  final bool isHighlighted;
  final VoidCallback onDelete;
  final VoidCallback? onTapReply;
  const _PostCard({super.key, required this.post, required this.channel, required this.isOwner, this.isHighlighted = false, required this.onDelete, this.onTapReply});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final time = DateFormat('d MMM, HH:mm', 'ru').format(post.createdAt.toLocal());
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isHighlighted ? AppTheme.orange.withValues(alpha: 0.18) : AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(children: [
              CircleAvatar(
                radius: 16, backgroundColor: AppTheme.surfaceVariant,
                backgroundImage: channel.avatarUrl != null
                    ? CachedNetworkImageProvider(channel.avatarUrl!, cacheKey: 'ch_avatar_${channel.id}')
                    : null,
                child: channel.avatarUrl == null
                    ? Text(channel.name[0].toUpperCase(), style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w600))
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(channel.name, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14))),
              Text(time, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
            ]),
          ),
          // Reply preview
          if (post.replyToId != null)
            GestureDetector(
              onTap: onTapReply,
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                  border: Border(left: BorderSide(color: AppTheme.orange, width: 3)),
                ),
                child: Text(
                  _replyPreviewText(post),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
              ),
            ),
          // Media
          if (post.mediaType != null && !post.mediaDeleted && post.mediaUrl != null)
            _PostMedia(post: post),
          // Text
          if (post.text != null && post.text!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: _LinkText(text: post.text!, textColor: AppTheme.textPrimary),
            )
          else
            const SizedBox(height: 12),
        ]),
      ),
    );
  }

  String _replyPreviewText(ChannelPostModel p) {
    if (p.replyMediaDeleted) return '🗑 Медиа удалено';
    if (p.replyMediaType == 'image') return '📷 Фото';
    if (p.replyMediaType == 'video') return '🎥 Видео';
    return p.replyText ?? '';
  }
}

class _PostMedia extends StatelessWidget {
  final ChannelPostModel post;
  const _PostMedia({required this.post});

  @override
  Widget build(BuildContext context) {
    if (post.mediaType == 'image') {
      return GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PhotoViewScreen(url: post.mediaUrl!, cacheKey: 'post_img_${post.id}'))),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(0)),
          child: CachedNetworkImage(imageUrl: post.mediaUrl!, cacheKey: 'post_img_${post.id}', width: double.infinity, height: 240, fit: BoxFit.cover,
            placeholder: (_, __) => Container(height: 240, color: AppTheme.surfaceVariant, child: Center(child: CircularProgressIndicator(color: AppTheme.orange, strokeWidth: 2))),
          ),
        ),
      );
    }
    if (post.mediaType == 'video') {
      return GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VideoPlayerScreen(url: post.mediaUrl!))),
        child: Container(height: 200, color: Colors.black,
          child: Stack(alignment: Alignment.center, children: [
            Container(width: 56, height: 56, decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36)),
          ]),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _UploadingPostBubble extends StatelessWidget {
  final Uint8List? previewBytes;
  final double progress;
  const _UploadingPostBubble({this.previewBytes, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: previewBytes != null ? 240 : 80,
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16)),
      child: Stack(alignment: Alignment.center, children: [
        if (previewBytes != null) ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.memory(previewBytes!, width: double.infinity, height: 240, fit: BoxFit.cover)),
        Container(decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(16)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            SizedBox(width: 52, height: 52, child: CircularProgressIndicator(value: progress > 0 ? progress : null, color: Colors.white, strokeWidth: 3)),
            if (progress > 0) ...[const SizedBox(height: 8), Text('${(progress * 100).toInt()}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))],
          ]),
        ),
      ]),
    );
  }
}

class _PostInputBar extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final bool uploading;
  final double progress;
  final bool hasReply;
  const _PostInputBar({required this.controller, required this.onSend, required this.onAttach, required this.uploading, required this.progress, this.hasReply = false});

  @override
  State<_PostInputBar> createState() => _PostInputBarState();
}

class _PostInputBarState extends State<_PostInputBar> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() {
      final has = widget.controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: widget.hasReply ? BorderRadius.zero : const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: SafeArea(top: false, child: Row(children: [
        IconButton(icon: const Icon(Icons.attach_file, color: AppTheme.textSecondary), onPressed: widget.onAttach, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36)),
        Expanded(child: TextField(
          controller: widget.controller,
          style: const TextStyle(color: AppTheme.textPrimary),
          maxLines: 4, minLines: 1,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Написать пост...',
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide.none,
            ),
          ),
        )),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _hasText ? widget.onSend : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44, height: 44,
            decoration: BoxDecoration(color: _hasText ? accent : AppTheme.surfaceVariant, shape: BoxShape.circle),
            child: Icon(Icons.send_rounded, color: _hasText ? AppTheme.bg : AppTheme.textSecondary, size: 20),
          ),
        ),
      ])),
    );
  }
}

// ── Reply preview bar ──────────────────────────────────────────────────────

class _PostReplyPreview extends StatelessWidget {
  final ChannelPostModel post;
  final VoidCallback onCancel;
  const _PostReplyPreview({required this.post, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final text = post.mediaDeleted
        ? '🗑 Медиа удалено'
        : post.mediaType == 'image'
            ? '📷 Фото'
            : post.mediaType == 'video'
                ? '🎥 Видео'
                : post.text ?? '';
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(children: [
        Container(width: 3, height: 36, color: AppTheme.orange, margin: const EdgeInsets.only(right: 10)),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('Ответ на пост', style: TextStyle(color: AppTheme.orange, fontSize: 12, fontWeight: FontWeight.w600)),
          Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        ])),
        IconButton(icon: const Icon(Icons.close, color: AppTheme.textSecondary, size: 20), onPressed: onCancel),
      ]),
    );
  }
}

// ── Swipeable post ─────────────────────────────────────────────────────────

class _SwipeablePost extends StatefulWidget {
  final ChannelPostModel post;
  final ChannelModel channel;
  final bool isOwner;
  final bool isHighlighted;
  final VoidCallback onDelete;
  final VoidCallback? onReply;
  final VoidCallback? onTapReply;
  const _SwipeablePost({super.key, required this.post, required this.channel, required this.isOwner, this.isHighlighted = false, required this.onDelete, this.onReply, this.onTapReply});

  @override
  State<_SwipeablePost> createState() => _SwipeablePostState();
}

class _SwipeablePostState extends State<_SwipeablePost> with SingleTickerProviderStateMixin {
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
  void dispose() { _snapCtrl.dispose(); super.dispose(); }

  void _onDragUpdate(DragUpdateDetails d) {
    if (widget.onReply == null) return;
    if (d.delta.dx < 0 && _dragX == 0) return;
    final newX = (_dragX + d.delta.dx).clamp(0.0, 70.0);
    setState(() => _dragX = newX);
    if (_dragX >= 65 && !_triggered) {
      _triggered = true;
      HapticFeedback.lightImpact();
      widget.onReply!();
    }
  }

  void _onDragEnd(DragEndDetails _) {
    _triggered = false;
    _snapAnim = Tween<double>(begin: _dragX, end: 0).animate(CurvedAnimation(parent: _snapCtrl, curve: Curves.easeOut));
    _snapCtrl.forward(from: 0);
  }

  void _showMenu(BuildContext context) {
    final post = widget.post;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (post.text != null && post.text!.isNotEmpty) ListTile(
          leading: Icon(Icons.copy, color: AppTheme.orange),
          title: const Text('Копировать', style: TextStyle(color: AppTheme.textPrimary)),
          onTap: () { Navigator.pop(context); Clipboard.setData(ClipboardData(text: post.text!)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Скопировано'))); },
        ),
        if (post.mediaUrl != null && !post.mediaDeleted) ListTile(
          leading: Icon(Icons.download, color: AppTheme.orange),
          title: const Text('Сохранить медиа', style: TextStyle(color: AppTheme.textPrimary)),
          onTap: () { Navigator.pop(context); showDownloadSheet(context, url: post.mediaUrl!, filename: '${post.mediaType}_${post.id}.${post.mediaType == 'video' ? 'mp4' : 'jpg'}'); },
        ),
        if (widget.isOwner) ListTile(
          leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
          title: const Text('Удалить пост', style: TextStyle(color: Colors.redAccent)),
          onTap: () { Navigator.pop(context); widget.onDelete(); },
        ),
      ])),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      onLongPress: () => _showMenu(context),
      behavior: HitTestBehavior.opaque,
      child: Transform.translate(
        offset: Offset(_dragX, 0),
        child: Stack(children: [
          if (widget.onReply != null)
            Positioned(
              left: 0, top: 0, bottom: 0,
              child: AnimatedOpacity(
                opacity: (_dragX / 50).clamp(0.0, 1.0),
                duration: const Duration(milliseconds: 50),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.reply_rounded, color: AppTheme.orange, size: 20),
                ),
              ),
            ),
          _PostCard(
            post: widget.post,
            channel: widget.channel,
            isOwner: widget.isOwner,
            isHighlighted: widget.isHighlighted,
            onDelete: widget.onDelete,
            onTapReply: widget.onTapReply,
          ),
        ]),
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
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
      final url = m.group(0)!;
      spans.add(WidgetSpan(
        child: GestureDetector(
          onTap: () => _showLinkDialog(context, url),
          child: Text(url, style: TextStyle(color: AppTheme.orange, fontSize: 15, decoration: TextDecoration.underline, decorationColor: AppTheme.orange)),
        ),
      ));
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return RichText(text: TextSpan(style: TextStyle(color: textColor, fontSize: 15), children: spans));
  }
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
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEmail ? 'Email скопирован' : 'Ссылка скопирована')));
          },
          child: const Text('Копировать'),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(ctx);
            final uri = Uri.parse(fullUrl);
            if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
          },
          child: Text(isEmail ? 'Написать' : 'Открыть', style: TextStyle(color: AppTheme.orange)),
        ),
      ],
    ),
  );
}
