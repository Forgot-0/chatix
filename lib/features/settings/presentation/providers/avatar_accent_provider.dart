import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/images/dominant_color.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/profile/presentation/providers/profile_detail_provider.dart';

/// How an attempt to take the accent out of the user's avatar ended.
enum AvatarAccentStatus {
  /// A colour was found. [AvatarAccentResult.accent] carries it.
  found,

  /// There is no avatar to read — nobody signed in, or none uploaded.
  noAvatar,

  /// The avatar loaded but holds no colour worth seeding from: a greyscale
  /// photo, or a black-and-white logo.
  noColour,

  /// The avatar could not be fetched or decoded.
  failed,
}

@immutable
class AvatarAccentResult {
  const AvatarAccentResult(this.status, [this.accent]);

  final AvatarAccentStatus status;
  final Color? accent;
}

/// Reads the accent out of the signed-in user's avatar.
///
/// A function rather than a `FutureProvider`, because this is an action with
/// a result the reader is told about — not a piece of state the screen
/// watches — and a plain callback is the shape a test can replace with a
/// predictable colour and no network.
typedef AvatarAccentReader = Future<AvatarAccentResult> Function();

class AvatarAccentPicker {
  const AvatarAccentPicker(this._ref);

  final Ref _ref;

  /// The avatar variant asked for.
  ///
  /// The scan runs at 48px, so anything above the 64 variant is bytes spent
  /// on detail that is thrown away before it is looked at.
  static const int variantSize = 64;

  Future<AvatarAccentResult> pick() async {
    final userId = _ref.read(authProvider).value?.id;
    if (userId == null) {
      return const AvatarAccentResult(AvatarAccentStatus.noAvatar);
    }

    final String? url;
    try {
      final profile = await _ref.read(profileDetailProvider(userId).future);
      url = profile.bestAvatarUrl(variantSize);
    } on Object {
      return const AvatarAccentResult(AvatarAccentStatus.failed);
    }

    if (url == null || url.isEmpty) {
      return const AvatarAccentResult(AvatarAccentStatus.noAvatar);
    }

    // `NetworkImage`, not the app's disk-cached provider: an avatar URL is
    // presigned and expires in 300 seconds (api-docs §4.3), so caching this
    // one-shot read by URL would only fill the disk with copies that can
    // never be hit again.
    final accent = await DominantColor.fromImage(NetworkImage(url));

    return accent == null
        ? const AvatarAccentResult(AvatarAccentStatus.noColour)
        : AvatarAccentResult(AvatarAccentStatus.found, accent);
  }
}

final avatarAccentPickerProvider = Provider<AvatarAccentReader>((ref) {
  return AvatarAccentPicker(ref).pick;
});
