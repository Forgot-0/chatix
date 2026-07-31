import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/features/project/domain/entities/application_entity.dart';
import 'package:chatix/features/project/presentation/providers/project_providers.dart';

/// `GET /applications/me/` (api-docs §5.4) — the current candidate's own
/// applications, optionally filtered by [ApplicationStatus]. The active
/// filter is held in [status]; [setStatus] re-runs the query. ⚠️ The backend
/// defaults `status` to `pending` when omitted, so a `null` here still means
/// "pending only" on the server — pass an explicit status to see others.
class MyApplicationsController extends AsyncNotifier<List<ApplicationEntity>> {
  ApplicationStatus? _status = ApplicationStatus.pending;

  ApplicationStatus? get status => _status;

  @override
  Future<List<ApplicationEntity>> build() => _fetch();

  Future<void> setStatus(ApplicationStatus? status) async {
    _status = status;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<List<ApplicationEntity>> _fetch() async {
    final result = await ref
        .read(getMyApplicationsUseCaseProvider)
        .execute(status: _status, pageSize: 50);
    return result.fold((failure) => throw failure, (page) => page.items);
  }
}

final myApplicationsProvider =
    AsyncNotifierProvider<MyApplicationsController, List<ApplicationEntity>>(
  MyApplicationsController.new,
);
