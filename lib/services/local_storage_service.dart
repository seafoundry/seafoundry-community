// @tier: community
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:path_provider/path_provider.dart';
import 'package:seafoundry_app/models/models.dart';
// Pro-tier models (not exported from barrel)
import 'package:seafoundry_app/models/sync/sync_conflict_entry.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Service for managing local storage of offline data
class LocalStorageService {
  LocalStorageService._();
  static LocalStorageService? _instance;
  static LocalStorageService get instance =>
      _instance ??= LocalStorageService._();

  final _logger = LoggingService.instance;

  static const _dbFileName = 'seafoundry_offline.json';
  static const _pendingOpsFileName = 'seafoundry_pending_ops.json';

  Directory? _appDocDir;

  /// Initialize the local storage
  Future<void> initialize() async {
    _logger.info('Initializing LocalStorageService');

    try {
      if (!kIsWeb &&
          (Platform.isAndroid ||
              Platform.isIOS ||
              Platform.isMacOS ||
              Platform.isWindows ||
              Platform.isLinux)) {
        _appDocDir = await getApplicationDocumentsDirectory();
        // Ensure files exist
        await _ensureFilesExist();
        _logger.info('LocalStorageService initialized at: ${_appDocDir?.path}');
      } else {
        _logger.info('LocalStorageService skipped on web/unsupported platform');
      }
    } catch (e) {
      _logger.error('Failed to initialize LocalStorageService', e);
      // Don't rethrow on web/unsupported platforms to avoid crashing app
      if (!kIsWeb &&
          (Platform.isAndroid ||
              Platform.isIOS ||
              Platform.isMacOS ||
              Platform.isWindows ||
              Platform.isLinux)) {
        rethrow;
      }
    }
  }

  /// Ensure storage files exist
  Future<void> _ensureFilesExist() async {
    final dbFile = await _getDbFile();
    final opsFile = await _getPendingOpsFile();

    if (!await dbFile.exists()) {
      await dbFile.writeAsString(
        json.encode({
          'version': 1,
          'lastSync': null,
          'records': {},
          'events': {},
          'conflicts': <Map<String, dynamic>>[],
        }),
      );
    }

    if (!await opsFile.exists()) {
      await opsFile.writeAsString(json.encode({'operations': []}));
    }
  }

  /// Get the database file
  Future<File> _getDbFile() async {
    if (_appDocDir == null) {
      throw StateError('LocalStorageService not initialized');
    }
    return File('${_appDocDir!.path}/$_dbFileName');
  }

  /// Get the pending operations file
  Future<File> _getPendingOpsFile() async {
    if (_appDocDir == null) {
      throw StateError('LocalStorageService not initialized');
    }
    return File('${_appDocDir!.path}/$_pendingOpsFileName');
  }

  /// Save a record to local storage
  Future<void> saveRecord<T extends GraphNodeRecord>(T record) async {
    try {
      final dbFile = await _getDbFile();
      final dbData =
          json.decode(await dbFile.readAsString()) as Map<String, dynamic>;

      final records = (dbData['records'] as Map<String, dynamic>?) ?? {};
      final typeKey = record.modelType.name;

      if (!records.containsKey(typeKey)) {
        records[typeKey] = {};
      }

      (records[typeKey] as Map<String, dynamic>)[record.id] = record.toJson();

      dbData['records'] = records;
      dbData['lastModified'] = DateTime.now().toIso8601String();

      await dbFile.writeAsString(json.encode(dbData));

      _logger.debug(
        'Saved ${record.modelType.name} ${record.id} to local storage',
      );
    } catch (e) {
      _logger.error('Failed to save record to local storage', e);
      rethrow;
    }
  }

  /// Save multiple records efficiently
  Future<void> saveRecords<T extends GraphNodeRecord>(List<T> records) async {
    if (records.isEmpty) return;

    try {
      final dbFile = await _getDbFile();
      final dbData =
          json.decode(await dbFile.readAsString()) as Map<String, dynamic>;

      final recordsMap = (dbData['records'] as Map<String, dynamic>?) ?? {};

      // Group records by type
      for (final record in records) {
        final typeKey = record.modelType.name;

        if (!recordsMap.containsKey(typeKey)) {
          recordsMap[typeKey] = {};
        }

        (recordsMap[typeKey] as Map<String, dynamic>)[record.id] = record
            .toJson();
      }

      dbData['records'] = recordsMap;
      dbData['lastModified'] = DateTime.now().toIso8601String();

      await dbFile.writeAsString(json.encode(dbData));

      _logger.debug('Saved ${records.length} records to local storage');
    } catch (e) {
      _logger.error('Failed to save records to local storage', e);
      rethrow;
    }
  }

  /// Get a record from local storage
  Future<Map<String, dynamic>?> getRecord(
    String id,
    ModelType modelType,
  ) async {
    try {
      final dbFile = await _getDbFile();
      final dbData =
          json.decode(await dbFile.readAsString()) as Map<String, dynamic>;

      final records = (dbData['records'] as Map<String, dynamic>?) ?? {};
      final typeKey = modelType.name;

      final typeRecords = (records[typeKey] as Map<String, dynamic>?) ?? {};

      return typeRecords[id] as Map<String, dynamic>?;
    } catch (e) {
      _logger.error('Failed to get record from local storage', e);
      return null;
    }
  }

  /// Get all records of a specific type
  Future<List<Map<String, dynamic>>> getRecordsByType(
    ModelType modelType,
  ) async {
    try {
      final dbFile = await _getDbFile();
      final dbData =
          json.decode(await dbFile.readAsString()) as Map<String, dynamic>;

      final records = (dbData['records'] as Map<String, dynamic>?) ?? {};
      final typeKey = modelType.name;

      final typeRecords = (records[typeKey] as Map<String, dynamic>?) ?? {};

      return typeRecords.values.cast<Map<String, dynamic>>().toList();
    } catch (e) {
      _logger.error('Failed to get records from local storage', e);
      return [];
    }
  }

  Future<void> deleteRecord(String id, ModelType modelType) async {
    try {
      final dbFile = await _getDbFile();
      final dbData =
          json.decode(await dbFile.readAsString()) as Map<String, dynamic>;

      final records = (dbData['records'] as Map<String, dynamic>?) ?? {};
      final typeKey = modelType.name;

      final typeRecords = (records[typeKey] as Map<String, dynamic>?) ?? {};
      if (typeRecords.remove(id) == null) {
        return;
      }

      if (typeRecords.isEmpty) {
        records.remove(typeKey);
      } else {
        records[typeKey] = typeRecords;
      }

      dbData['records'] = records;
      dbData['lastModified'] = DateTime.now().toIso8601String();

      await dbFile.writeAsString(json.encode(dbData));
      _logger.debug('Deleted $id (${modelType.name}) from local storage');
    } catch (e) {
      _logger.error('Failed to delete record from local storage', e);
    }
  }

  /// Save an event to local storage
  Future<void> saveEvent(Event event) async {
    try {
      final dbFile = await _getDbFile();
      final dbData =
          json.decode(await dbFile.readAsString()) as Map<String, dynamic>;

      final events = (dbData['events'] as Map<String, dynamic>?) ?? {};
      events[event.id] = event.toJson();

      dbData['events'] = events;
      dbData['lastModified'] = DateTime.now().toIso8601String();

      await dbFile.writeAsString(json.encode(dbData));

      _logger.debug(
        'Saved event ${event.id} (${event.eventTypeId}) to local storage',
      );
    } catch (e) {
      _logger.error('Failed to save event to local storage', e);
      rethrow;
    }
  }

  /// Get events for a specific record
  Future<List<Map<String, dynamic>>> getEventsForRecord(String recordId) async {
    try {
      final dbFile = await _getDbFile();
      final dbData =
          json.decode(await dbFile.readAsString()) as Map<String, dynamic>;

      final events = (dbData['events'] as Map<String, dynamic>?) ?? {};

      return events.values
          .cast<Map<String, dynamic>>()
          .where((event) => event['recordId'] == recordId)
          .toList();
    } catch (e) {
      _logger.error('Failed to get events from local storage', e);
      return [];
    }
  }

  /// Clear all local storage
  Future<void> clearAll() async {
    try {
      final dbFile = await _getDbFile();
      final opsFile = await _getPendingOpsFile();

      await dbFile.writeAsString(
        json.encode({
          'version': 1,
          'lastSync': null,
          'records': {},
          'events': {},
        }),
      );

      await opsFile.writeAsString(json.encode({'operations': []}));

      _logger.info('Cleared all local storage');
    } catch (e) {
      _logger.error('Failed to clear local storage', e);
      rethrow;
    }
  }

  /// Get storage statistics
  Future<StorageStats> getStorageStats() async {
    try {
      final dbFile = await _getDbFile();
      final opsFile = await _getPendingOpsFile();

      final dbData =
          json.decode(await dbFile.readAsString()) as Map<String, dynamic>;
      final opsData =
          json.decode(await opsFile.readAsString()) as Map<String, dynamic>;

      final records = (dbData['records'] as Map<String, dynamic>?) ?? {};
      final events = (dbData['events'] as Map<String, dynamic>?) ?? {};
      final operations = (opsData['operations'] as List?) ?? [];

      int recordCount = 0;
      for (final typeRecords in records.values) {
        recordCount += (typeRecords as Map).length;
      }

      final dbSize = await dbFile.length();
      final opsSize = await opsFile.length();

      return StorageStats(
        recordCount: recordCount,
        eventCount: events.length,
        pendingOperationCount: operations.length,
        totalSizeBytes: dbSize + opsSize,
        lastSync: dbData['lastSync'] != null
            ? DateTime.parse(dbData['lastSync'])
            : null,
        lastModified: dbData['lastModified'] != null
            ? DateTime.parse(dbData['lastModified'])
            : null,
      );
    } catch (e) {
      _logger.error('Failed to get storage stats', e);
      return StorageStats.empty();
    }
  }

  Future<void> appendSyncConflict(SyncConflictEntry entry) async {
    await _upsertSyncConflict(entry, logPrefix: 'Logged');
  }

  Future<void> overwriteSyncConflict(SyncConflictEntry entry) async {
    await _upsertSyncConflict(entry, logPrefix: 'Updated');
  }

  Future<void> _upsertSyncConflict(
    SyncConflictEntry entry, {
    required String logPrefix,
  }) async {
    try {
      final dbFile = await _getDbFile();
      final dbData =
          json.decode(await dbFile.readAsString()) as Map<String, dynamic>;

      final conflicts = (dbData['conflicts'] as List<dynamic>? ?? <dynamic>[])
          .cast<Map<String, dynamic>>();
      final serialized = entry.toJson();
      final existingIndex = conflicts.indexWhere(
        (conflict) => conflict['operationId'] == entry.operationId,
      );
      if (existingIndex >= 0) {
        conflicts[existingIndex] = serialized;
      } else {
        conflicts.add(serialized);
      }

      dbData['conflicts'] = conflicts;
      dbData['lastModified'] = DateTime.now().toIso8601String();

      await dbFile.writeAsString(json.encode(dbData));
      _logger.info(
        '$logPrefix sync conflict for ${entry.recordId} (${entry.modelType.name})',
      );
    } catch (e) {
      _logger.error('Failed to log sync conflict locally', e);
    }
  }

  Future<List<SyncConflictEntry>> getSyncConflicts() async {
    try {
      final dbFile = await _getDbFile();
      final dbData =
          json.decode(await dbFile.readAsString()) as Map<String, dynamic>;
      final conflicts = (dbData['conflicts'] as List<dynamic>? ?? <dynamic>[])
          .cast<Map<String, dynamic>>();
      return conflicts.map(SyncConflictEntry.fromJson).toList(growable: false);
    } catch (e) {
      _logger.error('Failed to read sync conflicts from local storage', e);
      return const <SyncConflictEntry>[];
    }
  }
}

/// Storage statistics
class StorageStats {
  final int recordCount;
  final int eventCount;
  final int pendingOperationCount;
  final int totalSizeBytes;
  final DateTime? lastSync;
  final DateTime? lastModified;

  const StorageStats({
    required this.recordCount,
    required this.eventCount,
    required this.pendingOperationCount,
    required this.totalSizeBytes,
    this.lastSync,
    this.lastModified,
  });

  factory StorageStats.empty() => const StorageStats(
    recordCount: 0,
    eventCount: 0,
    pendingOperationCount: 0,
    totalSizeBytes: 0,
  );

  String get formattedSize {
    if (totalSizeBytes < 1024) return '$totalSizeBytes B';
    if (totalSizeBytes < 1024 * 1024) {
      return '${(totalSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(totalSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
