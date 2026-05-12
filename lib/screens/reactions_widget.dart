import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../models/models.dart';
import '../theme.dart';

const _quickEmojis = ['👍', '❤️', '😂', '😮', '😢', '🔥'];

/// Показывает панель реакций + меню действий.
/// Возвращает выбранный emoji или null.
Future<String?> showReactionPickerWithMenu(
  BuildContext context, {
  required List<Widget> menuItems,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppTheme.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) => _ReactionSheet(menuItems: menuItems),
  );
}

class _ReactionSheet extends StatefulWidget {
  final List<Widget> menuItems;
  const _ReactionSheet({required this.menuItems});
  @override
  State<_ReactionSheet> createState() => _ReactionSheetState();
}

class _ReactionSheetState extends State<_ReactionSheet> {
  bool _showPicker = false;

  @override
  Widget build(BuildContext context) {
    if (_showPicker) {
      return SizedBox(
        height: MediaQuery.of(context).size.height * 0.5,
        child: EmojiPicker(
          onEmojiSelected: (_, emoji) => Navigator.pop(context, emoji.emoji),
          config: Config(
            emojiViewConfig: EmojiViewConfig(
              backgroundColor: AppTheme.surface,
              noRecents: const SizedBox.shrink(),
            ),
            bottomActionBarConfig: const BottomActionBarConfig(enabled: false),
            categoryViewConfig: CategoryViewConfig(
              backgroundColor: AppTheme.surface,
              iconColor: AppTheme.textSecondary,
              iconColorSelected: AppTheme.orange,
              indicatorColor: AppTheme.orange,
            ),
            skinToneConfig: SkinToneConfig(
              dialogBackgroundColor: AppTheme.surfaceVariant,
              indicatorColor: AppTheme.textPrimary,
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ..._quickEmojis.map((e) => _EmojiBtn(emoji: e)),
                GestureDetector(
                  onTap: () => setState(() => _showPicker = true),
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: AppTheme.surfaceVariant, borderRadius: BorderRadius.circular(22)),
                    child: const Icon(Icons.add, color: AppTheme.textSecondary, size: 20),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.divider),
          ...widget.menuItems,
        ],
      ),
    );
  }
}

class _EmojiBtn extends StatelessWidget {
  final String emoji;
  const _EmojiBtn({required this.emoji});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => Navigator.pop(context, emoji),
    child: Container(
      width: 44, height: 44,
      decoration: BoxDecoration(color: AppTheme.surfaceVariant, borderRadius: BorderRadius.circular(22)),
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
    ),
  );
}

/// Строка реакций под сообщением в чате (с аватарами).
class ChatReactionsRow extends StatelessWidget {
  final List<ReactionModel> reactions;
  final void Function(String emoji) onTap;

  const ChatReactionsRow({super.key, required this.reactions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: reactions.map((r) => GestureDetector(
          onTap: () => onTap(r.emoji),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: r.reacted ? accent.withValues(alpha: 0.2) : AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: r.reacted ? Border.all(color: accent, width: 1) : null,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(r.emoji, style: const TextStyle(fontSize: 14)),
              if (r.count > 1) ...[
                const SizedBox(width: 4),
                Text('${r.count}', style: TextStyle(
                  color: r.reacted ? accent : AppTheme.textSecondary,
                  fontSize: 12, fontWeight: FontWeight.w600,
                )),
              ],
              if (r.users.isNotEmpty) ...[
                const SizedBox(width: 4),
                ...r.users.take(3).map((u) => _MiniAvatar(user: u)),
              ],
            ]),
          ),
        )).toList(),
      ),
    );
  }
}

/// Строка реакций под постом в канале (с обводкой для своих).
class PostReactionsRow extends StatelessWidget {
  final List<ReactionModel> reactions;
  final void Function(String emoji) onTap;

  const PostReactionsRow({super.key, required this.reactions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: reactions.map((r) => GestureDetector(
          onTap: () => onTap(r.emoji),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: r.reacted ? accent.withValues(alpha: 0.2) : AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: r.reacted ? Border.all(color: accent, width: 1) : null,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(r.emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
              Text('${r.count}', style: TextStyle(
                color: r.reacted ? accent : AppTheme.textSecondary,
                fontSize: 12, fontWeight: FontWeight.w600,
              )),
            ]),
          ),
        )).toList(),
      ),
    );
  }
}

class _MiniAvatar extends StatelessWidget {
  final Map<String, dynamic> user;
  const _MiniAvatar({required this.user});
  @override
  Widget build(BuildContext context) {
    final url = user['avatar_url'] as String?;
    final name = (user['name'] as String? ?? '?');
    return Container(
      width: 16, height: 16,
      margin: const EdgeInsets.only(left: 1),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.surfaceVariant,
        image: url != null ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover) : null,
      ),
      child: url == null
          ? Center(child: Text(name[0].toUpperCase(), style: const TextStyle(fontSize: 8, color: AppTheme.textSecondary)))
          : null,
    );
  }
}
