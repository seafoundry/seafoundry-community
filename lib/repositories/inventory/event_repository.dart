// @tier: community
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fbAuth;
import 'package:rxdart/rxdart.dart';
import 'package:seafoundry_app/errors/domain_errors.dart';
import 'package:seafoundry_app/models/factories/event_factory.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/models/transfer_status.dart';
import 'package:seafoundry_app/repositories/contracts/i_event_repository.dart';
import 'package:seafoundry_app/repositories/firebase_utils.dart';
import 'package:seafoundry_app/repositories/inventory/base_inventory_record_repository.dart';
import 'package:seafoundry_app/services/auth_session_service.dart';
import 'package:seafoundry_app/services/firestore_collection_resolver.dart';
import 'package:seafoundry_app/services/genet_id_resolver.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/stream_cache.dart';
import 'package:seafoundry_app/utils/date_time_converter.dart';
import 'package:seafoundry_app/repositories/utils/firestore_document_helpers.dart';

part 'event_repository_helpers.dart';
part 'event_repository_history.dart';
part 'event_repository_mutations.dart';
part 'event_repository_queries.dart';

abstract class _EventRepositoryBase
    extends BaseInventoryRecordRepository<Event>
    implements IEventRepository {
  _EventRepositoryBase({
    required super.organization,
    required super.user,
    required super.firestore,
    super.organismContext,
  }) : super(modelType: ModelType.event);

  DateTime? _timestampOverride;

  /// Check if a model type represents an organism (coral or organismRecord).
  bool _isOrganismType(ModelType type) {
    return type == ModelType.organismRecord;
  }

  /// Apply organization scoping without adding ordering.
  @protected
  Query<Map<String, dynamic>> organizationQuery(
    CollectionReference<Map<String, dynamic>> collectionRef,
  ) {
    return super.collectionQuery(collectionRef) as Query<Map<String, dynamic>>;
  }
}

class EventRepository extends _EventRepositoryBase
    with
        _EventRepositoryHelpers,
        _EventRepositoryHistory,
        _EventRepositoryMutations,
        _EventRepositoryQueries {
  EventRepository({
    required super.organization,
    required super.user,
    required super.firestore,
    super.organismContext,
  });

  @override
  void dispose() {
    // Clean up stream caches to prevent memory leaks
    _organismRecordEventCache.dispose();
    _urlPathEventCache.dispose();
    _recentEventsCache.dispose();
    super.dispose();
  }

  @visibleForTesting
  static ({OutplantEvent updatedEvent, Map<String, Object?> payload})
  prepareOutplantGeometryUpdate({
    required OutplantEvent event,
    OutplantGeometry? geometry,
    bool clearGeometry = false,
    required String updatedAt,
    required String updatedById,
  }) {
    return _EventRepositoryMutations.prepareOutplantGeometryUpdate(
      event: event,
      geometry: geometry,
      clearGeometry: clearGeometry,
      updatedAt: updatedAt,
      updatedById: updatedById,
    );
  }
}
