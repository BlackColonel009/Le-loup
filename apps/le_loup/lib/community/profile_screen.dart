import 'package:flutter/material.dart';
import 'password_reset_screen.dart';

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
                      : 'En attente'}',
                ),
                trailing: Text(
                  '${((purchase['amount_minor'] as num) / (purchase['currency'] == 'XOF' ? 1 : 100)).toStringAsFixed(purchase['currency'] == 'XOF' ? 0 : 2)} ${purchase['currency']}',
                ),
              ),
            ),
        ],
      ],
    ),
  );
}
