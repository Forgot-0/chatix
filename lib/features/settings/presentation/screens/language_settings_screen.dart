import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/core/localization/language_selector_widget.dart';
import 'package:chatix/l10n/l10n.dart';

class LanguageSettingsScreen extends ConsumerWidget {
  const LanguageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('language_settings'))),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                context.tr('select_your_language'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),

            const Expanded(child: Card(child: LanguageSelectorWidget())),

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                context.tr('language_explanation'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
