import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:local_host/local_host.dart';
import '../services/server_config.dart';
import 'official_content.dart';
import 'admin_dashboard.dart';
import 'profile_screen.dart';
import '../social/social_screens.dart';
import '../social/social_service.dart';
import 'password_reset_screen.dart';
import 'community_session.dart';
import '../stickers/chat_stickers.dart';
import '../design/action_spacing.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});
  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final _name = TextEditingController(), _password = TextEditingController();
  final _email = TextEditingController();
  final _message = TextEditingController(),
      _subject = TextEditingController(),
      _description = TextEditingController();
  final _http = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  final _base = onlineServerUri(apiBaseUrl);
  late final _sessions = CommunitySessionStore(_base.toString());
  DateTime? _expiresAt;
  Timer? _expiry;
  bool _restoring = true;
  String? _token, _nickname, _error;
  bool _isAdmin = false;
  double _mutedUntil = 0;
  bool _register = true, _busy = false, _refreshing = false;
  List<Map<String, dynamic>> _messages = [], _tickets = [];
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    unawaited(_restoreSession());
  }

  Future<void> _restoreSession() async {
    final session = await _sessions.load();
    if (!mounted) return;
    if (session != null) {
      setState(() {
        _token = session.token;
        _nickname = session.nickname;
        _expiresAt = session.expiresAt;
      });
      _scheduleSession();
      try {
        await _refresh();
      } catch (_) {
        if (mounted && _token != null) {
          setState(
            () => _error =
                'Connexion au service momentanément indisponible. Ta session est conservée ; tu peux actualiser.',
          );
        }
      }
      if (mounted && _token != null) _startPolling();
    }
    if (mounted) setState(() => _restoring = false);
  }

  void _scheduleSession() {
    _expiry?.cancel();
    final remaining = _expiresAt?.difference(DateTime.now());
    if (remaining != null) {
      _expiry = Timer(
        remaining.isNegative ? Duration.zero : remaining,
        _backToLogin,
      );
    }
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refresh(quiet: true),
    );
  }

  Future<Map<String, dynamic>> _request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    if (_token != null &&
        _expiresAt != null &&
        !DateTime.now().isBefore(_expiresAt!)) {
      _backToLogin();
      throw StateError('Ta session a expiré. Reconnecte-toi.');
    }
    final sentToken = _token;
    final request = await _http
        .openUrl(method, _base.resolve('community/$path'))
        .timeout(const Duration(seconds: 10));
    request.headers.contentType = ContentType.json;
    if (sentToken != null) {
      request.headers.set('Authorization', 'Bearer $sentToken');
    }
    if (body != null) request.write(jsonEncode(body));
    final response = await request.close().timeout(const Duration(seconds: 12));
    final text = await response
        .transform(utf8.decoder)
        .join()
        .timeout(const Duration(seconds: 12));
    final data = jsonDecode(text) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      if ((response.statusCode == 401 ||
              response.statusCode == 403 &&
                  ('${data['detail']}'.startsWith('Compte banni') ||
                      '${data['detail']}'.startsWith('Vérifie ton adresse'))) &&
          sentToken != null &&
          sentToken == _token) {
        _backToLogin();
      }
      throw StateError(
        data['detail'] is String
            ? data['detail'] as String
            : 'Vérifie les champs du formulaire.',
      );
    }
    return data;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is StateError
              ? error.message
              : 'Communauté momentanément inaccessible. Réessaie dans un instant.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _authenticate() => _run(() async {
    if (_name.text.trim().length < 2 || _password.text.length < 8) {
      throw StateError(
        _register
            ? 'Choisis un pseudo et un mot de passe de 8 caractères minimum.'
            : 'Saisis ton pseudo ou ton email et ton mot de passe.',
      );
    }
    final data = await _request(
      _register ? 'register' : 'login',
      method: 'POST',
      body: {
        'nickname': _name.text.trim(),
        'password': _password.text,
        if (_register) 'email': _email.text.trim(),
      },
    );
    if (!mounted) return;
    _password.clear();
    final maxExpiry = DateTime.now().add(
      (data['user'] as Map)['role'] == 'admin'
          ? communityAdminSessionLifetime
          : communityPlayerSessionLifetime,
    );
    final serverExpiry = data['expires_at'] is num
        ? DateTime.fromMillisecondsSinceEpoch(
            ((data['expires_at'] as num) * 1000).round(),
          )
        : maxExpiry;
    setState(() {
      _token = data['token'] as String;
      _nickname = (data['user'] as Map)['nickname'] as String;
      _expiresAt = serverExpiry.isBefore(maxExpiry) ? serverExpiry : maxExpiry;
      _isAdmin =
          (data['user'] as Map)['role'] == 'admin' &&
          (data['user'] as Map)['email_verified'] == true;
    });
    if (data['verification_required'] == true) {
      final verified = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => EmailVerificationScreen(
            request: _request,
            email: (data['user'] as Map)['email'] as String? ?? _email.text,
            challenge: data['challenge_id'] as String?,
          ),
        ),
      );
      if (verified != true) {
        _backToLogin();
        return;
      }
    }
    if (_token == null) return;
    await _sessions.save(
      CommunitySession(
        token: _token!,
        nickname: _nickname!,
        expiresAt: _expiresAt!,
      ),
    );
    if (!mounted) return;
    _scheduleSession();
    await _refresh();
    if (_token != null) _startPolling();
  });

  void _backToLogin() {
    _poll?.cancel();
    _expiry?.cancel();
    unawaited(_sessions.clear());
    if (mounted) {
      setState(() {
        _token = null;
        _expiresAt = null;
        _nickname = null;
        _isAdmin = false;
        _register = false;
        _password.clear();
        _messages = [];
        _tickets = [];
      });
    }
  }

  Future<void> _recovery() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PasswordResetScreen(
          request: _request,
          identifier: _name.text.trim(),
        ),
      ),
    );
    if (changed == true) _backToLogin();
  }

  Future<void> _refresh({bool quiet = false}) async {
    if (_token == null || _refreshing) return;
    final refreshingToken = _token;
    _refreshing = true;
    try {
      final profile = await _request('me');
      final chat = await _request('messages');
      final support = await _request('tickets');
      if (mounted && _token == refreshingToken) {
        setState(() {
          final user = profile['user'] as Map;
          _nickname = user['nickname'] as String;
          _isAdmin = user['role'] == 'admin';
          _mutedUntil = (user['muted_until'] as num? ?? 0).toDouble();
          _messages = (chat['messages'] as List)
              .map((m) => Map<String, dynamic>.from(m as Map))
              .toList();
          _tickets = (support['tickets'] as List)
              .map((m) => Map<String, dynamic>.from(m as Map))
              .toList();
        });
      }
    } catch (error) {
      if (!quiet) rethrow;
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _send() => _run(() async {
    if (_message.text.trim().isEmpty) return;
    await _request(
      'messages',
      method: 'POST',
      body: {'text': _message.text.trim()},
    );
    _message.clear();
    await _refresh();
  });
  Future<void> _sendSticker() async {
    final sticker = await showStickerPicker(context);
    if (!mounted ||
        sticker == null ||
        _busy ||
        _token == null ||
        _mutedUntil > DateTime.now().millisecondsSinceEpoch / 1000) {
      return;
    }
    await _run(() async {
      await _request(
        'messages',
        method: 'POST',
        body: {'text': stickerMessage(sticker)},
      );
      await _refresh();
    });
  }

  Future<void> _createTicket() => _run(() async {
    if (_subject.text.trim().isEmpty || _description.text.trim().isEmpty) {
      throw StateError('Indique le sujet et décris ton problème.');
    }
    await _request(
      'tickets',
      method: 'POST',
      body: {'subject': _subject.text.trim(), 'text': _description.text.trim()},
    );
    _subject.clear();
    _description.clear();
    await _refresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Demande envoyée au support. Réponse visée sous 48 h.'),
        ),
      );
    }
  });

  Future<void> _openTicket(int id) => _run(() async {
    final ticket = await _request('tickets/$id');
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _TicketScreen(ticket: ticket, request: _request),
      ),
    );
    await _refresh();
  });

  @override
  void dispose() {
    _email.dispose();
    _poll?.cancel();
    _expiry?.cancel();
    _http.close(force: true);
    for (final field in [_name, _password, _message, _subject, _description]) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 4,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Communauté'),
        actions: [
          if (_token != null)
            IconButton(
              tooltip: 'Mon profil',
              icon: ListenableBuilder(
                listenable: SocialService.instance,
                builder: (context, _) => Badge(
                  isLabelVisible: SocialService.instance.friendRequests > 0,
                  label: Text('${SocialService.instance.friendRequests}'),
                  child: const Icon(Icons.account_circle_outlined),
                ),
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ProfileScreen(
                    request: _request,
                    onPasswordReset: _backToLogin,
                  ),
                ),
              ),
            ),
          if (_token != null && _isAdmin)
            IconButton(
              tooltip: 'Dashboard administrateur',
              icon: const Icon(Icons.admin_panel_settings),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AdminDashboard(request: _request),
                ),
              ),
            ),
          if (_token != null)
            IconButton(
              tooltip: 'Actualiser',
              onPressed: _busy ? null : () => _run(_refresh),
              icon: const Icon(Icons.refresh),
            ),
          if (_token != null)
            IconButton(
              tooltip: 'Se déconnecter',
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                      try {
                        unawaited(SocialService.instance.logout());
                        await _request('logout', method: 'POST');
                      } finally {
                        _backToLogin();
                      }
                    }),
              icon: const Icon(Icons.logout),
            ),
        ],
        bottom: _token == null
            ? null
            : const TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: 'Discussion', icon: Icon(Icons.forum_outlined)),
                  Tab(text: 'Support privé', icon: Icon(Icons.support_agent)),
                  Tab(text: 'Annonces', icon: Icon(Icons.campaign_outlined)),
                  Tab(text: 'FAQ', icon: Icon(Icons.help_outline)),
                ],
              ),
      ),
      body: Column(
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_busy || _restoring) const LinearProgressIndicator(),
          Expanded(
            child: _restoring
                ? const Center(child: Text('Restauration de ta connexion…'))
                : _token == null
                ? _authForm()
                : TabBarView(
                    children: [
                      _chat(),
                      _support(),
                      const OfficialContentPage(faq: false),
                      const OfficialContentPage(faq: true),
                    ],
                  ),
          ),
        ],
      ),
    ),
  );

  Widget _authForm() => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(24),
        children: spaceGameActions([
          const Icon(Icons.groups_outlined, size: 56),
          const SizedBox(height: 16),
          Text(
            'Le village se retrouve ici',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const Text(
            'Discute, partage tes idées et pose tes questions. Crée ton compte avec ton pseudo, ton email et un mot de passe.',
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _name,
            maxLength: _register ? 24 : 254,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: _register
                  ? 'Pseudo de la communauté'
                  : 'Pseudo ou email',
            ),
          ),
          TextField(
            controller: _password,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            maxLength: 128,
            decoration: const InputDecoration(
              labelText: 'Mot de passe',
              helperText: '8 caractères minimum',
            ),
          ),
          if (_register)
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              maxLength: 254,
              decoration: const InputDecoration(
                labelText: 'Adresse email',
                helperText: 'Un code de vérification sera envoyé.',
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _authenticate,
            child: Text(_register ? 'Créer mon compte' : 'Me connecter'),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() => _register = !_register),
            child: Text(_register ? 'J’ai déjà un compte' : 'Créer un compte'),
          ),
          if (!_register)
            TextButton(
              onPressed: _busy ? null : _recovery,
              child: const Text('Mot de passe oublié ?'),
            ),
          const SizedBox(height: 12),
          const Text(
            'Les discussions sont publiques. Pour ton problème personnel, utilise le support privé. Ne partage jamais de mot de passe.',
          ),
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    const OfficialContentPage(faq: true, standalone: true),
              ),
            ),
            icon: const Icon(Icons.help_outline),
            label: const Text('Consulter la FAQ'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    const OfficialContentPage(faq: false, standalone: true),
              ),
            ),
            icon: const Icon(Icons.campaign_outlined),
            label: const Text('Lire les annonces officielles'),
          ),
        ]),
      ),
    ),
  );

  Widget _chat() => Column(
    children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Text(
          'Évite les insultes et les termes sexuels. Après 3 avertissements consécutifs : chat restreint pendant 3 h.',
          style: TextStyle(fontSize: 12),
        ),
      ),
      if (_mutedUntil > DateTime.now().millisecondsSinceEpoch / 1000)
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'Chat temporairement restreint. Tu peux lire les échanges et contacter le support privé.',
          ),
        ),
      Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'Bienvenue $_nickname${_isAdmin ? ' · Administrateur certifié' : ''} · Questions, entraide et partages',
        ),
      ),
      Expanded(
        child: _messages.isEmpty
            ? const Center(child: Text('Ouvre la discussion avec le village.'))
            : ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(12),
                itemCount: _messages.length,
                itemBuilder: (context, i) {
                  final m = _messages[_messages.length - 1 - i];
                  return Card(
                    child: ListTile(
                      title: Row(
                        children: [
                          Flexible(
                            child: InkWell(
                              onTap: m['user_id'] is int
                                  ? () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => SocialProfileScreen(
                                          userId: m['user_id'] as int,
                                        ),
                                      ),
                                    )
                                  : null,
                              child: Text(m['nickname'] as String),
                            ),
                          ),
                          if (m['role'] == 'admin')
                            const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Tooltip(
                                message: 'Administrateur certifié',
                                child: Icon(Icons.verified, size: 18),
                              ),
                            ),
                        ],
                      ),
                      subtitle: ChatMessageBody(
                        text: m['text'] as String,
                        selectable: true,
                      ),
                      trailing: IconButton(
                        tooltip: 'Signaler ce message',
                        icon: const Icon(Icons.flag_outlined, size: 18),
                        onPressed: _busy
                            ? null
                            : () => _run(() async {
                                await _request(
                                  'messages/${m['id']}/report',
                                  method: 'POST',
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Signalement transmis.'),
                                    ),
                                  );
                                }
                              }),
                      ),
                    ),
                  );
                },
              ),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Stickers',
                onPressed:
                    _busy ||
                        _mutedUntil >
                            DateTime.now().millisecondsSinceEpoch / 1000
                    ? null
                    : _sendSticker,
                icon: const Icon(Icons.emoji_emotions_outlined),
              ),
              Expanded(
                child: TextField(
                  controller: _message,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: 'Ton message au village',
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Envoyer',
                onPressed:
                    _busy ||
                        _mutedUntil >
                            DateTime.now().millisecondsSinceEpoch / 1000
                    ? null
                    : _send,
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _support() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text('Nous contacter', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      const Text(
        'Échange privé avec le support du jeu. Réponse visée sous 48 h. Tu retrouveras la réponse dans cette rubrique.',
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _subject,
        maxLength: 100,
        decoration: const InputDecoration(labelText: 'Sujet du problème'),
      ),
      TextField(
        controller: _description,
        minLines: 3,
        maxLines: 7,
        maxLength: 4000,
        decoration: const InputDecoration(
          labelText: 'Que s’est-il passé ?',
          helperText:
              'Précise ton appareil et les étapes pour reproduire le problème.',
        ),
      ),
      FilledButton.icon(
        onPressed: _busy ? null : _createTicket,
        icon: const Icon(Icons.support_agent),
        label: const Text('Envoyer au support'),
      ),
      const SizedBox(height: 24),
      Text('Mes demandes', style: Theme.of(context).textTheme.titleLarge),
      if (_tickets.isEmpty)
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text('Aucune demande pour le moment.'),
        ),
      for (final ticket in _tickets)
        Card(
          child: ListTile(
            title: Text(ticket['subject'] as String),
            subtitle: Text(
              ticket['status'] == 'answered'
                  ? 'Réponse du support disponible'
                  : 'En attente de réponse',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _busy ? null : () => _openTicket(ticket['id'] as int),
          ),
        ),
    ],
  );
}

typedef _Request =
    Future<Map<String, dynamic>> Function(
      String path, {
      String method,
      Map<String, dynamic>? body,
    });

class _TicketScreen extends StatefulWidget {
  const _TicketScreen({required this.ticket, required this.request});
  final Map<String, dynamic> ticket;
  final _Request request;
  @override
  State<_TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends State<_TicketScreen> {
  late Map<String, dynamic> _ticket = widget.ticket;
  final _text = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _load({bool send = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (send) {
        if (_text.text.trim().isEmpty) return;
        await widget.request(
          'tickets/${_ticket['id']}/reply',
          method: 'POST',
          body: {'text': _text.text.trim()},
        );
        _text.clear();
      }
      final ticket = await widget.request('tickets/${_ticket['id']}');
      if (mounted) setState(() => _ticket = ticket);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Impossible de charger la demande. Réessaie.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_ticket['subject'] as String),
      actions: [
        IconButton(
          tooltip: 'Actualiser',
          onPressed: _busy ? null : () => _load(),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text('Conversation privée · Réponse visée sous 48 h'),
        ),
        if (_error != null) Text(_error!),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (final m in _ticket['messages'] as List)
                Card(
                  child: ListTile(
                    title: Text(
                      m['author'] == 'support' ? 'Support · Mordeviel' : 'Toi',
                    ),
                    subtitle: SelectableText(m['text'] as String),
                  ),
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                      labelText: 'Compléter ma demande',
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _busy ? null : () => _load(send: true),
                  icon: const Icon(Icons.send),
                  tooltip: 'Envoyer au support',
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
