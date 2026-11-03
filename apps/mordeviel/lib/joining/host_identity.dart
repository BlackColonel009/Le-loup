/// Only use with a private MDJ snapshot. Never changes the actual game aliases.
Map<String, dynamic> hostDisplayRoom(Map<String, dynamic> room) {
  final names = room['account_names'] as Map?;
  if (names == null || names.isEmpty) return room;
  return {
    ...room,
    'players': [
      for (final raw in room['players'] as List? ?? [])
        if (raw is Map)
          {
            ...raw,
            'game_nickname': raw['game_nickname'] ?? raw['nickname'],
            'nickname':
                names[raw['id']] is String &&
                    names[raw['id']] !=
                        (raw['game_nickname'] ?? raw['nickname'])
                ? '${raw['game_nickname'] ?? raw['nickname']} (${names[raw['id']]})'
                : raw['game_nickname'] ?? raw['nickname'],
          },
    ],
  };
}
