// @tier: community
part of 'event_repository.dart';

const String _eventSummaryCollectionId = 'event_summaries';
const String _healthIssuesDailySummaryType = 'health_issues_daily';
const String _healthIssuesDailySummaryPrefix = 'health_issues_daily_';

mixin _EventRepositoryHelpers on _EventRepositoryBase {
  Stream<T> _guardStream<T>(
    Stream<T> source, {
    required String debugLabel,
  }) {
    return source.onErrorResume((error, stackTrace) {
      if (_shouldSuppressAuthError(error)) {
        LoggingService.instance.debug(
          'Suppressing event stream error after sign out',
          {'stream': debugLabel},
        );
        return Stream<T>.empty();
      }
      LoggingService.instance.error(
        'Stream error ($debugLabel)',
        error,
        stackTrace,
      );
      return Stream<T>.error(error, stackTrace);
    });
  }

  String _isoNow([DateTime? explicit]) {
    final source = explicit ?? _timestampOverride ?? DateTime.now();
    return DateTimeConverter.toIso8601String(source);
  }

  CollectionReference<Map<String, dynamic>> _eventSummariesCollection() {
    return FirestoreCollectionResolver.instance.subcollection(
      db,
      ModelType.organization.collectionPath,
      organization.id,
      _eventSummaryCollectionId,
    );
  }

  String _healthIssuesDailyDocId(DateTime date) {
    final dateKey = DateTimeConverter.formatDate(date);
    return '$_healthIssuesDailySummaryPrefix$dateKey';
  }

  DocumentReference<Map<String, dynamic>> _healthIssuesDailyDocRef(
    DateTime date,
  ) {
    return _eventSummariesCollection().doc(_healthIssuesDailyDocId(date));
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  List<DateTime> _dateRangeDays(DateTime startDate, DateTime endDate) {
    final start = _normalizeDate(startDate);
    final end = _normalizeDate(endDate);
    if (end.isBefore(start)) return const [];
    final days = end.difference(start).inDays;
    return List<DateTime>.generate(
      days + 1,
      (index) => start.add(Duration(days: index)),
      growable: false,
    );
  }

  @override
  Future<T> withTimestampOverride<T>(
    DateTime timestamp,
    Future<T> Function() action,
  ) async {
    final previous = _timestampOverride;
    _timestampOverride = timestamp;
    try {
      return await action();
    } finally {
      _timestampOverride = previous;
    }
  }

  /// Helper to create exclusive upper bound for urlPath range queries.
  ///
  /// For typical URL paths (alphanumeric), increments the last character.
  /// Handles edge cases: empty strings throw, high Unicode appends sentinel.
  ///
  /// Examples:
  /// - "sites/123" → "sites/124" (typical usage)
  /// - "abc" → "abd" (simple case)
  String _incrementLastChar(String input) {
    if (input.isEmpty) {
      // Empty string would create invalid query bounds (x >= "" AND x < "")
      // This should never happen in practice - urlPath is always non-empty
      throw ArgumentError('Cannot create range query for empty urlPath');
    }

    final lastCharCode = input.codeUnitAt(input.length - 1);

    // Check for high Unicode that would overflow (surrogate pairs, max BMP)
    // In practice, URL paths use ASCII characters, but be defensive
    if (lastCharCode >= 0xD800) {
      // Surrogate pair or near-max Unicode - append high character instead
      return '$input\uFFFF';
    }

    return input.substring(0, input.length - 1) +
        String.fromCharCode(lastCharCode + 1);
  }

  bool _isIndexError(Object error) {
    if (error is FirebaseException) {
      final message = error.message?.toLowerCase() ?? '';
      if (error.code == 'failed-precondition' && message.contains('index')) {
        return true;
      }
    }

    final text = error.toString().toLowerCase();
    if (!text.contains('index')) {
      return false;
    }
    return text.contains('requires an index') ||
        text.contains('index is currently building') ||
        text.contains('failed-precondition');
  }

  Duration _indexRetryDelay(int attempt) {
    const baseSeconds = 2;
    const maxSeconds = 30;
    final seconds = baseSeconds * (1 << (attempt - 1));
    return Duration(seconds: seconds > maxSeconds ? maxSeconds : seconds);
  }

  Stream<T> _retryIndexStream<T>(
    Stream<T> Function() sourceFactory, {
    required String debugLabel,
  }) async* {
    var attempt = 0;
    while (true) {
      try {
        await for (final value in sourceFactory()) {
          attempt = 0;
          yield value;
        }
        break;
      } catch (error, stackTrace) {
        if (_shouldSuppressAuthError(error)) {
          LoggingService.instance.debug(
            'Suppressing event stream error after sign out',
            {'stream': debugLabel},
          );
          return;
        }
        if (!_isIndexError(error)) {
          LoggingService.instance.error(
            'Stream error ($debugLabel)',
            error,
            stackTrace,
          );
          rethrow;
        }
        attempt += 1;
        final delay = _indexRetryDelay(attempt);
        LoggingService.instance.warning(
          'Index not ready for $debugLabel; retrying in ${delay.inSeconds}s',
          {'error': error.toString()},
        );
        await Future.delayed(delay);
      }
    }
  }

  bool _shouldSuppressAuthError(Object error) {
    if (!_isSignedOut()) {
      return false;
    }
    return _isPermissionError(error);
  }

  bool _isSignedOut() {
    try {
      return AuthSessionService.instance.isSigningOut ||
          fbAuth.FirebaseAuth.instance.currentUser == null;
    } catch (_) {
      return AuthSessionService.instance.isSigningOut;
    }
  }

  bool _isPermissionError(Object error) {
    if (error is FirebaseException) {
      return error.code == 'permission-denied' || error.code == 'unauthenticated';
    }
    final message = error.toString().toLowerCase();
    return message.contains('permission-denied') ||
        message.contains('permission') ||
        message.contains('unauthenticated');
  }

  @override
  Query<Object?> collectionQuery(
    CollectionReference<Map<String, dynamic>> collectionRef,
  ) {
    // Note: super.collectionQuery filters by organizationId
    // CRITICAL: Avoid orderBy to prevent composite index requirements
    // Sorting is handled in-memory by consumers
    return super.collectionQuery(collectionRef);
  }


  /// Injects the Firestore document ID into the JSON data.
  ///
  /// Delegates to [FirestoreDocumentHelpers.injectDocumentId].
  Map<String, dynamic> _injectDocId(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) => FirestoreDocumentHelpers.injectDocumentId(doc);

  /// Helper to safely parse an Event from a Firestore DocumentSnapshot.
  /// Returns null if parsing fails, logging the error.
  Event? _parseEventSafe(DocumentSnapshot<Map<String, dynamic>> doc) {
    try {
      return RecordFactory.eventFromJson(_injectDocId(doc));
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to parse event ${doc.id}',
        e,
        stackTrace,
      );
      return null;
    }
  }

  @override
  T withOrganismMetadata<T extends Event>(
    T event, {
    Map<String, dynamic>? additionalMetadata,
  }) {
    final existing = event.metadata == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(event.metadata!);
    existing['organismKind'] = organismContext.kind.name;
    if (additionalMetadata != null) {
      existing.addAll(additionalMetadata);
    }
    final enrichedJson = event.toJson();
    enrichedJson['metadata'] = existing;
    if (event is MonitoringEventRecord) {
      return MonitoringEventRecord.fromJson(enrichedJson) as T;
    }
    return RecordFactory.eventFromJson(enrichedJson) as T;
  }

  Map<String, dynamic> _organismRecordMetadata(
    String recordId,
    OrganismRecord snapshot,
  ) {
    final metadata = <String, dynamic>{'organismRecordId': recordId};
    if (snapshot.speciesId != null) {
      metadata['speciesId'] = snapshot.speciesId;
    }
    metadata['organismKind'] = snapshot.organismKind.name;
    return metadata;
  }
}
