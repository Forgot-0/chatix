import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/core/error/failure_messages.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/presentation/providers/profile_providers.dart';
import 'package:chatix/features/profile/presentation/widgets/profile_avatar.dart';

/// Type-ahead person picker over `GET /profiles/?username=` (api-docs §4.2).
///
/// Replaces the "type a numeric user id" fields that every place needing a
/// user used to carry. The backend contract is unchanged — callers still end
/// up with an `int` id — only the way that id is *found* moved from the
/// user's memory into a search box.
///
/// ### Why the use case directly, and not `profileListProvider`
///
/// `profileListProvider` is a single global `AsyncNotifier` backing the
/// Profiles tab. Calling `.search()` from a dialog would silently rewrite
/// that screen's list and scroll position behind the user's back, and two
/// pickers open at once would fight over one state object. This widget owns
/// throwaway results for one text field, so it holds them locally and calls
/// [GetProfilesUseCase] itself.
///
/// ### ⚠️ `username` filters but never renders
///
/// `GET /profiles/` accepts `username` as a query parameter, but `ProfileDTO`
/// (§4.3) does **not** contain a username field — the account's handle lives
/// in the users service, not the profiles one. So a search matches on the
/// handle the user typed while the row can only show `display_name`. Rows are
/// labelled through [profileLabel], which falls back to `User #id` rather
/// than showing an `@handle` this client never receives. Rendering the typed
/// query as if it were the found user's handle would be a guess, and wrong
/// for every partial match.
///
/// Debounced by [debounce] (300 ms) so a typed word costs one request rather
/// than one per keystroke; an empty field collapses the results and issues no
/// request at all.
class UserSearchField extends ConsumerStatefulWidget {
  const UserSearchField({
    super.key,
    required this.onSelected,
    this.excludedUserIds = const {},
    this.labelText = 'Search by username',
    this.autofocus = false,
    this.debounce = const Duration(milliseconds: 300),
  });

  /// Called with the picked profile. The caller takes `profile.id` — the same
  /// `int` the old numeric field produced.
  final void Function(ProfileEntity profile) onSelected;

  /// Ids to hide from results — already-picked people, existing members, or
  /// the signed-in user. Filtered client-side: §4.2 has no "exclude" query
  /// parameter, and the alternative (letting someone pick a duplicate and
  /// failing later with `409 ALREADY_CHAT_MEMBER`) is worse UX.
  final Set<int> excludedUserIds;

  final String labelText;
  final bool autofocus;
  final Duration debounce;

  @override
  ConsumerState<UserSearchField> createState() => _UserSearchFieldState();
}

class _UserSearchFieldState extends ConsumerState<UserSearchField> {
  final _controller = TextEditingController();

  Timer? _debounce;
  List<ProfileEntity> _results = const [];
  bool _isLoading = false;
  String? _error;

  /// Guards against out-of-order responses: a slow request for "an" must not
  /// overwrite the results of a later, faster "anna".
  int _requestId = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();

    final query = value.trim();
    if (query.isEmpty) {
      // Collapse rather than list everybody: an empty query would fetch page
      // one of the entire user base, which is neither useful nor cheap.
      setState(() {
        _results = const [];
        _isLoading = false;
        _error = null;
      });
      return;
    }

    setState(() => _isLoading = true);
    _debounce = Timer(widget.debounce, () => _search(query));
  }

  Future<void> _search(String query) async {
    final requestId = ++_requestId;

    final result = await ref
        .read(getProfilesUseCaseProvider)
        .execute(username: query, pageSize: 20);

    // A newer keystroke already started its own request.
    if (!mounted || requestId != _requestId) return;

    setState(() {
      _isLoading = false;
      result.match(
        (failure) {
          _error = friendlyFailureMessage(
            failure,
            fallback: 'Could not search for people',
          );
          _results = const [];
        },
        (page) {
          _error = null;
          _results = page.items
              .where((p) => !widget.excludedUserIds.contains(p.id))
              .toList();
        },
      );
    });
  }

  void _select(ProfileEntity profile) {
    widget.onSelected(profile);
    // Clearing here (rather than in the caller) keeps the field ready for the
    // next pick in multi-select mode; single-select callers close the sheet
    // immediately, so the reset is invisible to them.
    _controller.clear();
    setState(() {
      _results = const [];
      _error = null;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasQuery = _controller.text.trim().isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          autofocus: widget.autofocus,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          decoration: InputDecoration(
            labelText: widget.labelText,
            prefixIcon: const Icon(Icons.search),
            border: const OutlineInputBorder(),
            suffixIcon: hasQuery
                ? IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _controller.clear();
                      _onChanged('');
                    },
                  )
                : null,
          ),
        ),
        if (hasQuery) ...[const SizedBox(height: 8), _buildResults(theme)],
      ],
    );
  }

  Widget _buildResults(ThemeData theme) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(Icons.error_outline, size: 18, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            Expanded(child: Text(_error!, style: theme.textTheme.bodySmall)),
            TextButton(
              onPressed: () => _search(_controller.text.trim()),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      // An explicit empty state, not a blank gap: "nothing matched" and
      // "still typing" must not look the same.
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Icon(
              Icons.person_search_outlined,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 8),
            Text(
              'No one found for "${_controller.text.trim()}"',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            Text(
              'Search matches usernames exactly as they are registered.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ConstrainedBox(
      // Bounded so the dropdown can live inside a dialog without pushing the
      // action buttons off-screen.
      constraints: const BoxConstraints(maxHeight: 280),
      child: Material(
        type: MaterialType.transparency,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _results.length,
          itemBuilder: (context, index) {
            final profile = _results[index];
            return ListTile(
              leading: ProfileAvatar(profile: profile, radius: 20),
              title: Text(profileLabel(profile)),
              subtitle: profile.specialization == null
                  ? null
                  : Text(profile.specialization!),
              onTap: () => _select(profile),
            );
          },
        ),
      ),
    );
  }
}

/// Human label for a profile in a picker row.
///
/// `ProfileDTO` has no username (§4.3), so this is `display_name` or the
/// `User #id` diagnostic fallback — the same convention `chatDisplayName`
/// uses on the chat side, spelled once so the two never drift.
String profileLabel(ProfileEntity profile) {
  final name = profile.displayName?.trim();
  if (name != null && name.isNotEmpty) return name;
  return 'User #${profile.id}';
}

/// [UserSearchField] plus a chip row of everyone picked so far.
///
/// The multi-select form used by chat creation: picking adds a chip and
/// resets the query, the chips are removable, and an already-picked person
/// stops appearing in results (via [UserSearchField.excludedUserIds]) so the
/// same id can't be submitted twice.
class MultiUserSearchField extends StatelessWidget {
  const MultiUserSearchField({
    super.key,
    required this.selected,
    required this.onAdd,
    required this.onRemove,
    this.labelText = 'Add people by username',
    this.helperText,
  });

  final List<ProfileEntity> selected;
  final void Function(ProfileEntity profile) onAdd;
  final void Function(ProfileEntity profile) onRemove;

  final String labelText;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (selected.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final profile in selected)
                InputChip(
                  avatar: ProfileAvatar(profile: profile, radius: 12),
                  label: Text(profileLabel(profile)),
                  onDeleted: () => onRemove(profile),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        UserSearchField(
          labelText: labelText,
          excludedUserIds: selected.map((p) => p.id).toSet(),
          onSelected: onAdd,
        ),
        if (helperText != null) ...[
          const SizedBox(height: 6),
          Text(
            helperText!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ],
    );
  }
}
