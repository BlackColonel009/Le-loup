import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_host/local_host.dart';

void main() {
  final players = <Map>[
    {'id': 'h', 'nickname': 'Alice', 'is_bot': false},
    {'id': 'a', 'nickname': 'Bot Léa 1', 'is_bot': true},
    {'id': 'b', 'nickname': 'Bot Hugo 2', 'is_bot': true},
  ];
  Map<String, dynamic> game(List<Map> messages, {String phase = 'voting'}) => {
    'phase': phase,
    'phase_revision': 7,
    'night': 1,
    'chat_open': true,
    'alive_ids': ['h', 'a', 'b'],
    'players': players,
    'day_messages': messages,
  };
  final own = {'phase_revision': 7, 'alive': true};
  final now = DateTime(2026, 11, 5);
  BotConversation bot() =>
      BotConversation(BotPersona.forIndex(1), random: Random(4));
  test(
    'mentions accept spaces and punctuation, never a partial nickname or email',
    () {
      expect(mentionedPlayers('@Bot Léa 1, pourquoi ? @Alice !', players), {
        'a',
        'h',
      });
      expect(
        mentionedPlayers('@Bot Léa 10 moi ? email@Alice', players),
        isEmpty,
      );
    },
  );
  test(
    'intent recognition handles accents, counter-accusations and whole words',
    () {
      expect(botIntent('Moi ?'), 'me');
      expect(botIntent('Pourquoi ?'), 'why');
      expect(botIntent("C’est toi-même le loup !"), 'counter');
      expect(botIntent("Ce n'est pas moi"), 'deny');
      expect(botIntent('Je suis innocent'), 'deny');
      expect(botIntent('Il y en a moins'), 'fallback');
    },
  );
  test('gender agreements and non-repeating lines', () {
    final female = bot(),
        male = BotConversation(
          const BotPersona('Bot Hugo 2', 'male'),
          random: Random(4),
        );
    expect(female.line('thanks'), isNotEmpty);
    final lines = [for (var i = 0; i < 6; i++) female.line('fallback')];
    expect(lines.any((s) => s.contains('curieuse')), isTrue);
    expect(
      [
        for (var i = 0; i < 6; i++) male.line('fallback'),
      ].any((s) => s.contains('curieux')),
      isTrue,
    );
    for (var i = 1; i < lines.length; i++)
      expect(lines[i], isNot(lines[i - 1]));
  });
  test('the four temperaments are distributed across bot personas', () {
    expect([
      for (var index = 1; index <= 4; index++)
        BotPersona.forIndex(index).temperament,
    ], BotTemperament.values);
    expect(BotPersona.forIndex(1).feminine, isTrue);
    expect(BotPersona.forIndex(2).feminine, isFalse);
    expect(
      BotConversation(
        BotPersona.forIndex(2),
        random: Random(2),
      ).line('counter'),
      matches(RegExp(r'conseil|scène')),
    );
  });
  test(
    'human mention replies quote the correct message and are processed once',
    () {
      final brain = bot();
      final state = game([
        {'id': '1', 'author': 'h', 'text': '@Bot Léa 1 moi ?'},
      ]);
      final response = brain.next('a', state, own, now)!;
      expect(response['reply_to'], '1');
      expect(response['text'], startsWith('@Alice '));
      expect(
        brain.next('a', state, own, now.add(const Duration(seconds: 4))),
        isNull,
      );
    },
  );
  test(
    'reply arrow works without an explicit mention; closed and dead bots stay silent',
    () {
      final state = game([
        {'id': '1', 'author': 'h', 'text': 'Pourquoi ?', 'reply_author': 'a'},
      ]);
      expect(bot().next('a', state, own, now), isNotNull);
      expect(bot().next('a', {...state, 'chat_open': false}, own, now), isNull);
      expect(bot().next('a', {...state, 'paused': true}, own, now), isNull);
      expect(bot().next('a', state, {...own, 'alive': false}, now), isNull);
      expect(
        bot().next('a', game(state['day_messages'], phase: 'wolves'), own, now),
        isNull,
      );
      expect(
        bot().next('a', state, {...own, 'phase_revision': 6}, now),
        isNull,
      );
    },
  );
  test(
    'a vote tags humans, never falsely alleges silence after a public message',
    () {
      final response = bot().next(
        'a',
        game([
          {'id': '1', 'author': 'h', 'text': 'Bonjour'},
        ]),
        own,
        now,
        voteTarget: 'h',
      )!;
      expect(response['text'], startsWith('@Alice '));
      expect(response['text'], isNot(contains('silence')));
      expect(bot().next('a', game([]), own, now, voteTarget: 'b'), isNull);
      expect(
        bot().next(
          'a',
          game([], phase: 'mayor_election'),
          own,
          now,
          voteTarget: 'h',
        ),
        isNull,
      );
    },
  );
  test(
    'a tagged bot message gets one sticker response, without sticker loops',
    () {
      final state = {
        ...game([
          {'id': 'message-1', 'author': 'b', 'text': '@Alice je te suspecte'},
        ]),
        'alive_ids': ['h', 'a', 'b', 'c'],
        'players': [
          ...players,
          {'id': 'c', 'nickname': 'Bot Nora 3', 'is_bot': true},
        ],
      };
      final fromA = bot().next('a', state, own, now);
      final fromC = BotConversation(
        BotPersona.forIndex(3),
        random: Random(3),
      ).next('c', state, own, now);
      expect((fromA == null) != (fromC == null), isTrue);
      final reaction = fromA ?? fromC!;
      expect(stickerFromMessage(reaction['text'] as String), isNotNull);
      expect(reaction['reply_to'], 'message-1');

      final stickerOnly = game([
        {
          'id': 'message-2',
          'author': 'b',
          'text': reaction['text'],
          'reply_author': 'a',
        },
      ]);
      expect(bot().next('a', stickerOnly, own, now), isNull);
    },
  );
  test('human replies stay selective, avoid loops and respect cooldowns', () {
    final brain = bot();
    final state = game([
      {'id': 'message-2', 'author': 'h', 'text': '@Bot Léa 1 pourquoi ?'},
    ]);
    expect(brain.next('a', state, own, now), isNotNull);
    expect(
      brain.next('a', state, own, now.add(const Duration(seconds: 1))),
      isNull,
    );
    expect(
      brain.next('a', state, own, now.add(const Duration(seconds: 4))),
      isNull,
    );
    expect(
      bot().next(
        'a',
        game([
          {'id': 'message-3', 'author': 'h', 'text': 'Bonjour tout le monde'},
        ]),
        own,
        now,
      ),
      isNull,
    );
    expect(
      brain.next(
        'a',
        game([
          {
            'id': 'message-4',
            'author': 'h',
            'text': 'Merci',
            'reply_author': 'a',
          },
        ]),
        own,
        now.add(const Duration(seconds: 8)),
      ),
      isNotNull,
    );
  });
}
