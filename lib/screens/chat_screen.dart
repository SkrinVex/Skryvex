import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class ChatScreen extends StatefulWidget {
  final int chatId;
  final String partnerName;

  const ChatScreen({super.key, required this.chatId, required this.partnerName});

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
  MessageModel? _replyTo;
  int? _highlightedId;
  double _lastBottomInset = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    if (bottomInset > _lastBottomInset) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
    _lastBottomInset = bottomInset;
  }

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('ru', null).then((_) => _init());
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userJson = prefs.getString('user');
    if (userJson != null) {
      _myId = (jsonDecode(userJson) as Map<String, dynamic>)['id'] as int?;
    }
    await _loadMessages();
    if (token != null) {
      _ws = WebSocketChannel.connect(Uri.parse('${ApiService.wsBase}?token=$token'));
      _ws!.sink.add(jsonEncode({'type': 'join', 'chatId': widget.chatId}));
      _ws!.stream.listen(_onWsMessage, onError: (_) {}, onDone: () {});
    }
  }

  Future<void> _loadMessages() async {
    try {
      final data = await ApiService.get('/chats/${widget.chatId}/messages') as List<dynamic>;
      final msgs = data.map((e) => MessageModel.fromJson(e as Map<String, dynamic>)).toList();
      setState(() {
        _messages.clear();
        _messages.addAll(msgs);
        for (final m in msgs) {
          _msgKeys[m.id] = GlobalKey();
        }
        _loading = false;
      });
      _scrollToBottom();
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _onWsMessage(dynamic raw) {
    final msg = jsonDecode(raw as String) as Map<String, dynamic>;
    if (msg['type'] == 'message') {
      final m = MessageModel.fromJson(msg);
      if (m.chatId == widget.chatId) {
        setState(() {
          _messages.add(m);
          _msgKeys[m.id] = GlobalKey();
        });
        _scrollToBottom();
        // Помечаем как прочитанное — мы в чате и видим сообщение
        ApiService.get('/chats/${widget.chatId}/messages?limit=1').catchError((_) => null);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _scrollToMessage(int messageId) async {
    final key = _msgKeys[messageId];
    if (key?.currentContext == null) return;
    await Scrollable.ensureVisible(
      key!.currentContext!,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      alignment: 0.3,
    );
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

  @override
  void dispose() {
    _ws?.sink.close();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.partnerName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.orange))
                : _messages.isEmpty
                    ? Center(
                        child: Text('Начните переписку',
                            style: TextStyle(color: AppTheme.textSecondary)))
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) {
                          final msg = _messages[i];
                          final showDate = i == 0 ||
                              !_sameDay(_messages[i - 1].createdAt, msg.createdAt);
                          return _SwipeableMessage(
                            key: _msgKeys[msg.id],
                            message: msg,
                            isMe: msg.senderId == _myId,
                            showDate: showDate,
                            isHighlighted: _highlightedId == msg.id,
                            onReply: () => setState(() => _replyTo = msg),
                            onTapReply: msg.replyToId != null
                                ? () => _scrollToMessage(msg.replyToId!)
                                : null,
                          );
                        },
                      ),
          ),
          if (_replyTo != null) _ReplyPreview(
            message: _replyTo!,
            isMe: _replyTo!.senderId == _myId,
            onCancel: () => setState(() => _replyTo = null),
            onTap: () => _scrollToMessage(_replyTo!.id),
          ),
          _InputBar(controller: _msgCtrl, onSend: _send),
        ],
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
  final VoidCallback? onTapReply;

  const _SwipeableMessage({
    super.key,
    required this.message,
    required this.isMe,
    required this.showDate,
    required this.isHighlighted,
    required this.onReply,
    this.onTapReply,
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
                                    widget.message.replyText ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: widget.isMe
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
                              Text(
                                widget.message.text,
                                style: TextStyle(
                                  color: widget.isMe ? AppTheme.bg : AppTheme.textPrimary,
                                  fontSize: 15,
                                ),
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
        color: AppTheme.surface,
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
                    isMe ? 'Вы' : message.senderName,
                    style: const TextStyle(
                        color: AppTheme.orange, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    message.text,
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

  const _InputBar({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                style: const TextStyle(color: AppTheme.textPrimary),
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Сообщение...'),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onSend,
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                    color: AppTheme.orange, shape: BoxShape.circle),
                child: const Icon(Icons.send_rounded, color: AppTheme.bg, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
