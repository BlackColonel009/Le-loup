import 'dart:async';
import 'dart:convert';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import '../content/pack_store.dart';
import '../content/require_packs.dart';
import '../social/social_api.dart';
import 'player_avatar.dart';
import 'profile_photo.dart';

typedef AvatarRequest =
    Future<Map<String, dynamic>> Function(
      String path, {
      String method,
      Map<String, dynamic>? body,
    });

class AvatarGalleryScreen extends StatefulWidget {
  const AvatarGalleryScreen({super.key, this.request});
  final AvatarRequest? request;
  @override
  State<AvatarGalleryScreen> createState() => _AvatarGalleryScreenState();
}

class _AvatarGalleryScreenState extends State<AvatarGalleryScreen> {
  List<Map<String, dynamic>> _avatars = [
    for (final a in avatarCatalog) {...a, 'locked': a['starter'] != true},
  ];
  Map? _current;
  bool _loading = true, _saving = false, _canEdit = false;
  String? _error;
  Future<Map<String, dynamic>> _request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) => widget.request != null
      ? widget.request!(path, method: method, body: body)
      : SocialApi.instance.request(
          '/community/$path',
          method: method,
          body: body,
        );
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      unawaited(PackStore.instance.initialize().catchError((Object _) {}));
      final loggedIn =
          widget.request != null || await SocialApi.instance.session() != null;
      if (loggedIn) {
        final data = await _request('avatars');
        if (mounted) {
          setState(() {
            _avatars = (data['avatars'] as List)
                .map((v) => Map<String, dynamic>.from(v as Map))
                .toList();
            _current = data['avatar'] as Map?;
            _canEdit = true;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Impossible d’actualiser tes portraits. Réessaie après la mise à jour du serveur.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  Future<void> _select(Map avatar) async {
    if (avatar['locked'] == true) {
      _message(
        'Ce visage se débloquera grâce aux futurs défis. Les conditions seront annoncées dans le jeu.',
      );
      return;
    }
    if (!_canEdit) {
      _message(
        'Connecte-toi à la communauté puis ouvre ton profil pour choisir ce portrait.',
      );
      return;
    }
    if (!await ensurePacksAvailable(
      context,
      ['avatars-classic'],
      reason: 'Télécharge les visages Classiques pour utiliser ce portrait.',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => _saving = true);
    try {
      await _request(
        'avatar',
        method: 'PUT',
        body: {'avatar_id': avatar['id']},
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _message('$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _photo() async {
    if (!_canEdit) {
      _message('Connecte-toi à la communauté pour personnaliser ton portrait.');
      return;
    }
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'Photo',
            extensions: ['jpg', 'jpeg', 'png', 'webp'],
            mimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
            uniformTypeIdentifiers: ['public.image'],
          ),
        ],
      );
      if (file == null) return;
      if (await file.length() > 8 * 1048576) {
        throw const FormatException('Choisis une photo de moins de 8 Mo.');
      }
      if (!mounted) return;
      setState(() => _saving = true);
      final bytes = await prepareProfilePhoto(await file.readAsBytes());
      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Mon portrait'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipOval(child: Image.memory(bytes, width: 160, height: 160)),
              const SizedBox(height: 16),
              const Text('Cette photo sera visible sur ton profil joueur.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      await _request(
        'avatar/photo',
        method: 'PUT',
        body: {'image_base64': base64Encode(bytes)},
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        _message(
          e is FormatException
              ? e.message.toString()
              : 'La photo n’a pas pu être enregistrée. Réessaie avec une autre image.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _download() async {
    await ensurePacksAvailable(
      context,
      ['avatars-classic'],
      reason:
          'Les images des avatars sont un pack téléchargeable. Elles restent ensuite disponibles sur cet appareil.',
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Les visages du village')),
    body: AbsorbPointer(
      absorbing: _saving,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_loading || _saving) const LinearProgressIndicator(),
          const Text(
            'Un visage pour ton aventure',
            style: TextStyle(fontFamily: 'Cormorant', fontSize: 29),
          ),
          const SizedBox(height: 10),
          const Text(
            'Quatre portraits Classiques sont disponibles. Ton premier visage est attribué au hasard et reste lié à ton compte ; tu peux le changer ici.',
          ),
          const SizedBox(height: 14),
          if (_current != null) PlayerAvatar(avatar: _current, size: 88),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: _download,
                icon: const Icon(Icons.download_outlined),
                label: const Text('Pack d’avatars Classiques'),
              ),
              if (_canEdit)
                OutlinedButton.icon(
                  onPressed: _photo,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Ma propre photo'),
                ),
            ],
          ),
          if (!_canEdit && !_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Connecte-toi à la communauté et ouvre ton profil pour choisir ton portrait.',
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_error!),
            ),
          const SizedBox(height: 22),
          const Text(
            'Disponibles au départ',
            style: TextStyle(fontFamily: 'Cormorant', fontSize: 26),
          ),
          _grid(_avatars.where((a) => a['locked'] != true).toList()),
          const SizedBox(height: 22),
          const Text(
            'Les visages à conquérir',
            style: TextStyle(fontFamily: 'Cormorant', fontSize: 26),
          ),
          const Text(
            'Défis à venir · ces portraits ne sont pas encore déblocables. Leurs conditions seront annoncées prochainement.',
          ),
          _grid(_avatars.where((a) => a['locked'] == true).toList()),
          const SizedBox(height: 18),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'Prochainement : collections Intense et Horreur. Les futurs avatars payants et les récompenses de défis seront présentés ici.',
              ),
            ),
          ),
        ],
      ),
    ),
  );
  Widget _grid(List<Map<String, dynamic>> avatars) => LayoutBuilder(
    builder: (context, box) => GridView.builder(
      padding: const EdgeInsets.only(top: 14),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: avatars.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: box.maxWidth >= 700
            ? 5
            : box.maxWidth >= 440
            ? 3
            : 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 155,
      ),
      itemBuilder: (context, index) {
        final avatar = avatars[index],
            locked = avatars[index]['locked'] == true;
        return Semantics(
          button: true,
          label:
              '${avatar['title']}${locked ? ', verrouillé, défi à venir' : ', disponible'}',
          child: InkWell(
            onTap: () => _select(avatar),
            borderRadius: BorderRadius.circular(16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF1A2730),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color:
                      _current?['id'] == avatar['id'] &&
                          _current?['kind'] != 'photo'
                      ? const Color(0xFFE1BD7B)
                      : const Color(0xFF4E554D),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Opacity(
                          opacity: locked ? .4 : 1,
                          child: PlayerAvatar(
                            avatar: {'id': avatar['id'], 'kind': 'game'},
                            nickname: avatar['title'] as String,
                            size: 78,
                          ),
                        ),
                        if (locked)
                          const Positioned.fill(
                            child: Center(
                              child: Icon(
                                Icons.lock,
                                color: Color(0xFFE4C58D),
                                size: 28,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Expanded(
                      child: Center(
                        child: Text(
                          avatar['title'] as String,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
