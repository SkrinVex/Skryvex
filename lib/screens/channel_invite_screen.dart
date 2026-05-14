import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'channel_screen.dart';

class ChannelInviteScreen extends StatefulWidget {
  final String inviteCode;
  const ChannelInviteScreen({super.key, required this.inviteCode});

  @override
  State<ChannelInviteScreen> createState() => _ChannelInviteScreenState();
}

class _ChannelInviteScreenState extends State<ChannelInviteScreen> {
  ChannelModel? _channel;
  bool _loading = true;
  bool _subscribing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.get('/channels/invite/${widget.inviteCode}') as Map<String, dynamic>;
      final channel = ChannelModel.fromJson(data);
      if (channel.subscribed || channel.isOwner) {
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => ChannelScreen(channel: channel)),
            (route) => route.isFirst,
          );
        }
        return;
      }
      setState(() { _channel = channel; _loading = false; });
    } catch (_) {
      setState(() { _error = 'Ссылка недействительна'; _loading = false; });
    }
  }

  Future<void> _subscribe() async {
    if (_channel == null || _subscribing) return;
    setState(() => _subscribing = true);
    try {
      await ApiService.post('/channels/${_channel!.id}/subscribe', {});
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => ChannelScreen(channel: _channel!.copyWith(subscribed: true))),
          (route) => route.isFirst,
        );
      }
    } catch (_) {
      setState(() => _subscribing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(title: const Text('Приглашение')),
      body: Center(
        child: _loading
            ? CircularProgressIndicator(color: accent)
            : _error != null
                ? Text(_error!, style: const TextStyle(color: AppTheme.textSecondary))
                : Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      CircleAvatar(
                        radius: 48, backgroundColor: AppTheme.surfaceVariant,
                        backgroundImage: _channel!.avatarUrl != null
                            ? CachedNetworkImageProvider(_channel!.avatarUrl!, cacheKey: 'ch_inv_${_channel!.id}')
                            : null,
                        child: _channel!.avatarUrl == null
                            ? Text(_channel!.name[0].toUpperCase(), style: TextStyle(color: accent, fontSize: 32, fontWeight: FontWeight.w600))
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Text(_channel!.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('@${_channel!.username}', style: const TextStyle(color: AppTheme.textSecondary)),
                      const SizedBox(height: 4),
                      Text('${_channel!.subscriberCount} подписчиков', style: const TextStyle(color: AppTheme.textSecondary)),
                      if (_channel!.description != null && _channel!.description!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(_channel!.description!, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                      ],
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _subscribing ? null : _subscribe,
                          child: _subscribing
                              ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppTheme.bg, strokeWidth: 2))
                              : const Text('Подписаться'),
                        ),
                      ),
                    ]),
                  ),
      ),
    );
  }
}
