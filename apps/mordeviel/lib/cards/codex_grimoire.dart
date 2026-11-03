import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'codex_page_turn.dart';

class CodexChapter {
  const CodexChapter(this.title, this.text);
  final String title, text;
}

class _Leaf {
  const _Leaf(this.chapter, this.start, this.end, this.text);
  final int chapter, start, end;
  final String text;
}

const _ink = Color(0xFF352719);
const _body = TextStyle(
  inherit: false,
  fontFamily: 'VillageSans',
  fontSize: 16,
  height: 1.4,
  color: _ink,
);

// Measure real lines at the user's text size; long chapters continue on paper.
List<_Leaf> _paginate(
  List<CodexChapter> chapters,
  double width,
  double height,
  TextScaler scaler,
  TextDirection direction,
) {
  final leaves = <_Leaf>[];
  for (var chapter = 0; chapter < chapters.length; chapter++) {
    final text = chapters[chapter].text;
    var start = 0;
    while (start < text.length) {
      while (start < text.length && text[start].trim().isEmpty) {
        start++;
      }
      if (start == text.length) break;
      final remaining = text.substring(start);
      final painter = TextPainter(
        text: TextSpan(text: remaining, style: _body),
        textScaler: scaler,
        textDirection: direction,
      )..layout(maxWidth: width);
      var end = remaining.length;
      if (painter.height > height) {
        final lines = painter.computeLineMetrics();
        var used = 0.0;
        var last = lines.first;
        for (final line in lines) {
          if (used + line.height > height && used > 0) break;
          last = line;
          used += line.height;
        }
        end = painter
            .getLineBoundary(
              painter.getPositionForOffset(Offset(0, last.baseline)),
            )
            .end;
        if (end <= 0) end = math.min(remaining.length, 1);
      }
      leaves.add(
        _Leaf(
          chapter,
          start,
          start + end,
          remaining.substring(0, end).trimRight(),
        ),
      );
      painter.dispose();
      start += end;
    }
  }
  return leaves;
}

class CodexGrimoire extends StatefulWidget {
  const CodexGrimoire({super.key, required this.chapters});
  final List<CodexChapter> chapters;
  @override
  State<CodexGrimoire> createState() => _CodexGrimoireState();
}

class _CodexGrimoireState extends State<CodexGrimoire> {
  final _turner = GlobalKey<CodexPageTurnState>();
  List<_Leaf> _leaves = [];
  Object? _layout;
  int _spread = 0, _perSpread = 1, _chapter = 0, _offset = 0;
  @override
  void didUpdateWidget(CodexGrimoire oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chapters != widget.chapters) _layout = null;
  }

  int get _spreads => (_leaves.length / _perSpread).ceil();
  void _turn(int target) {
    if (target < 0 || target >= _spreads) return;
    _turner.currentState?.turnTo(target);
  }

  Future<void> _contents() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Sommaire du grimoire',
                style: TextStyle(fontFamily: 'Cormorant', fontSize: 26),
              ),
            ),
            for (var i = 0; i < widget.chapters.length; i++)
              ListTile(
                title: Text(widget.chapters[i].title),
                leading: const Icon(Icons.auto_stories_outlined),
                trailing: Text(
                  '${_leaves.indexWhere((p) => p.chapter == i) + 1}',
                ),
                onTap: () => Navigator.pop(context, i),
              ),
          ],
        ),
      ),
    );
    if (!mounted || selected == null) return;
    final leaf = _leaves.indexWhere((p) => p.chapter == selected);
    if (leaf >= 0) _turn(leaf ~/ _perSpread);
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
          _turn(_spread - 1),
      const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
          _turn(_spread + 1),
    },
    child: Focus(
      autofocus: true,
      child: Material(
        color: const Color(0xFF0A1114),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.auto_stories,
                      color: Color(0xFFD6AE70),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Codex de la partie',
                        style: TextStyle(
                          fontFamily: 'Cormorant',
                          fontSize: 25,
                          color: Color(0xFFF2E8D5),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fermer le Codex',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1220),
                      child: LayoutBuilder(
                        builder: (context, size) {
                          final two =
                              MediaQuery.orientationOf(context) ==
                                  Orientation.landscape &&
                              size.maxWidth >= 560;
                          final perSpread = two ? 2 : 1;
                          const cover = 10.0, gutter = 8.0;
                          final width =
                              (size.maxWidth - cover * 2 - (two ? gutter : 0)) /
                              perSpread;
                          final height = size.maxHeight - cover * 2;
                          final margin = (width * .065).clamp(15.0, 32.0);
                          final scaler = MediaQuery.textScalerOf(context);
                          final heading = math.max(
                            56.0,
                            scaler.scale(24) * 2.12,
                          );
                          final bodyHeight = math.max(
                            32.0,
                            height - margin * 2 - heading - 28,
                          );
                          final token = (
                            width,
                            height,
                            scaler.scale(16),
                            two,
                            Directionality.of(context),
                          );
                          if (_layout != token) {
                            _layout = token;
                            _leaves = _paginate(
                              widget.chapters,
                              width - margin * 2,
                              bodyHeight - 4,
                              scaler,
                              Directionality.of(context),
                            );
                            _perSpread = perSpread;
                            final anchor = _leaves.indexWhere(
                              (p) => p.chapter == _chapter && p.end > _offset,
                            );
                            _spread = math.max(0, anchor) ~/ _perSpread;
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) setState(() {});
                            });
                          }
                          return DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF65432B),
                                  Color(0xFF2D1C17),
                                  Color(0xFF795237),
                                ],
                              ),
                              border: Border.all(
                                color: const Color(0xFFB08B50),
                                width: 1.5,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black87,
                                  blurRadius: 22,
                                  offset: Offset(0, 7),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(cover),
                              child: CodexPageTurn(
                                key: _turner,
                                index: _spread,
                                count: _spreads,
                                doublePage: two,
                                layoutToken: token,
                                gutter: gutter,
                                pageBuilder: (index, left) =>
                                    _page(index, margin, heading, left),
                                onChanged: (index) => setState(() {
                                  _spread = index;
                                  final leaf = _leaves[index * _perSpread];
                                  _chapter = leaf.chapter;
                                  _offset = leaf.start;
                                }),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 58,
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Page précédente',
                        onPressed: _spread > 0
                            ? () => _turn(_spread - 1)
                            : null,
                        icon: const Icon(Icons.chevron_left, size: 28),
                      ),
                      Expanded(
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            _leaves.isEmpty
                                ? ''
                                : '${_perSpread == 2 ? 'Pages' : 'Page'} ${_spread * _perSpread + 1}${_perSpread == 2 && _spread * 2 + 2 <= _leaves.length ? '–${_spread * 2 + 2}' : ''} / ${_leaves.length}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFFE6D4AC),
                            ),
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _contents,
                        icon: const Icon(Icons.list, size: 20),
                        label: const Text('Sommaire'),
                      ),
                      IconButton(
                        tooltip: 'Page suivante',
                        onPressed: _spread + 1 < _spreads
                            ? () => _turn(_spread + 1)
                            : null,
                        icon: const Icon(Icons.chevron_right, size: 28),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  Widget _page(int index, double margin, double heading, bool left) {
    final leaf = index < _leaves.length ? _leaves[index] : null;
    return ClipRRect(
      borderRadius: BorderRadius.horizontal(
        left: Radius.circular(left ? 7 : 2),
        right: Radius.circular(left ? 2 : 7),
      ),
      child: CustomPaint(
        painter: _Parchment(left),
        child: Padding(
          padding: EdgeInsets.all(margin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: heading,
                child: Center(
                  child: Text(
                    leaf == null
                        ? 'Fin du grimoire'
                        : widget.chapters[leaf.chapter].title,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      inherit: false,
                      fontFamily: 'Cormorant',
                      fontSize: 24,
                      height: 1.05,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: leaf == null
                    ? const Center(
                        child: Icon(
                          Icons.nights_stay_outlined,
                          color: Color(0xFF967B4C),
                          size: 44,
                        ),
                      )
                    : Text(
                        leaf.text,
                        key: ValueKey('codex-leaf-$index'),
                        style: _body,
                      ),
              ),
              SizedBox(
                height: 28,
                child: Center(
                  child: Text(
                    '— ${index + 1} —',
                    style: const TextStyle(
                      inherit: false,
                      color: Color(0xFF775C36),
                      fontFamily: 'Cormorant',
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Parchment extends CustomPainter {
  const _Parchment(this.left);
  final bool left;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFFD0AF78),
            Color(0xFFF2E3BC),
            Color(0xFFE8D3A1),
            Color(0xFFCCAC77),
          ],
          stops: [0, .12, .88, 1],
        ).createShader(rect),
    );
    final random = math.Random(73);
    final grain = Paint()
      ..color = const Color(0xFF76512E).withValues(alpha: .085)
      ..strokeWidth = .6;
    for (var i = 0; i < 100; i++) {
      final point = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      canvas.drawLine(
        point,
        point + Offset(3 + random.nextDouble() * 18, random.nextDouble() * 2),
        grain,
      );
    }
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: left ? Alignment.centerRight : Alignment.centerLeft,
          end: left ? Alignment.centerLeft : Alignment.centerRight,
          colors: [
            const Color(0xFF54341F).withValues(alpha: .35),
            Colors.transparent,
            Colors.transparent,
          ],
          stops: const [0, .12, 1],
        ).createShader(rect),
    );
    final line = Paint()
      ..color = const Color(0xFF876535).withValues(alpha: .45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .7;
    for (var inset = 2.0; inset < 6; inset += 2) {
      canvas.drawRect(rect.deflate(inset), line);
    }
    final ornament = Paint()
      ..color = const Color(0xFF94703D).withValues(alpha: .6);
    for (final x in [12.0, size.width - 12]) {
      for (final y in [12.0, size.height - 12]) {
        canvas.drawCircle(Offset(x, y), 2, ornament);
      }
    }
  }

  @override
  bool shouldRepaint(_Parchment oldDelegate) => oldDelegate.left != left;
}
