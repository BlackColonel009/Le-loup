import 'package:flutter/material.dart';

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Communauté')),
    body: const Center(
      child: Text(
        'La communauté est disponible dans l’application Android, iOS et Windows.',
      ),
    ),
  );
}
