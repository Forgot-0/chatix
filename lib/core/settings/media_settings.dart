/// When media in the feed is allowed to start playing on its own.
///
/// Kept as our own enum rather than a bare bool so the middle answer — the
/// one most people actually want — is expressible. The platform's own data
/// saver is not readable from Flutter on either Android or iOS, so
/// [MediaAutoplay.wifiOnly] is the app's stand-in for it and the default:
/// nothing spends mobile data without having been asked to.
library;

enum MediaAutoplay {
  /// On any connection.
  always,

  /// Only on a connection that is not charged by the megabyte.
  wifiOnly,

  /// Never. A video note waits for a tap, like a voice message does.
  never;

  static MediaAutoplay fromName(String? value) =>
      MediaAutoplay.values.firstWhere(
        (mode) => mode.name == value,
        orElse: () => MediaAutoplay.wifiOnly,
      );
}

/// When an attachment is fetched before anyone asks for it.
///
/// The same three answers as [MediaAutoplay] and deliberately a separate
/// type: these are set per attachment kind, they are about bytes rather than
/// about motion, and conflating them would make "never autoplay video notes"
/// silently also mean "never download them".
enum MediaAutoDownload {
  /// On any connection, mobile data included.
  always,

  /// Only on a connection that is not charged by the megabyte.
  wifiOnly,

  /// Never — the attachment waits for a tap.
  never;

  /// Whether the file may be fetched right now, given the connection.
  bool allowsOn({required bool unmetered}) => switch (this) {
    MediaAutoDownload.always => true,
    MediaAutoDownload.wifiOnly => unmetered,
    MediaAutoDownload.never => false,
  };

  static MediaAutoDownload fromName(
    String? value,
    MediaAutoDownload fallback,
  ) => MediaAutoDownload.values.firstWhere(
    (mode) => mode.name == value,
    orElse: () => fallback,
  );
}

/// The attachment kinds auto-download is set for.
///
/// Four buckets rather than one switch, because the cost of each is wildly
/// different: a photo is worth fetching ahead on a train, a 90 MB video is
/// not, and a voice message is small enough that waiting for it is pure
/// friction.
enum MediaKind {
  photo(MediaAutoDownload.wifiOnly),
  video(MediaAutoDownload.wifiOnly),
  file(MediaAutoDownload.never),
  voice(MediaAutoDownload.always);

  const MediaKind(this.defaultPolicy);

  /// What this kind does before anyone has said otherwise.
  final MediaAutoDownload defaultPolicy;
}

/// What the reader has said about media that plays, downloads or piles up by
/// itself.
///
/// One value rather than a key per field, for the same reason
/// [AppearanceSettings] is: a settings change is a single write, so a
/// half-written state cannot happen.
class MediaSettings {
  const MediaSettings({
    this.videoNoteAutoplay = MediaAutoplay.wifiOnly,
    this.autoDownload = const <MediaKind, MediaAutoDownload>{},
    this.cacheLimitBytes = defaultCacheLimitBytes,
  });

  /// How much disk cached attachments may take before the oldest are
  /// dropped, before anyone has said otherwise.
  static const int defaultCacheLimitBytes = 256 * 1024 * 1024;

  /// The sizes the cache limit can be set to.
  ///
  /// A short list of round numbers rather than a free slider: the value is a
  /// disk budget, and nobody has an opinion about 1.37 GB.
  static const List<int> cacheLimitSteps = <int>[
    128 * 1024 * 1024,
    256 * 1024 * 1024,
    512 * 1024 * 1024,
    1024 * 1024 * 1024,
    2048 * 1024 * 1024,
    4096 * 1024 * 1024,
  ];

  /// Whether a video note starts playing — silently — when it scrolls into
  /// view.
  final MediaAutoplay videoNoteAutoplay;

  /// Per-kind auto-download policy. Sparse: a kind that is absent is at its
  /// [MediaKind.defaultPolicy], so the defaults can be retuned in a later
  /// release without rewriting what people have stored.
  final Map<MediaKind, MediaAutoDownload> autoDownload;

  /// How much disk cached attachments may take before the oldest are
  /// dropped.
  final int cacheLimitBytes;

  MediaAutoDownload policyFor(MediaKind kind) =>
      autoDownload[kind] ?? kind.defaultPolicy;

  MediaSettings copyWith({
    MediaAutoplay? videoNoteAutoplay,
    Map<MediaKind, MediaAutoDownload>? autoDownload,
    int? cacheLimitBytes,
  }) => MediaSettings(
    videoNoteAutoplay: videoNoteAutoplay ?? this.videoNoteAutoplay,
    autoDownload: autoDownload ?? this.autoDownload,
    cacheLimitBytes: cacheLimitBytes ?? this.cacheLimitBytes,
  );

  MediaSettings withPolicy(MediaKind kind, MediaAutoDownload policy) =>
      copyWith(
        autoDownload: <MediaKind, MediaAutoDownload>{
          ...autoDownload,
          kind: policy,
        },
      );

  Map<String, Object?> toJson() => <String, Object?>{
    'videoNoteAutoplay': videoNoteAutoplay.name,
    'autoDownload': <String, String>{
      for (final entry in autoDownload.entries)
        entry.key.name: entry.value.name,
    },
    'cacheLimitBytes': cacheLimitBytes,
  };

  static MediaSettings fromJson(Map<String, Object?> json) {
    final stored = json['autoDownload'];
    final policies = <MediaKind, MediaAutoDownload>{};

    if (stored is Map) {
      for (final kind in MediaKind.values) {
        final value = stored[kind.name];
        if (value is String) {
          policies[kind] = MediaAutoDownload.fromName(
            value,
            kind.defaultPolicy,
          );
        }
      }
    }

    return MediaSettings(
      videoNoteAutoplay: MediaAutoplay.fromName(
        json['videoNoteAutoplay'] is String
            ? json['videoNoteAutoplay'] as String
            : null,
      ),
      autoDownload: policies,
      // Read by shape rather than cast: a preference written by an older
      // build — or corrupted — must fall back, not crash the launch.
      cacheLimitBytes: switch (json['cacheLimitBytes']) {
        final num bytes when bytes > 0 => bytes.toInt(),
        _ => defaultCacheLimitBytes,
      },
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaSettings &&
          other.videoNoteAutoplay == videoNoteAutoplay &&
          other.cacheLimitBytes == cacheLimitBytes &&
          _samePolicies(other.autoDownload));

  bool _samePolicies(Map<MediaKind, MediaAutoDownload> other) {
    for (final kind in MediaKind.values) {
      if ((autoDownload[kind] ?? kind.defaultPolicy) !=
          (other[kind] ?? kind.defaultPolicy)) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    videoNoteAutoplay,
    cacheLimitBytes,
    Object.hashAll(<Object>[
      for (final kind in MediaKind.values) policyFor(kind),
    ]),
  );
}
