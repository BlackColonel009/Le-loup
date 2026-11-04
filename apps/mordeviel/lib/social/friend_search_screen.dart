import 'dart:async';
import 'package:flutter/material.dart';
import '../profile/player_avatar.dart';
import 'social_api.dart';
import 'social_screens.dart';
import 'social_service.dart';

class FriendSearchScreen extends StatefulWidget {
  const FriendSearchScreen({super.key});
  @override
  State<FriendSearchScreen> createState() => _FriendSearchScreenState();
}

class _FriendSearchScreenState extends State<FriendSearchScreen> {
  final _query = TextEditingController();
  final _acting = <int>{};
  Timer? _debounce;
  int _revision = 0;
  bool _loading = false, _searched = false;
  String? _error;
  List<Map<String, dynamic>> _players = [];

  @override
  void dispose() {
    _revision++;
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _changed(String value) {
    _revision++;
    _debounce?.cancel();
    setState(() {
      _players = [];
      _error = null;
      _searched = false;
      _loading = value.trim().length >= 2;
    });
    if (_loading) {
      _debounce = Timer(const Duration(milliseconds: 350), _search);
    }
  }

  Future<void> _search() async {
    _debounce?.cancel();
    final query = _query.text.trim();
    if (query.length < 2) return;
    final revision = ++_revision;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await SocialApi.instance.request(
        '/social/players/search?q=${Uri.encodeQueryComponent(query)}',
      );
      if (!mounted || revision != _revision) return;
      setState(() {
        _players = (data['players'] as List)
            .map((p) => Map<String, dynamic>.from(p as Map))
            .toList();
        _searched = true;
      });
    } catch (error) {
      if (mounted && revision == _revision) {
        setState(
          () => _error = error is SocialError
              ? error.message
              : 'La recherche est indisponible pour le moment. Réessaie.',
        );
      }
    } finally {
      if (mounted && revision == _revision) setState(() => _loading = false);
    }
  }

  Future<void> _friend(Map<String, dynamic> player) async {
    final id = player['id'] as int;
    if (_acting.contains(id)) return;
    setState(() => _acting.add(id));
    try {
      final accept = player['request_incoming'] == true;
      await SocialApi.instance.request(
        '/social/friends/$id',
        method: 'POST',
        body: {'action': accept ? 'accept' : 'request'},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? '${player['nickname']} a rejoint tes amis.'
                : 'Demande envoyée à ${player['nickname']}.',
          ),
        ),
      );
      await _search();
      unawaited(SocialService.instance.refresh());
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is SocialError
                  ? error.message
                  : 'Impossible d’envoyer la demande pour le moment.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _acting.remove(id));
    }
  }

  Future<void> _visit(Map<String, dynamic> player) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SocialProfileScreen(userId: player['id'] as int),
      ),
    );
    if (mounted) await _search();
  }

  Widget _person(Map<String, dynamic> player) {
    final pending = player['relationship'] == 'pending';
    final incoming = pending && player['request_incoming'] == true;
    final friend = player['is_friend'] == true;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: SizedBox.square(
                dimension: 48,
                child: PlayerAvatar(
                  avatar: player['avatar'] as Map?,
                  nickname: player['nickname'] as String,
                  size: 48,
                ),
              ),
              title: Text(player['nickname'] as String),
              subtitle: Text(
                friend
                    ? 'Déjà dans tes amis'
                    : incoming
                    ? 'T’a envoyé une demande'
                    : pending
                    ? 'Demande déjà envoyée'
                    : 'Compagnon de Mordeviel',
              ),
              trailing: Icon(
                player['verified'] == true
                    ? Icons.verified
                    : Icons.chevron_right,
                color: player['verified'] == true
                    ? const Color(0xFFE1BA78)
                    : null,
              ),
              onTap: () => _visit(player),
            ),
            const SizedBox(height: 8),
            if (friend)
              OutlinedButton.icon(
                onPressed: () => _visit(player),
                icon: const Icon(Icons.person_outline),
                label: const Text('Voir le profil'),
              )
            else
              FilledButton.icon(
                onPressed:
                    _acting.contains(player['id']) || pending && !incoming
                    ? null
                    : () => _friend(player),
                icon: Icon(
                  pending && !incoming
                      ? Icons.schedule
                      : incoming
                      ? Icons.how_to_reg
                      : Icons.person_add_alt_1,
                ),
                label: Text(
                  _acting.contains(player['id'])
                      ? 'Un instant…'
                      : incoming
                      ? 'Accepter la demande'
                      : pending
                      ? 'Demande envoyée'
                      : 'Ajouter en ami',
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Trouver un compagnon')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: TextField(
            key: const ValueKey('friend-search-input'),
            controller: _query,
            maxLength: 24,
            autocorrect: false,
            textInputAction: TextInputAction.search,
            onChanged: _changed,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              labelText: 'Pseudo du joueur',
              hintText: 'Exemple : Logan',
              counterText: '',
              prefixIcon: const Icon(Icons.person_search_outlined),
              suffixIcon: _query.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Effacer la recherche',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _query.clear();
                        _changed('');
                      },
                    ),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: Text(
            'Recherche le pseudo de son compte, avec au moins 2 caractères.',
            style: TextStyle(fontSize: 13),
          ),
        ),
        if (_loading) const LinearProgressIndicator(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              if (_error != null) ...[
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(_error!, textAlign: TextAlign.center),
                ),
                TextButton.icon(
                  onPressed: _search,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Réessayer'),
                ),
              ] else if (!_loading && _players.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 40,
                    horizontal: 12,
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _searched ? Icons.search_off : Icons.group_add_outlined,
                        size: 56,
                        color: const Color(0xFFE1BA78),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searched
                            ? 'Aucun joueur trouvé. Vérifie son pseudo.'
                            : 'Retrouve tes compagnons et agrandis ton cercle.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              for (final player in _players) _person(player),
            ],
          ),
        ),
      ],
    ),
  );
}
