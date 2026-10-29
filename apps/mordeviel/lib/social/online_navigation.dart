import 'package:flutter/material.dart';
import '../community/community_screen.dart';
import '../lobby.dart';
import '../joining/room_nickname_dialog.dart';
import 'social_api.dart';

Future<void> openOnlineLobby(
  BuildContext context, {
  String? code,
  bool publicRoom = false,
  String title = 'Le village de la nuit',
  String theme = 'classic',
}) async {
  var session = await SocialApi.instance.session();
  if (!context.mounted) return;
  if (session == null) {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const CommunityScreen()));
    session = await SocialApi.instance.session();
  }
  if (!context.mounted || session == null) return;
  final nickname = await chooseRoomNickname(context);
  if (!context.mounted || nickname == null) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => LocalLobbyScreen(
        online: true,
        initialCode: code,
        initialNickname: nickname,
        communityToken: session!.token,
        autoStart: true,
        publicRoom: publicRoom,
        roomTitle: title,
        initialTheme: theme,
      ),
    ),
  );
}

String themeName(dynamic id) => switch (id) {
  'intense' => 'Intense',
  'horror' => 'Horreur',
  'mixed' => 'Mixte',
  _ => 'Classique',
};
