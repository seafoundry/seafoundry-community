// @tier: community
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/inventory_event.dart';
import 'package:seafoundry_app/models/group.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/records/inventory_record.dart';
import 'package:seafoundry_app/models/site.dart';
import 'package:seafoundry_app/models/types/event_type.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';
import 'package:seafoundry_app/repositories/event_history_repository.dart';
import 'package:seafoundry_app/repositories/utils/firestore_document_helpers.dart';
import 'package:seafoundry_app/repositories/inventory/group_repository.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/repositories/inventory/site_repository.dart';
import 'package:seafoundry_app/services/genet_id_resolver.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Service for building and managing comprehensive event histories
/// that propagate upward from children to parent nodes
class EventHistoryService {
  EventHistoryService({
    required EventHistoryRepository eventHistoryRepository,
    SiteRepository? siteRepository,
    GroupRepository? groupRepository,
    OrganismRecordRepository? organismRepository,
  }) : _eventHistoryRepository = eventHistoryRepository,
       _siteRepository = siteRepository,
       _groupRepository = groupRepository,
       _organismRepository = organismRepository;

  static const int _childQueryLimit = 100;

  final EventHistoryRepository _eventHistoryRepository;
  final SiteRepository? _siteRepository;
  final GroupRepository? _groupRepository;
  final OrganismRecordRepository? _organismRepository;
  final LoggingService _logger = LoggingService.instance;

  bool _isArchivedData(Map<String, dynamic> data) {
    if (data['archived'] == true || data['isDeleted'] == true) {
      return true;
    }
    final metadata = data['metadata'];
    if (metadata is Map) {
      return metadata['archived'] == true || metadata['isDeleted'] == true;
    }
    return false;
  }

  /// Build a complete event history for a record, including all propagated events
  Future<EventHistory> buildEventHistory({
    required String recordId,
    required ModelType recordModelType,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? eventTypes,
  }) async {
    try {
      final fetchedEvents = await _eventHistoryRepository.getEventsForRecord(
        recordId: recordId,
        recordModelType: recordModelType,
        startDate: startDate,
        endDate: endDate,
        eventTypes: eventTypes,
      );

      fetchedEvents.sort(
        (a, b) =>
            DateTime.parse(a.createdAt).compareTo(DateTime.parse(b.createdAt)),
      );

      final propagatedEvents = fetchedEvents
          .where((event) => event.eventTypeId == EventType.activity.id)
          .toList();

      final directEvents = fetchedEvents
          .where((event) => event.eventTypeId != EventType.activity.id)
          .toList();

      return EventHistory(
        recordId: recordId,
        recordModelType: recordModelType,
        events: fetchedEvents,
        startDate: startDate,
        endDate: endDate,
        totalEvents: fetchedEvents.length,
        directEvents: directEvents.length,
        propagatedEvents: propagatedEvents.length,
      );
    } catch (e) {
      _logger.error('Failed to build event history for $recordId', e);
      rethrow;
    }
  }

  /// Build event history for a record and all its children recursively
  Future<HierarchicalEventHistory> buildHierarchicalEventHistory({
    required String recordId,
    required ModelType recordModelType,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? eventTypes,
    int maxDepth = 5,
  }) async {
    try {
      final depth = maxDepth > 0 ? maxDepth : 1;
      return await _buildHierarchicalEventHistory(
        recordId: recordId,
        recordModelType: recordModelType,
        startDate: startDate,
        endDate: endDate,
        eventTypes: eventTypes,
        remainingDepth: depth,
        visited: <String>{},
      );
    } catch (e) {
      _logger.error(
        'Failed to build hierarchical event history for $recordId',
        e,
      );
      rethrow;
    }
  }

  Future<HierarchicalEventHistory> _buildHierarchicalEventHistory({
    required String recordId,
    required ModelType recordModelType,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? eventTypes,
    required int remainingDepth,
    required Set<String> visited,
  }) async {
    final nodeKey = _visitedKey(recordId, recordModelType);
    if (!visited.add(nodeKey)) {
      _logger.warning(
        'Detected cyclic reference while building event history for $nodeKey',
      );
      final currentHistory = await buildEventHistory(
        recordId: recordId,
        recordModelType: recordModelType,
        startDate: startDate,
        endDate: endDate,
        eventTypes: eventTypes,
      );
      return HierarchicalEventHistory(
        recordId: recordId,
        recordModelType: recordModelType,
        histories: {recordId: currentHistory},
        children: const {},
        startDate: startDate,
        endDate: endDate,
        totalEvents: currentHistory.totalEvents,
        maxDepth: remainingDepth,
      );
    }

    try {
      final histories = <String, EventHistory>{};
      final children = <String, HierarchicalEventHistory>{};

      final currentHistory = await buildEventHistory(
        recordId: recordId,
        recordModelType: recordModelType,
        startDate: startDate,
        endDate: endDate,
        eventTypes: eventTypes,
      );

      histories[recordId] = currentHistory;
      var totalEvents = currentHistory.totalEvents;

      if (remainingDepth > 1) {
        final childRecords = await _getChildRecords(
          recordId: recordId,
          modelType: recordModelType,
        );

        for (final child in childRecords) {
          final childKey = _visitedKey(child.id, child.modelType);
          if (visited.contains(childKey)) {
            _logger.warning(
              'Skipping child $childKey to avoid infinite recursion',
            );
            continue;
          }

          try {
            final childHistory = await _buildHierarchicalEventHistory(
              recordId: child.id,
              recordModelType: child.modelType,
              startDate: startDate,
              endDate: endDate,
              eventTypes: eventTypes,
              remainingDepth: remainingDepth - 1,
              visited: visited,
            );
            histories.addAll(childHistory.histories);
            children[child.id] = childHistory;
            totalEvents += childHistory.totalEvents;
          } catch (error, stackTrace) {
            _logger.error(
              'Failed to build child history for $childKey while traversing $nodeKey',
              error,
              stackTrace,
            );
          }
        }
      }
      return HierarchicalEventHistory(
        recordId: recordId,
        recordModelType: recordModelType,
        histories: histories,
        children: children,
        startDate: startDate,
        endDate: endDate,
        totalEvents: totalEvents,
        maxDepth: remainingDepth,
      );
    } finally {
      visited.remove(nodeKey);
    }
  }

  Future<List<InventoryRecord>> _getChildRecords({
    required String recordId,
    required ModelType modelType,
  }) async {
    final children = <InventoryRecord>[];

    try {
      switch (modelType) {
        case ModelType.organization:
          final siteRepository = _siteRepository;
          if (siteRepository == null) {
            return children;
          }
          final siteSnapshot = await siteRepository.collectionRef
              .where('organizationId', isEqualTo: recordId)
              .limit(_childQueryLimit)
              .get();
          for (final doc in siteSnapshot.docs) {
            try {
              final data = FirestoreDocumentHelpers.injectDocumentId(doc);
              children.add(Site.fromJson(data));
            } catch (e) {
              _logger.warning(
                'Failed to parse site child for organization $recordId: $e',
              );
            }
          }
          break;
        case ModelType.site:
          final groupRepository = _groupRepository;
          if (groupRepository == null) {
            return children;
          }
          final groupSnapshot = await groupRepository.collectionRef
              .where('parentId', isEqualTo: recordId)
              .limit(_childQueryLimit)
              .get();
          for (final doc in groupSnapshot.docs) {
            try {
              final data = FirestoreDocumentHelpers.injectDocumentId(doc);
              children.add(Group.fromJson(data));
            } catch (e) {
              _logger.warning(
                'Failed to parse group child for site $recordId: $e',
              );
            }
          }
          break;
        case ModelType.group:
          final groupRepository = _groupRepository;
          if (groupRepository != null) {
            final groupSnapshot = await groupRepository.collectionRef
                .where('parentId', isEqualTo: recordId)
                .limit(_childQueryLimit)
                .get();
            for (final doc in groupSnapshot.docs) {
              try {
                final data = FirestoreDocumentHelpers.injectDocumentId(doc);
                children.add(Group.fromJson(data));
              } catch (e) {
                _logger.warning(
                  'Failed to parse nested group child for group $recordId: $e',
                );
              }
            }
          }
          final organismRepository = _organismRepository;
          if (organismRepository != null) {
            final organismSnapshot = await organismRepository.collectionRef
                .where('groupId', isEqualTo: recordId)
                .limit(_childQueryLimit)
                .get();
            for (final doc in organismSnapshot.docs) {
              try {
                final data = deepNormalizeMap(
                  FirestoreDocumentHelpers.injectDocumentId(doc),
                );
                if (_isArchivedData(data)) {
                  continue;
                }
                children.add(OrganismRecord.partial(json: data));
              } catch (e) {
                _logger.warning(
                  'Failed to parse organism child for group $recordId: $e',
                );
              }
            }
          }
          break;
        case ModelType.genet:
          final organismRepository = _organismRepository;
          if (organismRepository == null) {
            return children;
          }
          // Query organisms with foreignKeys.genet.id == recordId
          final organismSnapshot = await organismRepository.collectionRef
              .where('foreignKeys.genet.id', isEqualTo: recordId)
              .limit(_childQueryLimit)
              .get();
          for (final doc in organismSnapshot.docs) {
            try {
              final data = deepNormalizeMap(
                FirestoreDocumentHelpers.injectDocumentId(doc),
              );
              if (_isArchivedData(data)) {
                continue;
              }
              children.add(OrganismRecord.partial(json: data));
            } catch (e) {
              _logger.warning(
                'Failed to parse organism child for genet $recordId: $e',
              );
            }
          }
          break;
        default:
          break;
      }
    } catch (e, st) {
      _logger.error(
        'Failed to load child records for ${modelType.name} $recordId',
        e,
        st,
      );
    }

    return children;
  }

  String _visitedKey(String id, ModelType modelType) => '${modelType.name}:$id';

  /// Get event timeline for a record with snapshot comparisons
  Future<EventTimeline> buildEventTimeline({
    required String recordId,
    required ModelType recordModelType,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final history = await buildEventHistory(
        recordId: recordId,
        recordModelType: recordModelType,
        startDate: startDate,
        endDate: endDate,
      );

      final timeline = <TimelineEntry>[];
      InventoryRecord? currentSnapshot;

      for (final event in history.events) {
        if (event is InventoryEvent) {
          final previousSnapshot = currentSnapshot;
          currentSnapshot = event.snapshot;

          timeline.add(
            TimelineEntry(
              event: event,
              timestamp: DateTime.parse(event.createdAt),
              previousSnapshot: previousSnapshot,
              currentSnapshot: currentSnapshot,
              changes: _calculateChanges(previousSnapshot, currentSnapshot),
            ),
          );
        } else {
          timeline.add(
            TimelineEntry(
              event: event,
              timestamp: DateTime.parse(event.createdAt),
              previousSnapshot: currentSnapshot,
              currentSnapshot: currentSnapshot,
              changes: <String, dynamic>{},
            ),
          );
        }
      }

      return EventTimeline(
        recordId: recordId,
        recordModelType: recordModelType,
        entries: timeline,
        startDate: startDate,
        endDate: endDate,
        totalEntries: timeline.length,
      );
    } catch (e) {
      _logger.error('Failed to build event timeline for $recordId', e);
      rethrow;
    }
  }

  /// Calculate changes between two snapshots
  Map<String, dynamic> _calculateChanges(
    InventoryRecord? previous,
    InventoryRecord? current,
  ) {
    if (previous == null || current == null) return {};

    final changes = <String, dynamic>{};

    // Compare common properties
    if (previous.id != current.id) {
      changes['id'] = {'from': previous.id, 'to': current.id};
    }
    if (previous.createdAt != current.createdAt) {
      changes['createdAt'] = {
        'from': previous.createdAt,
        'to': current.createdAt,
      };
    }
    if (previous.updatedAt != current.updatedAt) {
      changes['updatedAt'] = {
        'from': previous.updatedAt,
        'to': current.updatedAt,
      };
    }

    // Compare model-specific properties
    if (previous is OrganismRecord && current is OrganismRecord) {
      final prevName = previous.localId;
      final currName = current.localId;
      if (prevName != currName) {
        changes['name'] = {'from': prevName, 'to': currName};
      }
      if (previous.measurement.value != current.measurement.value) {
        changes['quantity'] = {
          'from': previous.measurement.value,
          'to': current.measurement.value,
        };
      }
      final prevHealth = previous.metadata?['healthStatus'];
      final currHealth = current.metadata?['healthStatus'];
      if (prevHealth != currHealth) {
        changes['healthStatus'] = {
          'from': prevHealth,
          'to': currHealth,
        };
      }
      if (previous.speciesId != current.speciesId) {
        changes['speciesId'] = {
          'from': previous.speciesId,
          'to': current.speciesId,
        };
      }
      final prevGenetId = GenetIdResolver.resolve(previous);
      final currGenetId = GenetIdResolver.resolve(current);
      if (prevGenetId != currGenetId) {
        changes['genetId'] = {'from': prevGenetId, 'to': currGenetId};
      }
    }

    return changes;
  }
}

/// Represents a complete event history for a record
class EventHistory {
  final String recordId;
  final ModelType recordModelType;
  final List<Event> events;
  final DateTime? startDate;
  final DateTime? endDate;
  final int totalEvents;
  final int directEvents;
  final int propagatedEvents;

  const EventHistory({
    required this.recordId,
    required this.recordModelType,
    required this.events,
    this.startDate,
    this.endDate,
    required this.totalEvents,
    required this.directEvents,
    required this.propagatedEvents,
  });

  /// Get events by type
  List<Event> getEventsByType(String eventType) {
    return events.where((event) => event.eventTypeId == eventType).toList();
  }

  /// Get events within a date range
  List<Event> getEventsInRange(DateTime start, DateTime end) {
    return events.where((event) {
      final eventDate = DateTime.parse(event.createdAt);
      return eventDate.isAfter(start) && eventDate.isBefore(end);
    }).toList();
  }

  /// Get the most recent event
  Event? get mostRecentEvent => events.isNotEmpty ? events.last : null;

  /// Get the first event
  Event? get firstEvent => events.isNotEmpty ? events.first : null;
}

/// Represents a hierarchical event history including children
class HierarchicalEventHistory {
  final String recordId;
  final ModelType recordModelType;
  final Map<String, EventHistory> histories;
  final Map<String, HierarchicalEventHistory> children;
  final DateTime? startDate;
  final DateTime? endDate;
  final int totalEvents;
  final int maxDepth;

  const HierarchicalEventHistory({
    required this.recordId,
    required this.recordModelType,
    required this.histories,
    required this.children,
    this.startDate,
    this.endDate,
    required this.totalEvents,
    required this.maxDepth,
  });

  /// Get all events across all levels
  List<Event> get allEvents {
    final allEvents = <Event>[];
    for (final history in histories.values) {
      allEvents.addAll(history.events);
    }
    for (final child in children.values) {
      allEvents.addAll(child.allEvents);
    }
    return allEvents;
  }
}

/// Represents a timeline entry with snapshot comparisons
class TimelineEntry {
  final Event event;
  final DateTime timestamp;
  final InventoryRecord? previousSnapshot;
  final InventoryRecord? currentSnapshot;
  final Map<String, dynamic> changes;

  const TimelineEntry({
    required this.event,
    required this.timestamp,
    this.previousSnapshot,
    this.currentSnapshot,
    required this.changes,
  });

  /// Check if this entry represents a significant change
  bool get hasSignificantChanges => changes.isNotEmpty;

  /// Get a summary of changes
  String get changeSummary {
    if (changes.isEmpty) return 'No changes';

    final changeList = changes.entries
        .map((e) => '${e.key}: ${e.value['from']} → ${e.value['to']}')
        .join(', ');
    return changeList;
  }
}

/// Represents a complete event timeline with snapshot comparisons
class EventTimeline {
  final String recordId;
  final ModelType recordModelType;
  final List<TimelineEntry> entries;
  final DateTime? startDate;
  final DateTime? endDate;
  final int totalEntries;

  const EventTimeline({
    required this.recordId,
    required this.recordModelType,
    required this.entries,
    this.startDate,
    this.endDate,
    required this.totalEntries,
  });

  /// Get entries with significant changes
  List<TimelineEntry> get significantChanges {
    return entries.where((entry) => entry.hasSignificantChanges).toList();
  }

  /// Get entries within a date range
  List<TimelineEntry> getEntriesInRange(DateTime start, DateTime end) {
    return entries.where((entry) {
      return entry.timestamp.isAfter(start) && entry.timestamp.isBefore(end);
    }).toList();
  }

  /// Get the most recent entry
  TimelineEntry? get mostRecentEntry =>
      entries.isNotEmpty ? entries.last : null;

  /// Get the first entry
  TimelineEntry? get firstEntry => entries.isNotEmpty ? entries.first : null;
}
