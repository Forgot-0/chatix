import 'dart:convert';

import 'package:chatix/core/storage/local_storage_service.dart';
import 'package:chatix/features/chat/domain/entities/voice_waveform.dart';

/// The two things about a voice message that only this device knows.
///
/// Neither has anywhere to live on the server. `AttachmentDTO` has no
/// waveform field and no per-listener read state (api-docs §5.5), and the
/// read receipts that do exist are per message, not per attachment — so the
/// bars drawn in a bubble and the dot that says this one has been heard are
/// both kept here, keyed by attachment id.
///
/// The attachment id is known before the message exists: `upload_token` from
/// the presign step *is* the id of the attachment it becomes (api-docs
/// §5.5), so a waveform can be filed under it the moment the upload lands.
abstract interface class VoiceLocalStore {
  /// The bars recorded for [attachmentId], or null if this device did not
  /// record it.
  VoiceWaveform? readWaveform(String attachmentId);

  Future<void> writeWaveform(String attachmentId, VoiceWaveform waveform);

  /// Attachment ids this device has played through.
  Set<String> readListened();

  Future<void> markListened(String attachmentId);

  /// Drops both maps, for signing out: they are keyed by attachment id and
  /// mean nothing to the next account on this device.
  Future<void> clear();
}

class SharedPrefsVoiceLocalStore implements VoiceLocalStore {
  SharedPrefsVoiceLocalStore(this._storage);

  static const String _waveformsKey = 'voice.waveforms';
  static const String _listenedKey = 'voice.listened';

  /// How many of each to keep.
  ///
  /// Both maps grow one entry per voice message forever otherwise, and
  /// neither is worth unbounded preferences: a waveform is 48 characters and
  /// an id is 36, so a thousand of each is well under a hundred kilobytes,
  /// and older messages fall back to a drawn stand-in rather than to
  /// nothing.
  static const int _maxEntries = 1000;

  final LocalStorageService _storage;

  Map<String, String>? _waveformCache;
  List<String>? _listenedCache;

  @override
  VoiceWaveform? readWaveform(String attachmentId) {
    final encoded = _waveforms()[attachmentId];
    if (encoded == null) return null;

    final decoded = VoiceWaveform.decode(encoded);
    return decoded.isEmpty ? null : decoded;
  }

  @override
  Future<void> writeWaveform(
    String attachmentId,
    VoiceWaveform waveform,
  ) async {
    if (waveform.isEmpty) return;

    final next = Map<String, String>.from(_waveforms())
      ..remove(attachmentId)
      ..[attachmentId] = waveform.encode();

    // Insertion order is what ages them out: `Map` keeps it, and the oldest
    // key is the first one.
    while (next.length > _maxEntries) {
      next.remove(next.keys.first);
    }

    _waveformCache = next;
    await _storage.setString(_waveformsKey, jsonEncode(next));
  }

  @override
  Set<String> readListened() => _listened().toSet();

  @override
  Future<void> markListened(String attachmentId) async {
    final current = _listened();
    if (current.contains(attachmentId)) return;

    final next = [...current, attachmentId];
    if (next.length > _maxEntries) {
      next.removeRange(0, next.length - _maxEntries);
    }

    _listenedCache = next;
    await _storage.setStringList(_listenedKey, next);
  }

  @override
  Future<void> clear() async {
    _waveformCache = <String, String>{};
    _listenedCache = <String>[];
    await _storage.remove(_waveformsKey);
    await _storage.remove(_listenedKey);
  }

  Map<String, String> _waveforms() {
    final cached = _waveformCache;
    if (cached != null) return cached;

    final raw = _storage.getString(_waveformsKey);
    if (raw == null || raw.isEmpty) return _waveformCache = <String, String>{};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return _waveformCache = <String, String>{};

      return _waveformCache = <String, String>{
        for (final entry in decoded.entries)
          if (entry.key is String && entry.value is String)
            entry.key as String: entry.value as String,
      };
    } on FormatException {
      return _waveformCache = <String, String>{};
    }
  }

  List<String> _listened() =>
      _listenedCache ??= _storage.getStringList(_listenedKey) ?? <String>[];
}

/// The fallback where shared preferences were never handed to the app — a
/// widget test that pumps one bubble, mostly. Waveforms recorded in this
/// session still draw; nothing survives a restart.
class InMemoryVoiceLocalStore implements VoiceLocalStore {
  final Map<String, VoiceWaveform> _waveforms = {};
  final Set<String> _listened = {};

  @override
  VoiceWaveform? readWaveform(String attachmentId) => _waveforms[attachmentId];

  @override
  Future<void> writeWaveform(
    String attachmentId,
    VoiceWaveform waveform,
  ) async {
    if (waveform.isEmpty) return;
    _waveforms[attachmentId] = waveform;
  }

  @override
  Set<String> readListened() => Set.unmodifiable(_listened);

  @override
  Future<void> markListened(String attachmentId) async {
    _listened.add(attachmentId);
  }

  @override
  Future<void> clear() async {
    _waveforms.clear();
    _listened.clear();
  }
}
