import '../services/server_config.dart';
import '../services/public_content.dart';

Future<String> loadOnlineInvitation(
  String code, {
  Future<Map<String, dynamic>> Function(String)? load,
}) async {
  String? downloadUrl;
  try {
    final config = await (load ?? loadPublicContent)(
      'site-config',
    ).timeout(const Duration(seconds: 3));
    downloadUrl = config['download_url'] as String?;
  } catch (_) {
    // The site and room code remain shareable during a temporary outage.
  }
  return onlineInvitationText(code, downloadUrl: downloadUrl);
}

String onlineInvitationText(String code, {String? downloadUrl}) {
  if (!RegExp(r'^\d{6}$').hasMatch(code)) {
    throw const FormatException('Code de salon invalide.');
  }
  final download = Uri.tryParse(downloadUrl ?? '');
  final validDownload =
      download != null &&
      download.scheme == 'https' &&
      download.host.isNotEmpty &&
      download.userInfo.isEmpty &&
      !RegExp(r'\s').hasMatch(downloadUrl ?? '');
  return '🐺 Rejoins mon village dans Mordeviel !\n\n'
      'Site : $publicSiteUrl\n'
      'Code du salon : $code\n\n'
      'Dans l’application : Jouer en ligne → Rejoindre le village.'
      '${validDownload ? '\n\nTu n’as pas encore l’application ?\nTélécharger l’APK Android : $downloadUrl' : ''}';
}
