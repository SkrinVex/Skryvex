import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'group_screen.dart';

class GroupInviteScreen extends StatefulWidget {
  final String inviteCode;
  const GroupInviteScreen({super.key, required this.inviteCode});

  @override
  State<GroupInviteScreen> createState() => _GroupInviteScreenState();
}

class _GroupInviteScreenState extends State<GroupInviteScreen> {
  GroupModel? _group;
  bool _loading = true;
  bool _joining = false;
  String? _error;
  // null = не определено, 'joined', 'pending', 'rejected', 'already_member'
  String? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.get('/groups/invite/${widget.inviteCode}') as Map<String, dynamic>;
      final group = GroupModel.fromJson(data);
      final alreadyMember = data['already_member'] as bool? ?? false;
      final pendingRequest = data['pending_request'] as bool? ?? false;
      final rejected = data['rejected'] as bool? ?? false;

      if (alreadyMember) {
        // Уже участник — открываем чат и убираем GroupInviteScreen из стека
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => GroupScreen(
              groupId: group.id, groupName: group.name,
              groupAvatar: group.avatarUrl, isOwner: false,
            )),
            (route) => route.isFirst, // оставляем только HomeScreen
          );
        }
        return;
      }

      setState(() {
        _group = group;
        _loading = false;
        if (pendingRequest) _status = 'pending';
        else if (rejected) _status = 'rejected';
      });
    } catch (_) {
      setState(() { _error = 'Ссылка недействительна'; _loading = false; });
    }
  }

  Future<void> _join() async {
    if (_group == null || _joining) return;
    setState(() => _joining = true);
    try {
      final data = await ApiService.post('/groups/${_group!.id}/join', {}) as Map<String, dynamic>;
      final status = data['status'] as String;
      if (status == 'joined' || status == 'already_member') {
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => GroupScreen(
              groupId: _group!.id, groupName: _group!.name,
              groupAvatar: _group!.avatarUrl, isOwner: false,
            )),
            (route) => route.isFirst,
          );
        }
      } else if (status == 'pending') {
        // Показываем сообщение и закрываем экран
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✓ Заявка отправлена. Ожидайте одобрения владельца')),
          );
          Navigator.pop(context);
        }
      }
    } catch (_) {
      setState(() { _error = 'Ошибка'; _joining = false; });
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
                : _buildContent(accent),
      ),
    );
  }

  Widget _buildContent(Color accent) {
    if (_status == 'pending') {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.hourglass_top, size: 56, color: accent),
        const SizedBox(height: 16),
        const Text('Заявка отправлена', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Text('Ожидайте одобрения владельца', style: TextStyle(color: AppTheme.textSecondary)),
        const SizedBox(height: 24),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Закрыть')),
      ]);
    }

    if (_status == 'rejected') {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.block, size: 56, color: Colors.redAccent.withValues(alpha: 0.8)),
        const SizedBox(height: 16),
        const Text('Заявка отклонена', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Text('Владелец отклонил вашу заявку', style: TextStyle(color: AppTheme.textSecondary)),
        const SizedBox(height: 24),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Закрыть')),
      ]);
    }

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircleAvatar(
          radius: 48, backgroundColor: AppTheme.surfaceVariant,
          backgroundImage: _group!.avatarUrl != null
              ? CachedNetworkImageProvider(_group!.avatarUrl!, cacheKey: 'group_${_group!.id}')
              : null,
          child: _group!.avatarUrl == null
              ? Text(_group!.name[0].toUpperCase(), style: TextStyle(color: accent, fontSize: 32, fontWeight: FontWeight.w600))
              : null,
        ),
        const SizedBox(height: 16),
        Text(_group!.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('${_group!.memberCount} участников', style: const TextStyle(color: AppTheme.textSecondary)),
        if (_group!.isPrivate) ...[
          const SizedBox(height: 8),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.lock, size: 14, color: AppTheme.textSecondary),
            const SizedBox(width: 4),
            const Text('Закрытая группа', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ]),
        ],
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _joining ? null : _join,
            child: _joining
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppTheme.bg, strokeWidth: 2))
                : Text(_group!.isPrivate ? 'Подать заявку' : 'Вступить'),
          ),
        ),
      ]),
    );
  }
}
