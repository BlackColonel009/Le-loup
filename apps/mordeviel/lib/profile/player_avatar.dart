import 'package:flutter/material.dart';
import '../community/community_session.dart';
import '../content/content_image.dart';
import '../content/pack_store.dart';
import '../social/social_api.dart';
import '../services/server_config.dart';
import 'avatar_catalog.g.dart';
export 'avatar_catalog.g.dart';

class PlayerAvatar extends StatefulWidget {
  const PlayerAvatar({
    super.key,
    this.avatar,
    this.nickname = '',
    this.size = 84,
  });
  final Map? avatar;
  final String nickname;
  final double size;
  @override
  State<PlayerAvatar> createState() => _PlayerAvatarState();
}

class _PlayerAvatarState extends State<PlayerAvatar> {
  Future<CommunitySession?>? _session;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    if (widget.avatar?['kind'] == 'photo') {
      _session = SocialApi.instance.session();
    }
    PackStore.instance.initialize().catchError((Object _) {});
  }

  @override
  void didUpdateWidget(PlayerAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.avatar?['photo_url'] != widget.avatar?['photo_url']) _load();
  }

  Widget _placeholder() => ColoredBox(
    color: const Color(0xFF28313B),
    child: Center(
      child: widget.nickname.isEmpty
          ? Icon(
              Icons.person_outline,
              size: widget.size * .55,
              color: const Color(0xFFD6AE70),
            )
          : Text(
              widget.nickname.characters.first.toUpperCase(),
              style: TextStyle(
                fontSize: widget.size * .4,
                color: const Color(0xFFD6AE70),
              ),
            ),
    ),
  );
  @override
  Widget build(BuildContext context) => Semantics(
    label:
        'Portrait de ${widget.nickname.isEmpty ? 'joueur' : widget.nickname}',
    image: true,
    child: Center(
      child: SizedBox.square(
        dimension: widget.size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFC9A66C), width: 2),
            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 9)],
          ),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: ClipOval(child: _portrait()),
          ),
        ),
      ),
    ),
  );
  Widget _portrait() {
    final photo = widget.avatar?['photo_url'];
    if (widget.avatar?['kind'] == 'photo' &&
        photo is String &&
        RegExp(
          r'^/community/avatars/photo/\d+/[a-f0-9]{32}\.webp$',
        ).hasMatch(photo)) {
      return FutureBuilder<CommunitySession?>(
        future: _session,
        builder: (context, value) {
          if (value.data == null) return _placeholder();
          return Image.network(
            Uri.parse(apiBaseUrl).resolve(photo).toString(),
            headers: {'Authorization': 'Bearer ${value.data!.token}'},
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _placeholder(),
          );
        },
      );
    }
    final definition = avatarCatalog
        .where((a) => a['id'] == widget.avatar?['id'])
        .firstOrNull;
    if (definition == null) return _placeholder();
    return ListenableBuilder(
      listenable: PackStore.instance,
      builder: (context, _) {
        if (PackStore.instance.pathFor(definition['asset'] as String) == null) {
          return Stack(
            fit: StackFit.expand,
            children: [
              _placeholder(),
              Positioned(
                right: 5,
                bottom: 5,
                child: Icon(
                  Icons.download_for_offline_outlined,
                  size: widget.size * .22,
                  color: const Color(0xFFD6AE70),
                ),
              ),
            ],
          );
        }
        final crop = (definition['crop'] as List).cast<num>();
        return LayoutBuilder(
          builder: (context, box) {
            final width = box.maxWidth / crop[2],
                height = box.maxHeight / crop[3];
            return OverflowBox(
              alignment: Alignment.topLeft,
              maxWidth: width,
              minWidth: width,
              maxHeight: height,
              minHeight: height,
              child: Transform.translate(
                offset: Offset(-crop[0] * width, -crop[1] * height),
                child: ContentImage(
                  definition['asset'] as String,
                  width: width,
                  height: height,
                  fit: BoxFit.fill,
                  cacheWidth: 768,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
