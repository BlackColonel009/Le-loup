/// Plain-text mentions resolve against the current public roster, never roles.
Set<String> mentionedPlayers(String text, Iterable<Map> players) => {
  for (final player in players)
    if (player['id'] is String &&
        player['nickname'] is String &&
        RegExp(
          '(^|[\\s(])@${RegExp.escape(player['nickname'] as String)}(?=\$|[\\s,.!?;:)])',
          caseSensitive: false,
        ).hasMatch(text))
      player['id'] as String,
};
