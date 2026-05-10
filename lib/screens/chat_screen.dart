import 'dart:convert';
import 'package:flutter/material.dart';
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
  final List<MessageModel> _messages = [];
  WebSocketChannel? _ws;
  int? _myId;
  bool _loading = true;

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
      _ws = WebSocketChannel.connect(
        Uri.parse('${ApiService.wsBase}?token=$token'),
      );
      _ws!.sink.add(jsonEncode({'type': 'join', 'chatId': widget.chatId}));
      _ws!.stream.listen(_onWsMessage, onError: (_) {}, onDone: () {});
    }
  }

  Future<void> _loadMessages() async {
    try {
      final data = await ApiService.get('/chats/${widget.chatId}/messages') as List<dynamic>;
      setState(() {
        _messages.clear();
        _messages.addAll(data.map((e) => MessageModel.fromJson(e as Map<String, dynamic>)));
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
        setState(() => _messages.add(m));
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _ws == null) return;
    _ws!.sink.add(jsonEncode({'type': 'message', 'text': text}));
    _msgCtrl.clear();
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
                        child: Text(
                          'Начните переписку',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) => _MessageBubble(
                          message: _messages[i],
                          isMe: _messages[i].senderId == _myId,
                          showDate: i == 0 ||
                              !_sameDay(_messages[i - 1].createdAt, _messages[i].createdAt),
                        ),
                      ),
          ),
          _InputBar(controller: _msgCtrl, onSend: _send),
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final bool showDate;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.showDate,
  });

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm').format(message.createdAt.toLocal());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showDate)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                _formatDate(message.createdAt),
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ),
          ),
        Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72,
            ),
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: isMe ? AppTheme.orangeDim : AppTheme.surfaceVariant,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  message.text,
                  style: TextStyle(
                    color: isMe ? AppTheme.bg : AppTheme.textPrimary,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  time,
                  style: TextStyle(
                    color: isMe
                        ? AppTheme.bg.withValues(alpha: 0.6)
                        : AppTheme.textSecondary,
                    fontSize: 11,
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
    if (local.year == yesterday.year && local.month == yesterday.month && local.day == yesterday.day) {
      return 'Вчера';
    }
    return DateFormat('d MMMM', 'ru').format(local);
  }
}

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
                decoration: const InputDecoration(
                  hintText: 'Сообщение...',
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onSend,
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppTheme.orange,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send_rounded, color: AppTheme.bg, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
