import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/features/project/domain/entities/application_entity.dart';
import 'package:chatix/features/project/domain/entities/position_entity.dart';
import 'package:chatix/features/project/presentation/providers/project_providers.dart';

/// `GET /positions/{id}/` 🔓 (api-docs §5.3), keyed by the position UUID.
/// Public read — works with or without a token.
final positionDetailProvider = FutureProvider.family<PositionEntity, String>((ref, positionId) async {
  final result = await ref.watch(getPositionUseCaseProvider).execute(positionId);
  return result.fold((failure) => throw failure, (position) => position);
});

/// `GET /projects/{id}/positions/` 🔒 (api-docs §5.3) — a project's positions,
/// keyed by the (int) project id. Used by the "Positions" tab of the project
/// detail screen. Invalidate this after creating/deleting a position.
final projectPositionsProvider = FutureProvider.family<List<PositionEntity>, int>((ref, projectId) async {
  final result = await ref
      .watch(getProjectPositionsUseCaseProvider)
      .execute(projectId, pageSize: 50);
  return result.fold((failure) => throw failure, (page) => page.items);
});

/// `GET /positions/{id}/applications/` (api-docs §5.3) for the position's
/// owner/maintainer, plus [approve]/[reject] actions
/// (`/applications/{id}/approve|reject/`). Keyed by position UUID. On a
/// successful decision the affected application is dropped locally and the
/// list refetched.
final positionApplicationsProvider =
    FutureProvider.family<List<ApplicationEntity>, String>(
  (ref, positionId) async {
    final result = await ref
        .read(getPositionApplicationsUseCaseProvider)
        .execute(
          positionId,
          status: ApplicationStatus.pending,
          pageSize: 50,
        );

    return result.fold(
      (failure) => Future.error(failure),
      (page) => page.items,
    );
  },
);

class PositionApplicationActionController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<String?> approve({
    required String applicationId,
    required String positionId,
  }) async {
    state = const AsyncLoading();

    final result = await ref
        .read(approveApplicationUseCaseProvider)
        .execute(applicationId);

    return result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        return failure.message;
      },
      (_) {
        state = const AsyncData(null);

        ref.invalidate(positionApplicationsProvider(positionId));

        return null;
      },
    );
  }

  Future<String?> reject({
    required String applicationId,
    required String positionId,
  }) async {
    state = const AsyncLoading();

    final result = await ref
        .read(rejectApplicationUseCaseProvider)
        .execute(applicationId);

    return result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        return failure.message;
      },
      (_) {
        state = const AsyncData(null);

        ref.invalidate(positionApplicationsProvider(positionId));

        return null;
      },
    );
  }
}

final positionApplicationActionProvider =
    AsyncNotifierProvider<PositionApplicationActionController, void>(
  PositionApplicationActionController.new,
);
