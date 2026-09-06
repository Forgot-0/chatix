import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/network/offline_sync_service.dart';
import 'package:hive/hive.dart';

final connectivityProvider = Provider<Connectivity>((ref) {
  return Connectivity();
});

final offlineSyncBoxProvider = FutureProvider<Box<String>>((ref) async {
  return await Hive.openBox<String>(AppConstants.offlineSyncBox);
});

final conflictResolutionStrategyProvider = Provider<ConflictResolutionStrategy>(
  (ref) {
    return SmartMergeStrategy({
      'id': false,
      'createdAt': false,
      'updatedAt': true,
    });
  },
);

final offlineSyncServiceProvider = Provider<OfflineSyncService>((ref) {
  final boxAsync = ref.watch(offlineSyncBoxProvider);

  return boxAsync.when(
    data: (box) {
      final connectivity = ref.watch(connectivityProvider);
      final conflictStrategy = ref.watch(conflictResolutionStrategyProvider);

      final service = HiveOfflineSyncService(
        box: box,
        connectivity: connectivity,
        conflictStrategy: conflictStrategy,
      );

      service.init();

      ref.onDispose(() {
        box.close();
      });

      return service;
    },
    loading: () => LoadingOfflineSyncService(),
    error: (error, stack) => ErrorOfflineSyncService(error.toString()),
  );
});

final pendingChangesProvider = StreamProvider<List<OfflineChange>>((ref) {
  final offlineSyncService = ref.watch(offlineSyncServiceProvider);

  if (offlineSyncService is LoadingOfflineSyncService) {
    return const Stream.empty();
  }

  if (offlineSyncService is ErrorOfflineSyncService) {
    return const Stream.empty();
  }

  return offlineSyncService.syncStatusStream;
});

final isOnlineProvider = FutureProvider.autoDispose<bool>((ref) async {
  final connectivity = ref.watch(connectivityProvider);
  final connectivityResult = await connectivity.checkConnectivity();
  return !connectivityResult.contains(ConnectivityResult.none);
});

class LoadingOfflineSyncService implements OfflineSyncService {
  @override
  Future<OfflineChange> queueChange({
    required String entityType,
    String? entityId,
    required OfflineOperationType operationType,
    Map<String, dynamic>? data,
  }) async {
    throw UnimplementedError('Offline sync service not yet initialized');
  }

  @override
  Future<void> syncChanges() async {
  }

  @override
  Future<SyncStatus?> getSyncStatus(String entityType, String entityId) async {
    return null;
  }

  @override
  Future<List<OfflineChange>> getPendingChanges() async {
    return [];
  }

  @override
  Future<void> resolveConflict(
    String changeId,
    Map<String, dynamic> resolvedData,
  ) async {
  }

  @override
  Stream<List<OfflineChange>> get syncStatusStream => const Stream.empty();

  @override
  Future<bool> isOnline() async {
    return false;
  }

  @override
  Future<void> init() async {
  }
}

class ErrorOfflineSyncService implements OfflineSyncService {
  final String errorMessage;

  ErrorOfflineSyncService(this.errorMessage);

  @override
  Future<OfflineChange> queueChange({
    required String entityType,
    String? entityId,
    required OfflineOperationType operationType,
    Map<String, dynamic>? data,
  }) async {
    throw Exception('Failed to initialize offline sync service: $errorMessage');
  }

  @override
  Future<void> syncChanges() async {
  }

  @override
  Future<SyncStatus?> getSyncStatus(String entityType, String entityId) async {
    return null;
  }

  @override
  Future<List<OfflineChange>> getPendingChanges() async {
    return [];
  }

  @override
  Future<void> resolveConflict(
    String changeId,
    Map<String, dynamic> resolvedData,
  ) async {
  }

  @override
  Stream<List<OfflineChange>> get syncStatusStream => const Stream.empty();

  @override
  Future<bool> isOnline() async {
    return false;
  }

  @override
  Future<void> init() async {
  }
}

class OfflineStatusIndicator extends ConsumerWidget {
  const OfflineStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnlineAsync = ref.watch(isOnlineProvider);
    final pendingChangesAsync = ref.watch(pendingChangesProvider);

    return isOnlineAsync.when(
      data: (isOnline) {
        return pendingChangesAsync.when(
          data: (pendingChanges) {
            final hasPending = pendingChanges.any(
              (c) => c.status == SyncStatus.pending,
            );
            final hasSyncing = pendingChanges.any(
              (c) => c.status == SyncStatus.syncing,
            );
            final hasFailed = pendingChanges.any(
              (c) => c.status == SyncStatus.failed,
            );

            if (!isOnline) {
              return _buildIndicator(Icons.cloud_off, 'Offline', Colors.orange);
            } else if (hasSyncing) {
              return _buildIndicator(
                Icons.sync,
                'Syncing',
                Colors.blue,
                isAnimated: true,
              );
            } else if (hasFailed) {
              return _buildIndicator(
                Icons.error_outline,
                'Sync errors',
                Colors.red,
              );
            } else if (hasPending) {
              return _buildIndicator(
                Icons.pending_outlined,
                'Changes pending',
                Colors.orange,
              );
            } else {
              return _buildIndicator(
                Icons.cloud_done,
                'All synced',
                Colors.green,
              );
            }
          },
          loading: () => _buildIndicator(
            Icons.sync,
            'Checking sync',
            Colors.blue,
            isAnimated: true,
          ),
          error: (error, stack) =>
              _buildIndicator(Icons.cloud_off, 'Sync error', Colors.red),
        );
      },
      loading: () => _buildIndicator(
        Icons.cloud_queue,
        'Checking connection',
        Colors.grey,
      ),
      error: (error, stack) =>
          _buildIndicator(Icons.cloud_off, 'Connection error', Colors.red),
    );
  }

  Widget _buildIndicator(
    IconData icon,
    String message,
    Color color, {
    bool isAnimated = false,
  }) {
    return Tooltip(
      message: message,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isAnimated)
            RotatingIcon(icon: icon, color: color)
          else
            Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(message, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}

class RotatingIcon extends StatefulWidget {
  final IconData icon;

  final Color color;

  const RotatingIcon({super.key, required this.icon, required this.color});

  @override
  State<RotatingIcon> createState() => _RotatingIconState();
}

class _RotatingIconState extends State<RotatingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Icon(widget.icon, color: widget.color, size: 16),
    );
  }
}
