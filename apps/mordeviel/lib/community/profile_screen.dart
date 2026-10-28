import 'package:flutter/material.dart';
import 'password_reset_screen.dart';
import '../social/social_screens.dart';
import '../store/collection_screen.dart';

typedef ProfileRequest =
    Future<Map<String, dynamic>> Function(
      String path, {
      String method,
      Map<String, dynamic>? body,
    });

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.request, this.onPasswordReset});
  final VoidCallback? onPasswordReset;
  final ProfileRequest request;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  List _purchases = [];
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await widget.request('profile');
      final history = await widget.request('purchases');
      if (mounted) {
        setState(() {
          _profile = profile;
          _purchases = history['purchases'] as List;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Impossible de charger ton profil. Réessaie ou reconnecte-toi.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changePassword() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PasswordResetScreen(
          request: widget.request,
          identifier: _profile?['nickname'] as String? ?? '',
        ),
      ),
    );
    if (changed == true && mounted) {
      widget.onPasswordReset?.call();
      Navigator.pop(context);
    }
  }

  Future<void> _deleteAccount() async {
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _AccountDeletionScreen(
          request: widget.request,
          email: _profile?['email'] as String? ?? '',
        ),
      ),
    );
    if (deleted == true && mounted) {
      widget.onPasswordReset?.call();
      Navigator.pop(context);
    }
  }

  String _date(num value) {
    final date = DateTime.fromMillisecondsSinceEpoch(
      (value * 1000).round(),
    ).toLocal();
    final locale = MaterialLocalizations.of(context);
    return '${locale.formatShortDate(date)} · ${locale.formatTimeOfDay(TimeOfDay.fromDateTime(date))}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Mon profil'),
      actions: [
        IconButton(
          tooltip: 'Actualiser',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (_loading) const LinearProgressIndicator(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (_profile != null) ...[
          const Icon(Icons.account_circle_outlined, size: 72),
          const SizedBox(height: 12),
          Text(
            _profile!['nickname'] as String,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          if (_profile!['verified'] == true)
            const Center(
              child: Chip(
                avatar: Icon(Icons.verified, size: 18),
                label: Text('Administrateur certifié'),
              ),
            ),
          const SizedBox(height: 20),
          if (_profile!['id'] is int) const ProfileSocialCard(),
          ListTile(
            leading: const Icon(Icons.collections_bookmark_outlined),
            title: const Text('Ma collection de cartes'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const CollectionScreen()),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'État du compte',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _profile!['account_state'] == 'chat_restricted'
                        ? 'Chat temporairement restreint'
                        : 'Compte actif',
                  ),
                  if (_profile!['restriction_ends_at'] is num)
                    Text(
                      'Fin de restriction : ${_date(_profile!['restriction_ends_at'] as num)}',
                    ),
                  if ((_profile!['warning_streak'] as num? ?? 0) > 0)
                    Text(
                      'Avertissements consécutifs : ${_profile!['warning_streak']}/3',
                    ),
                  if (_profile!['account_state'] == 'chat_restricted')
                    const Text(
                      'Tu peux lire les échanges et contacter le support privé.',
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Adresse email', style: Theme.of(context).textTheme.titleLarge),
          Text(_profile!['email'] as String? ?? ''),
          const Text('Adresse vérifiée par email'),
          const SizedBox(height: 16),
          const Text(
            'Tout changement de mot de passe demande un nouveau code reçu par email.',
          ),
          FilledButton.icon(
            onPressed: _changePassword,
            icon: const Icon(Icons.lock_reset),
            label: const Text('Changer mon mot de passe par email'),
          ),
          const SizedBox(height: 28),
          Text(
            'Historique de mes achats',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (_purchases.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Aucun achat pour le moment. Les achats sont actuellement indisponibles.',
              ),
            ),
          for (final purchase in _purchases)
            Card(
              child: ListTile(
                title: Text(purchase['title'] as String),
                subtitle: Text(
                  '${_date(purchase['purchased_at'] as num)}\n${purchase['status'] == 'refunded'
                      ? 'Remboursé'
                      : purchase['status'] == 'paid'
                      ? 'Confirmé'
                      : purchase['status'] == 'free'
                      ? 'Ajout gratuit à la collection'
                      : 'En attente'}',
                ),
                trailing: Text(
                  '${((purchase['amount_minor'] as num) / (purchase['currency'] == 'XOF' ? 1 : 100)).toStringAsFixed(purchase['currency'] == 'XOF' ? 0 : 2)} ${purchase['currency']}',
                ),
              ),
            ),
          const SizedBox(height: 28),
          const Divider(),
          TextButton.icon(
            onPressed: _deleteAccount,
            icon: const Icon(Icons.person_remove_outlined),
            label: const Text('Supprimer mon compte et mes données'),
          ),
        ],
      ],
    ),
  );
}

class _AccountDeletionScreen extends StatefulWidget {
  const _AccountDeletionScreen({required this.request, required this.email});
  final ProfileRequest request;
  final String email;
  @override
  State<_AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<_AccountDeletionScreen> {
  final _code = TextEditingController();
  String? _challenge, _message;
  bool _busy = false, _confirmed = false;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (_challenge == null) {
        final result = await widget.request(
          'account-deletion/request',
          method: 'POST',
          body: {'email': widget.email},
        );
        if (mounted) {
          setState(() {
            _challenge = result['challenge_id'] as String;
            _message = result['message'] as String;
          });
        }
      } else {
        if (!_confirmed || !RegExp(r'^\d{6}$').hasMatch(_code.text.trim())) {
          throw StateError(
            'Saisis les six chiffres et confirme la suppression.',
          );
        }
        await widget.request(
          'account-deletion/confirm',
          method: 'POST',
          body: {
            'challenge_id': _challenge,
            'code': _code.text.trim(),
            'confirm': true,
          },
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ton compte et ses données ont été supprimés.'),
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _message = error.toString().replaceFirst('Bad state: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Supprimer mon compte')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(Icons.person_remove_outlined, size: 64),
        const SizedBox(height: 20),
        const Text(
          'Cette action est définitive : ton compte, tes messages de communauté, tes demandes de support et ton historique d’achats seront effacés de la base active. Toutes tes sessions seront fermées.',
        ),
        const SizedBox(height: 12),
        const Text(
          'Les parties en cours ont une session distincte : quitte-les séparément. Les copies des autres joueurs, journaux techniques et sauvegardes éventuelles ne sont pas supprimés par ce formulaire.',
        ),
        const SizedBox(height: 16),
        Text('Adresse du compte : ${widget.email}'),
        if (_challenge != null) ...[
          const SizedBox(height: 20),
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            maxLength: 6,
            autofillHints: const [AutofillHints.oneTimeCode],
            decoration: const InputDecoration(labelText: 'Code reçu par email'),
          ),
          CheckboxListTile(
            value: _confirmed,
            onChanged: _busy
                ? null
                : (value) => setState(() => _confirmed = value ?? false),
            title: const Text(
              'Je confirme la suppression définitive de mon compte et de ses données.',
            ),
          ),
        ],
        if (_message != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(_message!),
          ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(
            _busy
                ? 'Veuillez patienter…'
                : _challenge == null
                ? 'Recevoir un code de suppression'
                : 'Supprimer définitivement mon compte',
          ),
        ),
        if (_challenge != null)
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() {
                    _challenge = null;
                    _code.clear();
                    _confirmed = false;
                    _message = null;
                  }),
            child: const Text('Demander un nouveau code'),
          ),
      ],
    ),
  );
}
