import 'package:flutter_test/flutter_test.dart';
import 'package:mordeviel/joining/online_invitation.dart';
import 'package:mordeviel/services/server_config.dart';

void main() {
  test('Invitation : vrai site, code et clé MEGA conservée', () async {
    const download = 'https://mega.nz/file/jeu#cle-de-partage';
    final message = await loadOnlineInvitation(
      '123456',
      load: (path) async {
        expect(path, 'site-config');
        return {'download_url': download};
      },
    );
    expect(message, contains(publicSiteUrl));
    expect(message, contains('Code du salon : 123456'));
    expect(message, contains(download));
    expect(message, contains('Jouer en ligne → Rejoindre le village'));
    expect(message, contains('Mordeviel'));
    expect(message, isNot(contains('host_token')));
  });
  test(
    'Téléchargement inactif ou indisponible : le code reste partageable',
    () async {
      final disabled = await loadOnlineInvitation(
        '654321',
        load: (_) async => {'download_url': ''},
      );
      final offline = await loadOnlineInvitation(
        '654321',
        load: (_) async => throw StateError('offline'),
      );
      expect(disabled, offline);
      expect(offline, contains('654321'));
      expect(offline, contains(publicSiteUrl));
      expect(offline, isNot(contains('Télécharger l’APK')));
    },
  );
  test('Un lien non HTTPS et un code invalide ne sont pas partagés', () {
    final invitation = onlineInvitationText(
      '123456',
      downloadUrl: 'javascript:alert(1)',
    );
    expect(invitation, isNot(contains('javascript')));
    expect(() => onlineInvitationText('123'), throwsFormatException);
  });
}
