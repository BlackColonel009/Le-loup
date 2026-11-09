import 'package:flutter/material.dart';
import 'package:local_host/local_host.dart' show normalizeBotText;

/// Suggestions are restricted to participants already visible in this channel.
class PlayerMentionSuggestions extends StatelessWidget {
  const PlayerMentionSuggestions({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.players,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<Map> players;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final caret = controller.selection.baseOffset;
      if (caret < 0 || caret > controller.text.length)
        return const SizedBox.shrink();
      final match = RegExp(
        r'(^|\s)@([^@\n]*)$',
      ).firstMatch(controller.text.substring(0, caret));
      if (match == null) return const SizedBox.shrink();
      final query = normalizeBotText(match.group(2)!);
      final matches = players
          .where((p) => normalizeBotText('${p['nickname']}').contains(query))
          .toList();
      if (matches.isEmpty) return const SizedBox.shrink();
      return Material(
        color: const Color(0xFF243640),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 150),
          child: ListView.builder(
            shrinkWrap: true,
            primary: false,
            key: const ValueKey('player-mention-list'),
            itemCount: matches.length,
            itemBuilder: (context, index) {
              final player = matches[index];
              return ListTile(
                dense: true,
                leading: Icon(
                  player['is_bot'] == true
                      ? Icons.smart_toy_outlined
                      : Icons.person_outline,
                ),
                title: Text(
                  '@${player['nickname']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  final start = match.start + match.group(1)!.length;
                  final insertion = '@${player['nickname']} ';
                  final text = controller.text.replaceRange(
                    start,
                    caret,
                    insertion,
                  );
                  if (text.length > 300) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Le message dépasse 300 caractères.'),
                      ),
                    );
                    return;
                  }
                  controller.value = TextEditingValue(
                    text: text,
                    selection: TextSelection.collapsed(
                      offset: start + insertion.length,
                    ),
                  );
                  focusNode.requestFocus();
                },
              );
            },
          ),
        ),
      );
    },
  );
}
