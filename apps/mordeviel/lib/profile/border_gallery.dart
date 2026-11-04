import 'package:flutter/material.dart';
import 'avatar_border.dart';
import 'player_avatar.dart';

class AvatarBorderGallery extends StatefulWidget {
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
  @override
  State<AvatarBorderGallery> createState() => _AvatarBorderGalleryState();
}

class _AvatarBorderGalleryState extends State<AvatarBorderGallery> {
  bool _illustrated = false;
  List<Map<String, dynamic>> get borders => widget.borders
      .where((b) => (b['effect'] == 'artwork') == _illustrated)
      .toList();
  Map? get current => widget.current;
  bool get canEdit => widget.canEdit;
  ValueChanged<Map<String, dynamic>> get onSelect => widget.onSelect;

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
                  padding: EdgeInsets.all(
                    border['effect'] == 'artwork' ? 0 : 15,
                  ),
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
            const Text('Bordure à débloquer', textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text(
              'Retrouve les récompenses du carnet des défis ou les offres quotidiennes de la boutique en Lunes d’or.',
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
        'Anneaux animés et cadres illustrés autour de ton portrait. Gagne des récompenses dans le carnet des défis. Touche une bordure pour voir son aperçu.',
      ),
      const SizedBox(height: 14),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ChoiceChip(
            label: const Text('Animées'),
            selected: !_illustrated,
            onSelected: (_) => setState(() => _illustrated = false),
          ),
          ChoiceChip(
            label: const Text('Illustrées'),
            selected: _illustrated,
            onSelected: (_) => setState(() => _illustrated = true),
          ),
        ],
      ),
      const SizedBox(height: 10),
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
                                  padding: EdgeInsets.all(
                                    border['effect'] == 'artwork' ? 0 : 10,
                                  ),
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
                            ? 'Bordure à débloquer'
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
