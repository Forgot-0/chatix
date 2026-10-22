import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/settings/data/models/privacy_settings_model.dart';
import 'package:chatix/features/settings/data/repositories/privacy_repository_impl.dart';
import 'package:chatix/features/settings/domain/entities/privacy_settings.dart';
import 'package:chatix/features/settings/domain/usecases/update_privacy_settings_use_case.dart';
import 'package:chatix/features/settings/presentation/providers/privacy_settings_provider.dart';
import 'package:chatix/features/settings/presentation/utils/privacy_labels.dart';
import 'package:chatix/gen/l10n/app_localizations_ru.dart';

import '../../helpers/privacy_harness.dart';

class _Auth extends AuthController {
  @override
  Future<UserEntity?> build() async =>
      const UserEntity(id: 7, username: 'maria', email: 'm@example.com');
}

const _allow = PrivacyExceptionKind.allow;
const _deny = PrivacyExceptionKind.deny;

void main() {
  final ru = AppLocalizationsRu();

  group('PrivacyRule', () {
    test('wire names and route slugs both read back', () {
      for (final rule in PrivacyRule.values) {
        expect(PrivacyRule.fromWire(rule.wire), rule);
        expect(PrivacyRule.fromSlug(rule.slug), rule);
      }
      expect(PrivacyRule.lastSeen.wire, 'last_seen');
      expect(PrivacyRule.groupInvites.slug, 'group-invites');
      // `blocked` and `devices` share the path segment; they are not rules.
      expect(PrivacyRule.fromSlug('blocked'), isNull);
      expect(PrivacyRule.fromSlug('devices'), isNull);
    });
  });

  group('which lists an answer offers', () {
    test('everybody: only "never"; nobody: only "always"; contacts: both', () {
      expect(PrivacyVisibility.everybody.offers(_deny), isTrue);
      expect(PrivacyVisibility.everybody.offers(_allow), isFalse);
      expect(PrivacyVisibility.nobody.offers(_allow), isTrue);
      expect(PrivacyVisibility.nobody.offers(_deny), isFalse);
      expect(PrivacyVisibility.contacts.offers(_allow), isTrue);
      expect(PrivacyVisibility.contacts.offers(_deny), isTrue);
    });
  });

  group('PrivacyExceptions', () {
    const lists = PrivacyExceptions(allow: [1, 2], deny: [3]);

    test('putting somebody on one list takes them off the other', () {
      final next = lists.withList(_deny, [3, 2]);
      expect(next.deny, [3, 2]);
      expect(next.allow, [1]);
    });

    test('a repeated id is kept once, in the order it first came', () {
      expect(lists.withList(_allow, [5, 5, 1]).allow, [5, 1]);
    });

    test('without() takes one person off one list', () {
      expect(
        lists.without(_allow, 1),
        const PrivacyExceptions(allow: [2], deny: [3]),
      );
      expect(lists.without(_deny, 99), lists);
    });

    test('room is what the other list leaves of the hundred', () {
      expect(lists.roomFor(_allow), PrivacyExceptions.limit - 1);
      expect(lists.roomFor(_deny), PrivacyExceptions.limit - 2);
    });
  });

  group('PrivacySettingsModel', () {
    test('reads the DTO', () {
      final settings = PrivacySettingsModel.fromJson({
        'rules': {
          'last_seen': 'contacts',
          'photo': 'nobody',
          'messages': 'everybody',
          'group_invites': 'contacts',
          'calls': 'nobody',
        },
        'exceptions': {
          'last_seen': {
            'allow': [],
            'deny': [5, 6],
          },
          'calls': {
            'allow': [9],
            'deny': [],
          },
        },
      });

      expect(
        settings.visibilityOf(PrivacyRule.lastSeen),
        PrivacyVisibility.contacts,
      );
      expect(
        settings.visibilityOf(PrivacyRule.photo),
        PrivacyVisibility.nobody,
      );
      expect(settings.exceptionsOf(PrivacyRule.lastSeen).deny, [5, 6]);
      expect(settings.exceptionsOf(PrivacyRule.calls).allow, [9]);
      expect(settings.exceptionsOf(PrivacyRule.photo), PrivacyExceptions.none);
    });

    test('a rule or a value it does not know costs nothing else', () {
      final settings = PrivacySettingsModel.fromJson({
        'rules': {'photo': 'nobody', 'stories': 'nobody', 'calls': 'friends'},
        'exceptions': {
          'stories': {
            'allow': [1],
          },
          'photo': 'oops',
        },
      });

      expect(
        settings.visibilityOf(PrivacyRule.photo),
        PrivacyVisibility.nobody,
      );
      // An unknown answer reads as the default.
      expect(
        settings.visibilityOf(PrivacyRule.calls),
        PrivacyVisibility.everybody,
      );
      expect(settings.exceptionsOf(PrivacyRule.photo), PrivacyExceptions.none);
    });

    test('the defaults are what an untouched account gets', () {
      final settings = PrivacySettingsModel.fromJson({
        'rules': {
          for (final rule in PrivacyRule.values) rule.wire: 'everybody',
        },
        'exceptions': {
          for (final rule in PrivacyRule.values)
            rule.wire: {'allow': [], 'deny': []},
        },
      });
      expect(settings, PrivacySettings.defaults);
    });

    test('an update carries only what changes, each list whole', () {
      expect(
        PrivacySettingsModel.updateJson(
          rules: {PrivacyRule.photo: PrivacyVisibility.contacts},
        ),
        {
          'rules': {'photo': 'contacts'},
        },
      );
      expect(
        PrivacySettingsModel.updateJson(
          exceptions: {
            PrivacyRule.calls: const PrivacyExceptions(allow: [9], deny: []),
          },
        ),
        {
          'exceptions': {
            'calls': {
              'allow': [9],
              'deny': <int>[],
            },
          },
        },
      );
    });
  });

  group('UpdatePrivacySettingsUseCase', () {
    test('an empty change never leaves the device', () async {
      final repository = FakePrivacyRepository();
      final result = await UpdatePrivacySettingsUseCase(repository).execute();

      expect(result.getLeft().toNullable(), isA<InputFailure>());
      expect(repository.updates, isEmpty);
    });

    test('a rule over the hundred is refused before the server is', () async {
      final repository = FakePrivacyRepository();
      final result = await UpdatePrivacySettingsUseCase(repository).execute(
        exceptions: {
          PrivacyRule.messages: PrivacyExceptions(
            allow: [for (var i = 1; i <= 60; i++) i],
            deny: [for (var i = 61; i <= 101; i++) i],
          ),
        },
      );

      expect(result.getLeft().toNullable(), isA<InputFailure>());
      expect(repository.updates, isEmpty);
    });
  });

  group('the summary on a rule row', () {
    test('the answer alone when nothing is excepted', () {
      expect(
        privacyValueSummary(
          ru,
          PrivacyVisibility.everybody,
          PrivacyExceptions.none,
        ),
        ru.privacyEverybody,
      );
    });

    test('Telegram\'s shorthand: taken out, then let in', () {
      expect(
        privacyValueSummary(
          ru,
          PrivacyVisibility.contacts,
          const PrivacyExceptions(allow: [1], deny: [2, 3]),
        ),
        'Мои контакты (−2, +1)',
      );
    });

    test('a list the answer makes meaningless is not counted', () {
      expect(
        privacyValueSummary(
          ru,
          PrivacyVisibility.everybody,
          const PrivacyExceptions(allow: [1, 2], deny: []),
        ),
        ru.privacyEverybody,
      );
      expect(
        privacyValueSummary(
          ru,
          PrivacyVisibility.nobody,
          const PrivacyExceptions(allow: [1], deny: [2]),
        ),
        'Никто (+1)',
      );
    });
  });

  group('PrivacySettingsController', () {
    late FakePrivacyRepository repository;
    late ProviderContainer container;

    setUp(() {
      repository = FakePrivacyRepository(
        const PrivacySettings(
          rules: {PrivacyRule.photo: PrivacyVisibility.contacts},
        ),
      );
      container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          authProvider.overrideWith(_Auth.new),
          privacyRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      // autoDispose: keep it alive for the test.
      container.listen(privacySettingsProvider, (_, _) {});
    });

    test('reads the settings for the signed-in account', () async {
      final settings = await container.read(privacySettingsProvider.future);
      expect(
        settings.visibilityOf(PrivacyRule.photo),
        PrivacyVisibility.contacts,
      );
    });

    test('a change shows at once and is sent as one rule', () async {
      await container.read(privacySettingsProvider.future);
      final controller = container.read(privacySettingsProvider.notifier);

      final pending = controller.setVisibility(
        PrivacyRule.calls,
        PrivacyVisibility.nobody,
      );
      expect(
        container
            .read(privacySettingsProvider)
            .value!
            .visibilityOf(PrivacyRule.calls),
        PrivacyVisibility.nobody,
      );

      expect(await pending, isNull);
      expect(repository.updates.single.rules, {
        PrivacyRule.calls: PrivacyVisibility.nobody,
      });
      expect(repository.updates.single.exceptions, isEmpty);
    });

    test('the same answer again sends nothing', () async {
      await container.read(privacySettingsProvider.future);
      await container
          .read(privacySettingsProvider.notifier)
          .setVisibility(PrivacyRule.photo, PrivacyVisibility.contacts);
      expect(repository.updates, isEmpty);
    });

    test('a refused change puts the old answer back and says why', () async {
      await container.read(privacySettingsProvider.future);
      const refusal = ApiFailure(
        code: 'PRIVACY_EXCEPTIONS_LIMIT',
        message: 'limit',
        detail: null,
        status: 400,
      );
      repository.failNext = refusal;

      final failure = await container
          .read(privacySettingsProvider.notifier)
          .setExceptions(
            PrivacyRule.photo,
            const PrivacyExceptions(allow: [1]),
          );

      expect(failure, refusal);
      expect(
        container
            .read(privacySettingsProvider)
            .value!
            .exceptionsOf(PrivacyRule.photo),
        PrivacyExceptions.none,
      );
    });
  });
}
