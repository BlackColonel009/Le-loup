import 'dart:convert';
import 'dart:io';
import '../lib/local_host.dart';

/// Private JSON-lines control channel. Only FastAPI owns stdin/stdout.
Future<void> main() async {
  final host = LocalHost();
  final bots = TestBotTable(host, practice: false);
  void emit(Map<String, dynamic> event) => stdout.writeln(jsonEncode(event));
  final subscription = host.updates.listen(
    (snapshot) => emit({'type': 'host.snapshot', 'room': snapshot}),
  );
  try {
    await for (final line
        in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
      dynamic id;
      try {
        final command = jsonDecode(line) as Map<String, dynamic>;
        id = command['id'];
        switch (command['action']) {
          case 'create':
            await host.start(
              port: 0,
              nickname: command['nickname'] as String,
              bindAddress: '127.0.0.1',
            );
          case 'configure':
            host.configure(
              Map<String, int>.from(command['deck'] as Map),
              campOnly: command['camp_only'] as bool,
              revealOnDeath: command['reveal_on_death'] as bool?,
              revealRescuer: command['reveal_rescuer'] as bool?,
              pack: command['pack'] as String?,
              sentences: (command['sentences'] as List?)?.cast<String>(),
              cardStyles: (command['card_styles'] as Map?)
                  ?.cast<String, String>(),
            );
          case 'narration.configure':
            host.setNarration(
              profile: command['profile'] as String,
              automatic: command['automatic'] as bool,
            );
          case 'lock':
            host.setLocked(command['locked'] as bool);
          case 'kick':
            await host.kick(command['player_id'] as String);
          case 'bots.add':
            final count = command['count'];
            if (count is! int) throw ArgumentError('Nombre de bots invalide.');
            await bots.add(count);
          case 'bots.configure':
            final paused = command['paused'];
            final delay = command['delay_ms'];
            if (paused is! bool ||
                delay is! int ||
                ![250, 900, 2500].contains(delay)) {
              throw ArgumentError('Réglage des bots invalide.');
            }
            bots.paused = paused;
            bots.delay = Duration(milliseconds: delay);
          case 'start':
            host.startGame();
          case 'night.start':
            host.startNight(seconds: command['seconds'] as int? ?? 120);
          case 'night.call':
            host.callNight(command['call'] as String);
          case 'night.advance':
            host.advanceNight();
          case 'night.finish':
            host.finishNight();
          case 'pause':
            host.pauseNight();
          case 'resume':
            host.resumeNight();
          case 'vote.start':
            host.startVote(seconds: command['seconds'] as int? ?? 120);
          case 'day.chat':
            host.setDayChat(command['open'] as bool);
          case 'sentence.spin':
            host.spinSentence();
          case 'sentence.continue':
            host.continueAfterSentence();
          case 'snapshot':
            break;
          default:
            throw ArgumentError('Commande MDJ inconnue.');
        }
        emit({
          'type': 'command.ok',
          'id': id,
          'port': host.port,
          'room': host.snapshot,
        });
      } catch (error) {
        emit({
          'type': 'command.error',
          'id': id,
          'message': error is StateError
              ? error.message
              : error is ArgumentError
              ? (error.message ?? 'Paramètres invalides.').toString()
              : 'Cette commande n’a pas pu être exécutée. Réessaie.',
        });
      }
    }
  } finally {
    await subscription.cancel();
    await bots.dispose();
    await host.dispose();
  }
}
