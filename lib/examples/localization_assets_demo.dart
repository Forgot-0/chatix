import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/core/localization/language_selector_widget.dart';
import 'package:chatix/core/localization/localized_asset_service.dart';
import 'package:chatix/core/providers/localization_providers.dart';
import 'package:chatix/l10n/l10n.dart';
import 'package:intl/intl.dart';

class LocalizationAssetsDemo extends ConsumerWidget {
  const LocalizationAssetsDemo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(persistentLocaleProvider);

    final l10n = AppLocalizations(locale);

    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('localization_assets_demo')),
        actions: const [
          LanguagePopupMenuButton(),
          SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('current_language'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${context.tr('language_code')}: ${locale.languageCode}',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${context.tr('language_name')}: ${getLanguageName(locale.languageCode)}',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('formatting_examples'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${context.tr('date_full')}: ${DateFormat.yMMMMEEEEd(locale.toString()).format(now)}',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${context.tr('date_short')}: ${DateFormat.yMd(locale.toString()).format(now)}',
                    ),
                    const SizedBox(height: 4),
                    Text('${context.tr('time')}: ${l10n.formatTime(now)}'),
                    const SizedBox(height: 4),
                    Text(
                      '${context.tr('currency')}: ${l10n.formatCurrency(1234.56)}',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${context.tr('percent')}: ${NumberFormat.percentPattern(locale.toString()).format(0.1234)}',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            Text(
              context.tr('localized_assets'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.tr('localized_assets_explanation'),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('image_example'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),

                    Center(
                      child: Column(
                        children: [
                          const LocalizedImage(
                            imageName: 'welcome.png',
                            width: 240,
                            height: 160,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.tr('welcome_image_caption'),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text(
                      context.tr('common_image_example'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),

                    Center(
                      child: Column(
                        children: [
                          const LocalizedImage(
                            imageName: 'logo.png',
                            useCommonPath: true,
                            width: 120,
                            height: 120,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.tr('common_image_caption'),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String getLanguageName(String languageCode) {
    switch (languageCode) {
      case 'en':
        return 'English';
      case 'es':
        return 'Español';
      case 'fr':
        return 'Français';
      case 'de':
        return 'Deutsch';
      case 'ja':
        return '日本語';
      case 'bn':
        return 'বাংলা';
      default:
        return languageCode;
    }
  }
}
