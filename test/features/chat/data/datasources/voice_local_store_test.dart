import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chatix/core/storage/local_storage_service.dart';
import 'package:chatix/features/chat/data/datasources/voice_local_store.dart';
import 'package:chatix/features/chat/domain/entities/voice_waveform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SharedPrefsVoiceLocalStore> store([
    Map<String, Object> initial = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(initial);
    return SharedPrefsVoiceLocalStore(
      LocalStorageService(await SharedPreferences.getInstance()),
    );
  }

  VoiceWaveform waveform(double level) =>
      VoiceWaveform.fromSamples([level, level / 2, level]);

  group('waveforms', () {
    test('what was recorded comes back', () async {
      final subject = await store();
      final original = waveform(0.8);

      await subject.writeWaveform('att-1', original);

      expect(subject.readWaveform('att-1')?.encode(), original.encode());
    });

    test('an attachment this device never recorded has none', () async {
      final subject = await store();
      expect(subject.readWaveform('att-unknown'), isNull);
    });

    test('survives a restart', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final first = SharedPrefsVoiceLocalStore(LocalStorageService(prefs));
      await first.writeWaveform('att-1', waveform(0.6));

      final second = SharedPrefsVoiceLocalStore(LocalStorageService(prefs));
      expect(second.readWaveform('att-1'), isNotNull);
    });

    test('an empty waveform is not worth storing', () async {
      final subject = await store();
      await subject.writeWaveform('att-1', VoiceWaveform.empty);
      expect(subject.readWaveform('att-1'), isNull);
    });

    test('junk in storage reads as nothing rather than throwing', () async {
      final subject = await store({'voice.waveforms': 'not json'});
      expect(subject.readWaveform('att-1'), isNull);
    });
  });

  group('listened marks', () {
    test('a mark is remembered and is idempotent', () async {
      final subject = await store();

      await subject.markListened('att-1');
      await subject.markListened('att-1');

      expect(subject.readListened(), {'att-1'});
    });

    test('starts out remembering nothing', () async {
      final subject = await store();
      expect(subject.readListened(), isEmpty);
    });

    test('survives a restart', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await SharedPrefsVoiceLocalStore(
        LocalStorageService(prefs),
      ).markListened('att-7');

      expect(
        SharedPrefsVoiceLocalStore(LocalStorageService(prefs)).readListened(),
        contains('att-7'),
      );
    });
  });
}
