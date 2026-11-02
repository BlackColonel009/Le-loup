import 'package:flutter/material.dart';
import 'package:local_host/local_host.dart';
import '../stickers/chat_stickers.dart';
import '../services/immersion_preferences.dart';
import '../content/pack_store.dart';

class HouseReaction extends StatefulWidget {
  const HouseReaction({super.key, required this.reaction});
  final Map reaction;
  @override
  State<HouseReaction> createState() => _HouseReactionState();
}

class _HouseReactionState extends State<HouseReaction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock;
  @override
  void initState() {
    super.initState();
    _clock = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: (widget.reaction['remaining_ms'] as int? ?? 0).clamp(
          0,
          4000,
        ),
      ),
    )..forward();
    final sticker = chatStickerById(
      widget.reaction['sticker'] as String? ?? '',
    );
    if (sticker != null) {
      PackStore.instance
          .initialize()
          .then((_) => PackStore.instance.ensureAsset(sticker.asset))
          .catchError((Object _) {});
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sticker = chatStickerById(
      widget.reaction['sticker'] as String? ?? '',
    );
    if (sticker == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _clock,
        builder: (context, child) {
          if (_clock.isCompleted) return const SizedBox.shrink();
          return Opacity(
            opacity: ((1 - _clock.value) * 5).clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(
                0,
                ImmersionPreferences.instance.reduced(context)
                    ? 0
                    : -_clock.value * 22,
              ),
              child: child,
            ),
          );
        },
        child: ListenableBuilder(
          listenable: PackStore.instance,
          builder: (context, _) =>
              PackStore.instance.pathFor(sticker.asset) == null
              ? Tooltip(
                  message: sticker.label,
                  child: const Icon(
                    Icons.emoji_emotions,
                    size: 52,
                    color: Color(0xFFE5C58C),
                  ),
                )
              : ChatStickerImage(sticker: sticker, size: 96),
        ),
      ),
    );
  }
}
