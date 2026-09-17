import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/core/error/failure_messages.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/network/request_cancellation.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/domain/usecases/get_profiles_use_case.dart';
import 'package:chatix/features/profile/presentation/providers/profile_providers.dart';
import 'package:chatix/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

class UserSearchField extends ConsumerStatefulWidget {
  const UserSearchField({
    super.key,
    required this.onSelected,
    this.excludedUserIds = const {},
    this.labelText = 'Search by name or @username',
    this.autofocus = false,
    this.debounce = const Duration(milliseconds: 300),
  });

  final void Function(ProfileEntity profile) onSelected;

  final Set<int> excludedUserIds;

  final String labelText;
  final bool autofocus;
  final Duration debounce;

  @override
  ConsumerState<UserSearchField> createState() => _UserSearchFieldState();
}

class _UserSearchFieldState extends ConsumerState<UserSearchField> {
  /// Below this the server answers 422 rather than an empty page
  /// (api-docs §4.2), so the field waits instead of asking.
  static const int _minQueryLength = GetProfilesUseCase.minQueryLength;

  final _controller = TextEditingController();

  Timer? _debounce;
  List<ProfileEntity> _results = const [];
  bool _isLoading = false;
  String? _error;

  /// Set while a query is typed but still too short to send.
  bool _needsMoreCharacters = false;

  int _requestId = 0;
  RequestCancellation? _inFlight;

  @override
  void dispose() {
    _debounce?.cancel();
    _inFlight?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    // Whatever is still on the wire answers an older query.
    _inFlight?.cancel();

    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _results = const [];
        _isLoading = false;
        _needsMoreCharacters = false;
        _error = null;
      });
      return;
    }

    if (query.length < _minQueryLength) {
      setState(() {
        _results = const [];
        _isLoading = false;
        _needsMoreCharacters = true;
        _error = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _needsMoreCharacters = false;
    });
    _debounce = Timer(widget.debounce, () => _search(query));
  }

  Future<void> _search(String query) async {
    final requestId = ++_requestId;

    final cancellation = RequestCancellation();
    _inFlight = cancellation;

    // One `q` matches username OR display_name server-side (api-docs §4.2),
    // so a person is found by either without the client firing two requests
    // against a 20/min budget and merging the answers.
    final result = await ref
        .read(getProfilesUseCaseProvider)
        .execute(q: query, pageSize: 20, cancellation: cancellation);

    if (!mounted || requestId != _requestId) return;

    setState(() {
      _isLoading = false;
      result.match(
        (failure) {
          // The search this one replaced is nobody's error to see.
          if (failure is CancelledFailure) return;
          _error = friendlyFailureMessage(
            failure,
            fallback: AppLocalizations.of(context).peopleSearchFailed,
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
                    tooltip: AppLocalizations.of(context).clear,
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
    if (_needsMoreCharacters) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          AppLocalizations.of(context).searchTypeMore(_minQueryLength),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

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
              child: Text(AppLocalizations.of(context).retry),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
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
              AppLocalizations.of(
                context,
              ).peopleSearchNoneFound(_controller.text.trim()),
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            Text(
              AppLocalizations.of(context).peopleSearchHint,
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
              subtitle: Text(_secondLine(profile)),
              onTap: () => _select(profile),
            );
          },
        ),
      ),
    );
  }
}

/// What to call somebody in a list: their display name, or the handle every
/// profile has when they have not set one (api-docs §4.3).
String profileLabel(ProfileEntity profile) {
  final name = profile.displayName?.trim();
  if (name != null && name.isNotEmpty) return name;
  return '@${profile.username}';
}

/// The handle, unless the row is already titled with it, in which case
/// whatever else identifies the person.
String _secondLine(ProfileEntity profile) {
  final name = profile.displayName?.trim();
  if (name == null || name.isEmpty) return profile.specialization?.trim() ?? '';
  return '@${profile.username}';
}

class MultiUserSearchField extends StatelessWidget {
  const MultiUserSearchField({
    super.key,
    required this.selected,
    required this.onAdd,
    required this.onRemove,
    this.excludedUserIds = const {},
    this.labelText = 'Add people by name or @username',
    this.helperText,
  });

  final List<ProfileEntity> selected;
  final void Function(ProfileEntity profile) onAdd;
  final void Function(ProfileEntity profile) onRemove;

  /// People who cannot be picked at all, on top of the ones already chosen —
  /// members a chat already has, say. Keeping them out of the results is
  /// kinder than letting them be tapped and quietly ignored.
  final Set<int> excludedUserIds;

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
          excludedUserIds: {...excludedUserIds, ...selected.map((p) => p.id)},
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
