import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/public_content.dart';
import '../services/server_config.dart';
import '../social/social_api.dart';
import 'collection_screen.dart';
import '../cards/card_gallery.dart';
import '../cards/classic_role.dart';

/// Optional daily welcome: never interrupts a game or blocks an offline launch.
Future<void> showDailyCollector(BuildContext context) async {
  try {
    Map<String, dynamic> data;
    bool signed = true;
    try {
      data = await SocialApi.instance.request('/collection/me');
    } on SocialError catch (error) {
      if (error.status != 401 && error.status != 403) rethrow;
      signed = false;
      data = await loadPublicContent('collection/catalog');
    }
    final ids = data['daily_ids'] as List;
    final offers = (data['products'] as List)
        .cast<Map>()
        .where(
          (p) =>
              ids.contains(p['id']) && p['visible'] == 1 && p['collector'] == 1,
        )
        .toList();
    if (offers.isEmpty ||
        !context.mounted ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    if (WidgetsBinding.instance.lifecycleState != null &&
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    if (signed) {
      final visit = await SocialApi.instance.request(
        '/collection/collector/visit',
        method: 'POST',
      );
      if (visit['show'] != true) return;
    } else {
      final prefs = await SharedPreferences.getInstance();
      final key = 'collector_welcome_guest:$apiBaseUrl';
      if (prefs.getString(key) == data['day']) return;
      await prefs.setString(key, data['day'] as String);
    }
    if (!context.mounted || ModalRoute.of(context)?.isCurrent != true) return;
    final open = await showDialog<bool>(
      context: context,
      builder: (dialog) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      tooltip: 'Continuer l’aventure',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(dialog, false),
                    ),
                  ),
                  Image.asset(
                    'assets/store/collector.png',
                    height: 180,
                    fit: BoxFit.contain,
                  ),
                  Text(
                    'Psst… mes trouvailles du jour !',
                    style: Theme.of(dialog).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '« De l’or, des ombres et quelques secrets… J’ai déniché ces merveilles pour toi. Reviens demain : mes étagères ne gardent jamais les mêmes trésors. »',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 140,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final p in offers.where(
                          (p) => p['kind'] == 'card',
                        ))
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: SizedBox(
                              width: 95,
                              child: RoleCardFront(
                                role: configuredRole(
                                  p['role_id'] == 'villager_female'
                                      ? 'villager'
                                      : p['role_id'] as String,
                                  feminine: p['role_id'] == 'villager_female',
                                ),
                                ambience: p['theme'] == 'horror'
                                    ? CardAmbience.horror
                                    : CardAmbience.intense,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final p in offers)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Icon(
                            p['kind'] == 'voice'
                                ? Icons.record_voice_over_outlined
                                : p['kind'] == 'theme'
                                ? Icons.landscape_outlined
                                : Icons.style_outlined,
                            color: const Color(0xFFD6B16D),
                            size: 20,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              '${p['title']} · ${p['theme'] == 'intense' ? 'Intense' : 'Horreur'}',
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (data['free_access'] == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'Accès gratuit · encore ${data['free_days_remaining']} jours',
                        style: const TextStyle(color: Color(0xFFD6B16D)),
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(dialog, true),
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Voir les trouvailles'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialog, false),
                    child: const Text('Continuer l’aventure'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (open == true && context.mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => const CollectionScreen(initialTab: 1),
        ),
      );
    }
  } catch (_) {
    // Discovery is optional; network/storage errors must leave the welcome usable.
  }
}
