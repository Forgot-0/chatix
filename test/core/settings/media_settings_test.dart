import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/settings/media_settings.dart';

/// Auto-download is set per attachment kind because the cost of each is
/// wildly different — a voice message is small enough that waiting for it is
/// pure friction, a 90 MB video on mobile data is not.
void main() {
  group('the defaults', () {
    test('spend nothing on mobile data without being asked', () {
      const settings = MediaSettings();

      expect(settings.policyFor(MediaKind.photo), MediaAutoDownload.wifiOnly);
      expect(settings.policyFor(MediaKind.video), MediaAutoDownload.wifiOnly);
      expect(settings.policyFor(MediaKind.file), MediaAutoDownload.never);
      expect(settings.policyFor(MediaKind.voice), MediaAutoDownload.always);
    });

    test('are not written down, so they can be retuned later', () {
      const settings = MediaSettings();

      expect(settings.toJson()['autoDownload'], isEmpty);
    });
  });

  group('whether a file may be fetched now', () {
    test('"mobile data" does not care what the connection is', () {
      expect(MediaAutoDownload.always.allowsOn(unmetered: false), isTrue);
      expect(MediaAutoDownload.always.allowsOn(unmetered: true), isTrue);
    });

    test('"never" does not either', () {
      expect(MediaAutoDownload.never.allowsOn(unmetered: true), isFalse);
    });

    test('"Wi-Fi" waits for one that is not charged by the megabyte', () {
      expect(MediaAutoDownload.wifiOnly.allowsOn(unmetered: true), isTrue);
      expect(MediaAutoDownload.wifiOnly.allowsOn(unmetered: false), isFalse);
    });
  });

  group('storage', () {
    test('a policy survives the round trip', () {
      const before = MediaSettings();
      final after = MediaSettings.fromJson(
        before
            .withPolicy(MediaKind.video, MediaAutoDownload.never)
            .withPolicy(MediaKind.file, MediaAutoDownload.always)
            .toJson(),
      );

      expect(after.policyFor(MediaKind.video), MediaAutoDownload.never);
      expect(after.policyFor(MediaKind.file), MediaAutoDownload.always);
      // Untouched kinds stay on their own defaults.
      expect(after.policyFor(MediaKind.photo), MediaAutoDownload.wifiOnly);
    });

    test('setting one kind leaves the others alone', () {
      const before = MediaSettings();
      final after = before.withPolicy(MediaKind.photo, MediaAutoDownload.never);

      expect(after.policyFor(MediaKind.photo), MediaAutoDownload.never);
      expect(after.policyFor(MediaKind.video), MediaAutoDownload.wifiOnly);
    });

    test('a stored value nobody recognises falls back to the default', () {
      final settings = MediaSettings.fromJson(<String, Object?>{
        'autoDownload': <String, Object?>{'photo': 'whenever-i-feel-like-it'},
      });

      expect(settings.policyFor(MediaKind.photo), MediaAutoDownload.wifiOnly);
    });

    test('a shape nobody recognises does not throw', () {
      final settings = MediaSettings.fromJson(<String, Object?>{
        'autoDownload': 'not a map',
        'cacheLimitBytes': 'not a number',
      });

      expect(settings.policyFor(MediaKind.photo), MediaAutoDownload.wifiOnly);
      expect(settings.cacheLimitBytes, MediaSettings.defaultCacheLimitBytes);
    });

    test('the cache limit survives the round trip', () {
      final limit = MediaSettings.cacheLimitSteps.last;
      final after = MediaSettings.fromJson(
        const MediaSettings().copyWith(cacheLimitBytes: limit).toJson(),
      );

      expect(after.cacheLimitBytes, limit);
    });
  });

  group('equality', () {
    test('an explicit default equals an absent one', () {
      const implicit = MediaSettings();
      final explicit = implicit.withPolicy(
        MediaKind.photo,
        MediaAutoDownload.wifiOnly,
      );

      expect(explicit, implicit);
      expect(explicit.hashCode, implicit.hashCode);
    });

    test('a real change is not equal', () {
      const implicit = MediaSettings();

      expect(
        implicit.withPolicy(MediaKind.photo, MediaAutoDownload.never),
        isNot(implicit),
      );
      expect(
        implicit.copyWith(cacheLimitBytes: MediaSettings.cacheLimitSteps.last),
        isNot(implicit),
      );
    });
  });

  test('every offered cache limit is larger than the one before it', () {
    final steps = MediaSettings.cacheLimitSteps;
    for (var i = 1; i < steps.length; i++) {
      expect(steps[i], greaterThan(steps[i - 1]));
    }
    expect(steps, contains(MediaSettings.defaultCacheLimitBytes));
  });
}
