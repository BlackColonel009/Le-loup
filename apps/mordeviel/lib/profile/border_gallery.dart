import 'package:flutter/material.dart';
import 'avatar_border.dart';
import 'player_avatar.dart';

class AvatarBorderGallery extends StatelessWidget {
  const AvatarBorderGallery({
    super.key,
    required this.borders,
    required this.current,
    required this.canEdit,
    required this.onSelect,
  });
  final List<Map<String, dynamic>> borders;
  final Map? current;
  final bool canEdit;
  final ValueChanged<Map<String, dynamic>> onSelect;

  void _preview(BuildContext context, Map<String, dynamic> border) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(border['title'] as String),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 152,
              child: AnimatedAvatarBorder(
                border: border,
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: PlayerAvatar(
                    avatar: {...?current, 'border_id': 'none'},
                    size: 122,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Icon(Icons.lock_outline, color: Color(0xFFD6AE70)),
            const SizedBox(height: 8),
            const Text('Défis ou achat à venir', textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text(
              'Tu peux admirer son animation. Cette bordure n’est pas encore déblocable.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Bordure prémium.',
        style: TextStyle(fontFamily: 'Cormorant', fontSize: 27),
      ),
      const SizedBox(height: 6),
      const Text(
        'Des reflets en mouvement autour de ton portrait. Les bordures colorées seront déblocables par défis ou achat. Touche une bordure pour voir son animation.',
      ),
      const SizedBox(height: 14),
      LayoutBuilder(
        builder: (context, box) => GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: borders.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: box.maxWidth >= 700
                ? 4
                : box.maxWidth >= 440
                ? 3
                : 2,
            mainAxisExtent:
                189 +
                ((MediaQuery.textScalerOf(context).scale(14) / 14 - 1).clamp(
                      0,
                      2,
                    ) *
                    80),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (context, index) {
            final border = borders[index], locked = border['locked'] != false;
            final selected = (current?['border_id'] ?? 'none') == border['id'];
            return Semantics(
              button: true,
              label:
                  '${border['title']}, ${locked
                      ? 'verrouillée, aperçu animé'
                      : selected
                      ? 'sélectionnée'
                      : 'disponible'}',
              child: InkWell(
                key: ValueKey('border-${border['id']}'),
                borderRadius: BorderRadius.circular(16),
                onTap: () =>
                    locked ? _preview(context, border) : onSelect(border),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2730),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFFD6AE70)
                          : const Color(0xFF4E554D),
                    ),
                  ),
                  child: Column(
                    children: [
                      SizedBox.square(
                        dimension: 78,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (border['effect'] == 'none')
                              const Icon(
                                Icons.account_circle_outlined,
                                size: 65,
                                color: Color(0xFFD6AE70),
                              )
                            else
                              AnimatedAvatarBorder(
                                animate: false,
                                border: border,
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Opacity(
                                    opacity: locked ? .4 : 1,
                                    child: const CircleAvatar(
                                      backgroundColor: Color(0xFF28313B),
                                      child: Icon(
                                        Icons.person_outline,
                                        color: Color(0xFFD6AE70),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (locked)
                              const Center(
                                child: Icon(
                                  Icons.lock,
                                  size: 24,
                                  color: Color(0xFFE4C58D),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Center(
                          child: Text(
                            border['title'] as String,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        locked
                            ? 'Défis ou achat à venir'
                            : selected
                            ? 'Sélectionnée'
                            : canEdit
                            ? 'Choisir'
                            : 'Disponible',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFB5BCBA),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ],
  );
}
