import 'package:equatable/equatable.dart';

/// The limits the organizer holds itself to.
abstract final class OrganizerLimits {
  /// How many chats can sit in the pinned zone at once. The zone is meant to
  /// be readable at a glance; past five it is just the list again.
  static const int pinnedChats = 5;
}

/// The handful of choices that change how the list behaves rather than what
/// is in it.
class OrganizerSettings extends Equatable {
  const OrganizerSettings({
    this.unarchiveOnNewMessage = true,
    this.foldersHidden = false,
  });

  /// Whether a new message pulls a chat back out of the archive.
  ///
  /// On by default: archiving is "not now", not "never again". Messages I
  /// sent myself never bring a chat back — opening it to write already did.
  final bool unarchiveOnNewMessage;

  /// Keeps the folder strip off the chats screen without deleting the
  /// folders behind it.
  final bool foldersHidden;

  OrganizerSettings copyWith({
    bool? unarchiveOnNewMessage,
    bool? foldersHidden,
  }) {
    return OrganizerSettings(
      unarchiveOnNewMessage:
          unarchiveOnNewMessage ?? this.unarchiveOnNewMessage,
      foldersHidden: foldersHidden ?? this.foldersHidden,
    );
  }

  @override
  List<Object?> get props => [unarchiveOnNewMessage, foldersHidden];
}
