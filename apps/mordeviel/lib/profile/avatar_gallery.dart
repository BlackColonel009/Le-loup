import 'dart:async';
import 'dart:convert';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import '../content/pack_store.dart';
import '../content/require_packs.dart';
import '../social/social_api.dart';
import '../challenges/challenges_screen.dart';
import 'player_avatar.dart';
import 'profile_photo.dart';
import 'avatar_border.dart';
import 'border_gallery.dart';

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
    for (final a in avatarCatalog)
      if (a['creator_only'] != true) {...a, 'locked': a['starter'] != true},
  ];
  List<Map<String, dynamic>> _borders = [
    for (final b in avatarBorderCatalog)
      if (b['creator_only'] != true) {...b, 'locked': b['free'] != true},
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
      unawaited(
        PackStore.instance
            .initialize()
            .then((_) => PackStore.instance.refresh())
            .catchError((Object _) {}),
      );
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
            if (data['borders'] is List) {
              _borders = (data['borders'] as List)
                  .map((v) => Map<String, dynamic>.from(v as Map))
                  .toList();
            }
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
        'Ce visage est verrouillé. Consulte le carnet des défis pour découvrir les portraits à gagner.',
      );
      return;
    }
    if (!_canEdit) {
      _message(
        'Connecte-toi à la communauté puis ouvre ton profil pour choisir ce portrait.',
      );
      return;
    }
    final definition = avatarCatalog
        .where((a) => a['id'] == avatar['id'])
        .firstOrNull;
    if (definition != null &&
        PackStore.instance.pathFor(definition['asset'] as String) == null) {
      try {
        await PackStore.instance.refresh();
      } catch (_) {
        if (mounted) {
          _message(
            PackStore.instance.error ??
                'Actualise les téléchargements avec Internet pour récupérer ce portrait.',
          );
        }
        return;
      }
      if (!mounted) return;
    }
    if (!await ensurePacksAvailable(context, [
      avatar['pack_id'] as String? ?? 'avatars-classic',
    ], reason: 'Télécharge le pack de ce portrait pour l’utiliser.')) {
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

  Future<void> _selectBorder(Map<String, dynamic> border) async {
    if (!_canEdit) {
      _message('Connecte-toi à la communauté pour personnaliser ta bordure.');
      return;
    }
    if (border['pack_id'] is String &&
        !await ensurePacksAvailable(
          context,
          [border['pack_id'] as String],
          reason: 'Télécharge cette bordure pour l’utiliser sur ton profil.',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => _saving = true);
    try {
      await _request(
        'avatar/border',
        method: 'PUT',
        body: {'border_id': border['id']},
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _message('$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _download([List<String> ids = const ['avatars-classic']]) async {
    try {
      await PackStore.instance.refresh();
    } catch (_) {
      if (mounted) {
        _message(
          PackStore.instance.error ??
              'Le catalogue est inaccessible. Vérifie Internet puis réessaie.',
        );
      }
      return;
    }
    if (!mounted) return;
    await ensurePacksAvailable(
      context,
      ids,
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
          if (_current?['is_creator'] == true) ...[
            const SizedBox(height: 10),
            const Center(child: CreatorBadge()),
          ],
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: _download,
                icon: const Icon(Icons.download_outlined),
                label: const Text('Pack d’avatars Classiques'),
              ),
              OutlinedButton.icon(
                onPressed: () => _download(const ['avatars-rewards']),
                icon: const Icon(Icons.person_outline),
                label: const Text('Profils à gagner'),
              ),
              OutlinedButton.icon(
                onPressed: () => _download(const ['borders-rewards']),
                icon: const Icon(Icons.filter_frames_outlined),
                label: const Text('Bordures à gagner'),
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
          AvatarBorderGallery(
            borders: _borders,
            current: _current,
            canEdit: _canEdit,
            onSelect: _selectBorder,
          ),
          const SizedBox(height: 24),
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
            'Remporte les défis pour gagner de nouveaux portraits. D’autres récompenses enrichiront aussi cette collection.',
          ),
          TextButton.icon(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ChallengesScreen(),
                ),
              );
              if (mounted) await _load();
            },
            icon: const Icon(Icons.workspace_premium_outlined),
            label: const Text('Consulter mes défis'),
          ),
          _grid(_avatars.where((a) => a['locked'] == true).toList()),
          const SizedBox(height: 18),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'Les récompenses reçues restent dans ton compte. Les prochaines collections enrichiront les défis et les offres de la boutique.',
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
              '${avatar['title']}${locked ? ', verrouillé' : ', disponible'}',
          child: InkWell(
            key: ValueKey('avatar-${avatar['id']}'),
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
