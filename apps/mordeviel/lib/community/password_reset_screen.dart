import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef RecoveryRequest =
    Future<Map<String, dynamic>> Function(
      String path, {
      String method,
      Map<String, dynamic>? body,
    });

class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({
    super.key,
    required this.request,
    this.identifier = '',
  });
  final RecoveryRequest request;
  final String identifier;
  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  late final _identifier = TextEditingController(text: widget.identifier);
  final _code = TextEditingController(),
      _password = TextEditingController(),
      _confirm = TextEditingController();
  String? _challenge, _error, _message;
  bool _busy = false;
  @override
  void dispose() {
    for (final c in [_identifier, _code, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _requestCode() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await widget.request(
        'password/request',
        method: 'POST',
        body: {'identifier': _identifier.text.trim()},
      );
      if (mounted) {
        setState(() {
          _challenge = response['challenge_id'] as String;
          _message = response['message'] as String;
          _code.clear();
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is StateError
              ? error.message
              : 'Impossible d’envoyer le code pour le moment.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (_busy || _challenge == null) return;
    if (_code.text.length != 6 ||
        _password.text.length < 8 ||
        _password.text != _confirm.text) {
      setState(
        () => _error =
            'Vérifie le code et les deux mots de passe identiques (8 caractères minimum).',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await widget.request(
        'password/confirm',
        method: 'POST',
        body: {
          'challenge_id': _challenge,
          'code': _code.text,
          'new_password': _password.text,
          'confirm_password': _confirm.text,
        },
      );
      if (!mounted) return;
      _password.clear();
      _confirm.clear();
      _code.clear();
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Mot de passe modifié'),
          content: Text(response['message'] as String),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Me connecter'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is StateError
              ? error.message
              : 'Modification impossible. Réessaie.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Récupérer mon compte')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(Icons.mark_email_read_outlined, size: 56),
        const SizedBox(height: 16),
        const Text(
          'La vérification par email est obligatoire pour tous les comptes, administrateurs compris.',
        ),
        TextField(
          controller: _identifier,
          maxLength: 254,
          decoration: const InputDecoration(labelText: 'Pseudo ou email'),
        ),
        FilledButton.icon(
          onPressed: _busy ? null : _requestCode,
          icon: const Icon(Icons.email_outlined),
          label: Text(
            _challenge == null
                ? 'Recevoir un code par email'
                : 'Recevoir un nouveau code',
          ),
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          Padding(padding: const EdgeInsets.all(12), child: Text(_error!)),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(_message!),
          ),
        if (_challenge != null) ...[
          const Text(
            'Le code expire après 10 minutes. Ne le partage avec personne.',
          ),
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Code reçu par email'),
          ),
          TextField(
            controller: _password,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            maxLength: 128,
            decoration: const InputDecoration(
              labelText: 'Nouveau mot de passe',
              helperText: '8 caractères minimum',
            ),
          ),
          TextField(
            controller: _confirm,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            maxLength: 128,
            decoration: const InputDecoration(
              labelText: 'Confirmer le nouveau mot de passe',
            ),
          ),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: const Text('Changer mon mot de passe'),
          ),
        ],
      ],
    ),
  );
}

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({
    super.key,
    required this.request,
    this.email = '',
    this.challenge,
  });
  final RecoveryRequest request;
  final String email;
  final String? challenge;
  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  late final _email = TextEditingController(text: widget.email);
  final _code = TextEditingController();
  late String? _challenge = widget.challenge;
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _act(bool verify) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (verify) {
        if (_challenge == null) {
          throw StateError('Demande d’abord un code de vérification.');
        }
        await widget.request(
          'email/verify',
          method: 'POST',
          body: {'challenge_id': _challenge, 'code': _code.text},
        );
        if (mounted) Navigator.pop(context, true);
      } else {
        final result = await widget.request(
          'email/request',
          method: 'POST',
          body: {'email': _email.text.trim()},
        );
        if (mounted) {
          setState(() => _challenge = result['challenge_id'] as String);
        }
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is StateError
              ? error.message
              : 'Vérification impossible. Réessaie.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Vérifier mon email')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(Icons.mark_email_read_outlined, size: 56),
        const SizedBox(height: 16),
        const Text(
          'Tous les comptes doivent confirmer leur adresse email avant d’accéder à la communauté.',
        ),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'Adresse email'),
        ),
        OutlinedButton(
          onPressed: _busy ? null : () => _act(false),
          child: const Text('Envoyer un code à cette adresse'),
        ),
        if (_challenge != null)
          const Text('Un code a été envoyé. Il est valable 10 minutes.'),
        TextField(
          controller: _code,
          maxLength: 6,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'Code reçu par email'),
        ),
        if (_error != null) Text(_error!),
        FilledButton(
          onPressed: _busy ? null : () => _act(true),
          child: const Text('Vérifier mon adresse email'),
        ),
      ],
    ),
  );
}
