import 'package:local_host/local_host.dart' show ChatSticker, chatStickers;

String normalizeStickerWords(String input) {
  var text = input.toLowerCase().replaceAll('œ', 'oe');
  for (final entry in const {
    'àâä': 'a',
    'éèêë': 'e',
    'îï': 'i',
    'ôö': 'o',
    'ùûü': 'u',
    'ç': 'c',
  }.entries) {
    for (final letter in entry.key.split('')) {
      text = text.replaceAll(letter, entry.value);
    }
  }
  return text.replaceAll(RegExp('[^a-z0-9]+'), ' ').trim();
}

/// Local matching only: no network request or disclosure of the typed draft.
List<ChatSticker> suggestStickers(
  String draft, {
  Iterable<ChatSticker>? stickers,
  int limit = 6,
}) {
  if (draft.trim().isEmpty || draft.trim().startsWith('[[sticker:')) return [];
  final words = normalizeStickerWords(
    draft,
  ).split(' ').where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return [];
  final tail = words.skip((words.length - 5).clamp(0, words.length)).toList();
  final sentence = ' ${tail.join(' ')} ';
  final unfinished = !RegExp(r'\s$').hasMatch(draft);
  final ranked = <({ChatSticker sticker, int score, int order})>[];
  var order = 0;
  for (final sticker in stickers ?? chatStickers) {
    var score = 0;
    for (final raw in sticker.keywords) {
      final term = normalizeStickerWords(raw);
      if (term.isEmpty) continue;
      if (sentence.endsWith(' $term ')) {
        score = score < 120 + term.length ? 120 + term.length : score;
      } else if (sentence.contains(' $term ')) {
        score = score < 60 + term.length ? 60 + term.length : score;
      } else if (unfinished &&
          tail.last.length >= 3 &&
          term.startsWith(tail.last)) {
        score = score < 30 ? 30 : score;
      }
    }
    if (score > 0) ranked.add((sticker: sticker, score: score, order: order));
    order++;
  }
  ranked.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : a.order.compareTo(b.order);
  });
  return ranked.take(limit).map((r) => r.sticker).toList();
}
