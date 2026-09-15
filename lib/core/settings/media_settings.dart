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

/// What the reader has said about media that plays itself.
///
/// One value rather than a key per field, for the same reason
/// [AppearanceSettings] is: a settings change is a single write, so a
/// half-written state cannot happen.
class MediaSettings {
  const MediaSettings({this.videoNoteAutoplay = MediaAutoplay.wifiOnly});

  /// Whether a video note starts playing — silently — when it scrolls into
  /// view.
  final MediaAutoplay videoNoteAutoplay;

  MediaSettings copyWith({MediaAutoplay? videoNoteAutoplay}) => MediaSettings(
    videoNoteAutoplay: videoNoteAutoplay ?? this.videoNoteAutoplay,
  );

  Map<String, Object?> toJson() => {'videoNoteAutoplay': videoNoteAutoplay.name};

  static MediaSettings fromJson(Map<String, Object?> json) => MediaSettings(
    videoNoteAutoplay: MediaAutoplay.fromName(
      json['videoNoteAutoplay'] as String?,
    ),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaSettings &&
          other.videoNoteAutoplay == videoNoteAutoplay);

  @override
  int get hashCode => videoNoteAutoplay.hashCode;
}
