import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Shows PRIVACY.md, the same text published for the stores.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: FutureBuilder<String>(
        future: rootBundle.loadString('PRIVACY.md'),
        builder: (context, snapshot) {
          final text = snapshot.data;
          if (text == null) return const Center(child: CircularProgressIndicator());
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final block in text.split(RegExp(r'\n\s*\n')))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: block.startsWith('#')
                      ? Text(
                          block.replaceFirst(RegExp(r'^#+\s*'), ''),
                          style: textTheme.titleMedium,
                        )
                      : SelectableText(block.trim()),
                ),
            ],
          );
        },
      ),
    );
  }
}
