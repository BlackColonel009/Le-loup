import 'package:flutter/material.dart';
import '../services/immersion_preferences.dart';

class NarrativeJournal extends StatefulWidget {
  const NarrativeJournal({
    super.key,
    required this.events,
    required this.describe,
  });
  final List events;
  final String Function(Map) describe;
  @override
  State<NarrativeJournal> createState() => _NarrativeJournalState();
}

class _NarrativeJournalState extends State<NarrativeJournal> {
  int? _night;
  final _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nights =
        widget.events.map((e) => e['night'] as int? ?? 0).toSet().toList()
          ..sort();
    final events = widget.events
        .where((e) => _night == null || e['night'] == _night)
        .toList();
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF27251F), Color(0xFF11171E)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Le grimoire du village',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFFE5C58C),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${widget.events.length} événements · ${widget.events.where((e) => e['kind'] == 'death').length} éliminations',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              spacing: 8,
              children: [
                for (final n in [null, ...nights])
                  ChoiceChip(
                    label: Text(
                      n == null
                          ? 'Toute l’histoire'
                          : n == 0
                          ? 'Préparation'
                          : 'Manche $n',
                    ),
                    selected: _night == n,
                    onSelected: (_) {
                      setState(() => _night = n);
                      if (_scroll.hasClients) _scroll.jumpTo(0);
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              itemCount: events.length,
              itemBuilder: (context, i) {
                final event = events[i] as Map;
                final previous = i == 0 ? null : events[i - 1] as Map;
                final night = event['night'] ?? 0;
                final phase = event['phase'];
                final day = [
                  'dawn',
                  'hunter',
                  'scapegoat',
                  'day',
                  'voting',
                  'mayor_election',
                  'mayor_succession',
                  'vote_result',
                  'ended',
                ].contains(phase);
                final heading =
                    previous == null ||
                    previous['night'] != night ||
                    ['dawn', 'sleep'].contains(phase) &&
                        previous['phase'] != phase;
                final death = event['kind'] == 'death';
                return TweenAnimationBuilder<double>(
                  key: ValueKey('journal-$_night-$i'),
                  tween: Tween(begin: 0, end: 1),
                  duration: ImmersionPreferences.instance.reduced(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 250),
                  builder: (context, value, child) => Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, (1 - value) * 8),
                      child: child,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (heading)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            night == 0
                                ? 'Préparation'
                                : '${day ? 'Jour' : 'Nuit'} $night',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(color: const Color(0xFFE5C58C)),
                          ),
                        ),
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xC020272B),
                          borderRadius: BorderRadius.circular(14),
                          border: Border(
                            left: BorderSide(
                              color: death
                                  ? const Color(0xFFAA5B5B)
                                  : const Color(0xFF997A4A),
                              width: 3,
                            ),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              death
                                  ? Icons.local_fire_department_outlined
                                  : event['kind'] == 'phase'
                                  ? day
                                        ? Icons.wb_sunny_outlined
                                        : Icons.nights_stay_outlined
                                  : Icons.history_edu,
                              size: 20,
                              color: const Color(0xFFCFB78F),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SelectableText(widget.describe(event)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
