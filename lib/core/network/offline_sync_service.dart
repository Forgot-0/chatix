import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:synchronized/synchronized.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

enum SyncStatus { pending, syncing, synced, failed, conflict, canceled }

enum OfflineOperationType { create, update, delete, custom }

class OfflineChange {
  final String id;

  final String entityType;

  final String? entityId;

  final OfflineOperationType operationType;

  final Map<String, dynamic>? data;

  final SyncStatus status;

  final DateTime timestamp;

  final int retryCount;

  final DateTime? lastRetryTime;

  final String? errorMessage;

  const OfflineChange({
    required this.id,
    required this.entityType,
    this.entityId,
    required this.operationType,
    this.data,
    required this.status,
    required this.timestamp,
    this.retryCount = 0,
    this.lastRetryTime,
    this.errorMessage,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'entityType': entityType,
    'entityId': entityId,
    'operationType': operationType.toString().split('.').last,
    'data': data,
    'status': status.toString().split('.').last,
    'timestamp': timestamp.toIso8601String(),
    'retryCount': retryCount,
    'lastRetryTime': lastRetryTime?.toIso8601String(),
    'errorMessage': errorMessage,
  };

  factory OfflineChange.fromJson(Map<String, dynamic> json) {
    return OfflineChange(
      id: json['id'],
      entityType: json['entityType'],
      entityId: json['entityId'],
      operationType: _parseOperationType(json['operationType']),
      data: json['data'] != null
          ? Map<String, dynamic>.from(json['data'])
          : null,
      status: _parseSyncStatus(json['status']),
      timestamp: DateTime.parse(json['timestamp']),
      retryCount: json['retryCount'] ?? 0,
      lastRetryTime: json['lastRetryTime'] != null
          ? DateTime.parse(json['lastRetryTime'])
          : null,
      errorMessage: json['errorMessage'],
    );
  }

  OfflineChange copyWith({
    String? id,
    String? entityType,
    String? entityId,
    OfflineOperationType? operationType,
    Map<String, dynamic>? data,
    SyncStatus? status,
    DateTime? timestamp,
    int? retryCount,
    DateTime? lastRetryTime,
    String? errorMessage,
  }) {
    return OfflineChange(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      operationType: operationType ?? this.operationType,
      data: data ?? this.data,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      retryCount: retryCount ?? this.retryCount,
      lastRetryTime: lastRetryTime ?? this.lastRetryTime,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  static OfflineOperationType _parseOperationType(String value) {
    switch (value) {
      case 'create':
        return OfflineOperationType.create;
      case 'update':
        return OfflineOperationType.update;
      case 'delete':
        return OfflineOperationType.delete;
      default:
        return OfflineOperationType.custom;
    }
  }

  static SyncStatus _parseSyncStatus(String value) {
    switch (value) {
      case 'pending':
        return SyncStatus.pending;
      case 'syncing':
        return SyncStatus.syncing;
      case 'synced':
        return SyncStatus.synced;
      case 'failed':
        return SyncStatus.failed;
      case 'conflict':
        return SyncStatus.conflict;
      case 'canceled':
        return SyncStatus.canceled;
      default:
        return SyncStatus.pending;
    }
  }
}

abstract class ConflictResolutionStrategy {
  Future<Map<String, dynamic>> resolveConflict({
    required String entityType,
    required String entityId,
    required Map<String, dynamic>? localData,
    required Map<String, dynamic>? remoteData,
    required OfflineOperationType operationType,
  });
}

class ClientWinsStrategy implements ConflictResolutionStrategy {
  @override
  Future<Map<String, dynamic>> resolveConflict({
    required String entityType,
    required String entityId,
    required Map<String, dynamic>? localData,
    required Map<String, dynamic>? remoteData,
    required OfflineOperationType operationType,
  }) async {
    return localData ?? {};
  }
}

class ServerWinsStrategy implements ConflictResolutionStrategy {
  @override
  Future<Map<String, dynamic>> resolveConflict({
    required String entityType,
    required String entityId,
    required Map<String, dynamic>? localData,
    required Map<String, dynamic>? remoteData,
    required OfflineOperationType operationType,
  }) async {
    return remoteData ?? {};
  }
}

class SmartMergeStrategy implements ConflictResolutionStrategy {
  final Map<String, bool> _fieldPriorities;

  SmartMergeStrategy(this._fieldPriorities);

  @override
  Future<Map<String, dynamic>> resolveConflict({
    required String entityType,
    required String entityId,
    required Map<String, dynamic>? localData,
    required Map<String, dynamic>? remoteData,
    required OfflineOperationType operationType,
  }) async {
    if (localData == null) return remoteData ?? {};
    if (remoteData == null) return localData;

    final result = Map<String, dynamic>.from(remoteData);

    localData.forEach((key, value) {
      final clientWins = _fieldPriorities[key] ?? false;
      if (clientWins) {
        result[key] = value;
      }
    });

    return result;
  }
}

abstract class OfflineSyncService {
  Future<OfflineChange> queueChange({
    required String entityType,
    String? entityId,
    required OfflineOperationType operationType,
    Map<String, dynamic>? data,
  });

  Future<void> syncChanges();

  Future<SyncStatus?> getSyncStatus(String entityType, String entityId);

  Future<List<OfflineChange>> getPendingChanges();

  Future<void> resolveConflict(
    String changeId,
    Map<String, dynamic> resolvedData,
  );

  Stream<List<OfflineChange>> get syncStatusStream;

  Future<bool> isOnline();

  Future<void> init();
}

class HiveOfflineSyncService implements OfflineSyncService {
  final Box<String> _box;
  final Connectivity _connectivity;
  final Lock _syncLock = Lock();

  final _uuid = const Uuid();
  final _syncController = StreamController<List<OfflineChange>>.broadcast();
  bool _isSyncing = false;

  HiveOfflineSyncService({
    required Box<String> box,
    required Connectivity connectivity,
    ConflictResolutionStrategy? conflictStrategy,
  }) : _box = box,
       _connectivity = connectivity;

  @override
  Future<void> init() async {
    _connectivity.onConnectivityChanged.listen((result) {
      if (!result.contains(ConnectivityResult.none)) {
        syncChanges();
      }
    });

    debugPrint('🔄 Offline sync service initialized');
  }

  @override
  Future<OfflineChange> queueChange({
    required String entityType,
    String? entityId,
    required OfflineOperationType operationType,
    Map<String, dynamic>? data,
  }) async {
    final id = _uuid.v4();
    final change = OfflineChange(
      id: id,
      entityType: entityType,
      entityId: entityId,
      operationType: operationType,
      data: data,
      status: SyncStatus.pending,
      timestamp: DateTime.now(),
    );

    await _box.put(id, jsonEncode(change.toJson()));

    _notifyListeners();

    if (await isOnline()) {
      syncChanges();
    }

    return change;
  }

  @override
  Future<void> syncChanges() async {
    if (_isSyncing) return;

    if (!await isOnline()) return;

    await _syncLock.synchronized(() async {
      _isSyncing = true;

      _notifyListeners();

      try {
        final pendingChanges = await getPendingChanges().then(
          (changes) =>
              changes.where((c) => c.status == SyncStatus.pending).toList(),
        );

        pendingChanges.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        for (final change in pendingChanges) {
          await _processChange(change);
        }
      } finally {
        _isSyncing = false;

        _notifyListeners();
      }
    });
  }

  Future<void> _processChange(OfflineChange change) async {
    final syncingChange = change.copyWith(status: SyncStatus.syncing);
    await _box.put(change.id, jsonEncode(syncingChange.toJson()));
    _notifyListeners();

    try {
      await Future.delayed(const Duration(milliseconds: 500));

      final syncedChange = syncingChange.copyWith(status: SyncStatus.synced);
      await _box.put(change.id, jsonEncode(syncedChange.toJson()));
    } catch (e) {
      final failedChange = syncingChange.copyWith(
        status: SyncStatus.failed,
        retryCount: change.retryCount + 1,
        lastRetryTime: DateTime.now(),
        errorMessage: e.toString(),
      );
      await _box.put(change.id, jsonEncode(failedChange.toJson()));
    }

    _notifyListeners();
  }

  @override
  Future<SyncStatus?> getSyncStatus(String entityType, String entityId) async {
    final changes = await getPendingChanges();
    final entityChanges = changes
        .where((c) => c.entityType == entityType && c.entityId == entityId)
        .toList();

    if (entityChanges.isEmpty) return null;

    entityChanges.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return entityChanges.first.status;
  }

  @override
  Future<List<OfflineChange>> getPendingChanges() async {
    final changes = <OfflineChange>[];

    for (final key in _box.keys) {
      final json = _box.get(key);
      if (json != null) {
        try {
          final change = OfflineChange.fromJson(jsonDecode(json));
          changes.add(change);
        } catch (e) {
          debugPrint('🔄 Error parsing change: $e');
        }
      }
    }

    return changes;
  }

  @override
  Future<void> resolveConflict(
    String changeId,
    Map<String, dynamic> resolvedData,
  ) async {
    final json = _box.get(changeId);
    if (json == null) return;

    final change = OfflineChange.fromJson(jsonDecode(json));

    final resolvedChange = change.copyWith(
      data: resolvedData,
      status: SyncStatus.pending,
    );

    await _box.put(changeId, jsonEncode(resolvedChange.toJson()));

    _notifyListeners();

    syncChanges();
  }

  @override
  Stream<List<OfflineChange>> get syncStatusStream => _syncController.stream;

  void _notifyListeners() async {
    final changes = await getPendingChanges();
    _syncController.add(changes);
  }

  @override
  Future<bool> isOnline() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    return !connectivityResult.contains(ConnectivityResult.none);
  }
}

class StreamController<T> {
  final List<void Function(T)> _listeners = [];

  StreamController.broadcast();

  void add(T value) {
    for (final listener in _listeners) {
      listener(value);
    }
  }

  Stream<T> get stream =>
      Stream<T>.periodic(const Duration(days: 365), (_) {
          throw UnimplementedError('This is a mock stream for demo purposes');
        }).asBroadcastStream()
        ..listen((event) {}, onDone: () {}, onError: (error, stack) {});
}
