import 'dart:math';

/// Every sentence appears once per shuffled cycle; no repeat at a cycle boundary.
class SentenceDraw {
  SentenceDraw(this.random);
  final Random random;
  final _remaining = <int>[];
  int? _last;
  int _count = 0;
  void reset() {
    _remaining.clear();
    _last = null;
    _count = 0;
  }

  int next(int count) {
    if (count < 1) throw ArgumentError('Aucune sentence disponible.');
    if (_count != count) reset();
    _count = count;
    if (_remaining.isEmpty) {
      _remaining.addAll(List.generate(count, (i) => i)..shuffle(random));
      if (count > 1 && _remaining.last == _last) {
        final swap = _remaining.first;
        _remaining[0] = _remaining.last;
        _remaining[_remaining.length - 1] = swap;
      }
    }
    return _last = _remaining.removeLast();
  }
}
