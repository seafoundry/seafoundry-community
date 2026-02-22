// @tier: community
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/group.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/site.dart';
import 'package:seafoundry_app/repositories/inventory/event_repository.dart';
import 'package:seafoundry_app/repositories/inventory/group_repository.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/repositories/inventory/site_repository.dart';
import 'package:seafoundry_app/services/csv/import/conflict_detector.dart';
import 'package:seafoundry_app/services/csv/import/csv_import_models.dart';
import 'package:seafoundry_app/services/csv/import/local_id_matcher.dart';
import 'package:seafoundry_app/services/genet_id_resolver.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Importer for consolidated outplant CSV format.
///
/// This importer handles a two-pass processing approach:
/// 1. Pass 1: Parse all rows, validate fields, group by eventId
/// 2. Pass 2: Resolve names to IDs, create OutplantEvents
///
/// The consolidated format combines event-level and allocation-level data
/// into a single CSV, with each row representing one allocation.
class OutplantConsolidatedCsvImporter {
  OutplantConsolidatedCsvImporter({
    required EventRepository eventRepository,
    required SiteRepository siteRepository,
    required GroupRepository groupRepository,
    required OrganismRecordRepository organismRecordRepository,
  })  : _eventRepository = eventRepository,
        _siteRepository = siteRepository,
        _groupRepository = groupRepository,
        _organismRecordRepository = organismRecordRepository;

  final EventRepository _eventRepository;
  final SiteRepository _siteRepository;
  final GroupRepository _groupRepository;
  final OrganismRecordRepository _organismRecordRepository;

  // Caches for name resolution
  final Map<String, Site?> _siteNameCache = {};
  final Map<String, Group?> _structureNameCache = {};
  final Map<String, OrganismRecord?> _localIdCache = {};

  static const _requiredFields = <String>{
    'eventId',
    'eventDate',
    'siteName',
    'localId',
    'quantity',
  };

  void _clearCaches() {
    _siteNameCache.clear();
    _structureNameCache.clear();
    _localIdCache.clear();
  }

  Future<CSVImportResult> import({
    required List<Map<String, String>> rows,
    bool validateOnly = false,
    Map<String, String>? metadata,
    String? sourceName,
    CsvTranslationSummary? translationSummary,
    int? totalRowCount,
  }) async {
    _clearCaches();
    final errors = <CSVImportError>[];
    final createdEvents = <OutplantEvent>[];
    int successCount = 0;

    // Pre-validation: Check for intra-file duplicate localIds
    final duplicateConflicts = ConflictDetector.detectIntraFileDuplicates(
      rows,
      'localId',
    );
    if (duplicateConflicts.isNotEmpty) {
      errors.addAll(ConflictDetector.conflictsToErrors(duplicateConflicts));
    }

    // If there are blocking conflicts, return early
    final blockingDuplicates = ConflictDetector.blockingConflicts(
      duplicateConflicts,
    );
    if (blockingDuplicates.isNotEmpty) {
      return CSVImportResult(
        totalRows: totalRowCount ?? rows.length,
        successfulImports: 0,
        errors: errors,
        importedGenets: const [],
        importedOrganisms: const [],
        translationSummary: translationSummary,
      );
    }

    // Pass 1: Parse and validate all rows, group by eventId
    final eventGroups = <String, _ResolvedEventGroup>{};
    final parsedRows = <_ParsedAllocationRow>[];

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final rowNum = i + 2; // Account for header row

      final parsed = await _parseRow(row, rowNum, errors);
      if (parsed != null) {
        parsedRows.add(parsed);
      }
    }

    // Group parsed rows by eventId
    for (final parsed in parsedRows) {
      final group = eventGroups.putIfAbsent(
        parsed.eventId,
        () => _ResolvedEventGroup(
          eventId: parsed.eventId,
          eventDate: parsed.eventDate,
          siteName: parsed.siteName,
          eventNotes: parsed.eventNotes,
          canonicalRowNumber: parsed.rowNumber,
        ),
      );
      group.allocations.add(parsed);

      // Check for event-level field conflicts
      _checkEventLevelConflicts(group, parsed, errors);
    }

    // Pass 2: Resolve names to IDs and create events
    for (final entry in eventGroups.entries) {
      final group = entry.value;
      final groupErrors = <CSVImportError>[];

      // Resolve site
      final firstAllocation = group.allocations.first;
      final site = await _resolveSiteByName(
        firstAllocation.siteName,
        firstAllocation.rowNumber,
        groupErrors,
      );

      if (site == null) {
        errors.addAll(groupErrors);
        continue;
      }

      // Build allocations with resolved IDs
      final allocations = <OutplantAllocation>[];
      var allAllocationsValid = true;

      for (final allocation in group.allocations) {
        final resolved = await _resolveAllocation(
          allocation,
          site,
          groupErrors,
        );
        if (resolved != null) {
          allocations.add(resolved);
        } else {
          allAllocationsValid = false;
        }
      }

      if (!allAllocationsValid) {
        errors.addAll(groupErrors);
        continue;
      }

      // Create the outplant event
      if (!validateOnly && errors.isEmpty) {
        try {
          final event = await _eventRepository.createOutplantEvent(
            site: site,
            name: 'Outplant ${group.eventId}',
            allocations: allocations,
            comment: group.eventNotes,
          );
          createdEvents.add(event);
          successCount += group.allocations.length;
        } catch (e, stackTrace) {
          LoggingService.instance.error(
            'Failed to create outplant event',
            e,
            stackTrace,
          );
          errors.add(
            CSVImportError(
              row: group.canonicalRowNumber,
              field: 'eventId',
              value: group.eventId,
              message: 'Failed to create outplant event: $e',
            ),
          );
        }
      } else if (validateOnly) {
        successCount += group.allocations.length;
      }
    }

    return CSVImportResult(
      totalRows: totalRowCount ?? rows.length,
      successfulImports: successCount,
      errors: errors,
      importedGenets: const [],
      importedOrganisms: const [],
      updatedOutplantEvents: createdEvents,
      translationSummary: translationSummary,
    );
  }

  Future<_ParsedAllocationRow?> _parseRow(
    Map<String, String> row,
    int rowNum,
    List<CSVImportError> errors,
  ) async {
    final rowErrors = <CSVImportError>[];

    String read(String key) => (row[key] ?? '').trim();

    // Validate required fields
    for (final field in _requiredFields) {
      final value = read(field);
      if (value.isEmpty) {
        rowErrors.add(
          CSVImportError(
            row: rowNum,
            field: field,
            value: value,
            message: 'Field is required',
          ),
        );
      }
    }

    // Parse quantity
    final quantityStr = read('quantity');
    final quantity = int.tryParse(quantityStr);
    if (quantity == null || quantity <= 0) {
      rowErrors.add(
        CSVImportError(
          row: rowNum,
          field: 'quantity',
          value: quantityStr,
          message: 'Quantity must be a positive integer',
        ),
      );
    }

    // Parse eventDate
    final eventDateStr = read('eventDate');
    DateTime? eventDate;
    if (eventDateStr.isNotEmpty) {
      eventDate = DateTime.tryParse(eventDateStr);
      if (eventDate == null) {
        rowErrors.add(
          CSVImportError(
            row: rowNum,
            field: 'eventDate',
            value: eventDateStr,
            message: 'Invalid ISO-8601 date format',
          ),
        );
      }
    }

    if (rowErrors.isNotEmpty) {
      errors.addAll(rowErrors);
      return null;
    }

    return _ParsedAllocationRow(
      rowNumber: rowNum,
      eventId: read('eventId'),
      eventDate: eventDate!,
      siteName: read('siteName'),
      structureName:
          read('structureName').isEmpty ? null : read('structureName'),
      localId: read('localId'),
      recordName: read('recordName').isEmpty ? null : read('recordName'),
      quantity: quantity!,
      eventNotes: read('eventNotes').isEmpty ? null : read('eventNotes'),
      tagId: read('tagId').isEmpty ? null : read('tagId'),
    );
  }

  void _checkEventLevelConflicts(
    _ResolvedEventGroup group,
    _ParsedAllocationRow parsed,
    List<CSVImportError> errors,
  ) {
    // Skip the first row as it sets the canonical values
    if (group.allocations.length <= 1) return;

    // Check eventDate conflict
    if (parsed.eventDate != group.eventDate) {
      errors.add(
        CSVImportError(
          row: parsed.rowNumber,
          field: 'eventDate',
          value: parsed.eventDate.toIso8601String(),
          message:
              'Event date differs from first row for event ${group.eventId}. '
              'Using date from row ${group.canonicalRowNumber}.',
          isWarning: true,
        ),
      );
    }

    // Check siteName conflict
    if (parsed.siteName.toLowerCase() != group.siteName.toLowerCase()) {
      errors.add(
        CSVImportError(
          row: parsed.rowNumber,
          field: 'siteName',
          value: parsed.siteName,
          message:
              'Site name differs from first row for event ${group.eventId}. '
              'Using site from row ${group.canonicalRowNumber}.',
          isWarning: true,
        ),
      );
    }

    // Check eventNotes conflict
    if (parsed.eventNotes != null &&
        group.eventNotes != null &&
        parsed.eventNotes != group.eventNotes) {
      errors.add(
        CSVImportError(
          row: parsed.rowNumber,
          field: 'eventNotes',
          value: parsed.eventNotes!,
          message:
              'Notes differ from first row for event ${group.eventId}. '
              'Using notes from row ${group.canonicalRowNumber}.',
          isWarning: true,
        ),
      );
    }
  }

  Future<Site?> _resolveSiteByName(
    String siteName,
    int rowNum,
    List<CSVImportError> errors,
  ) async {
    final cacheKey = LocalIdMatcher.normalize(siteName);
    if (_siteNameCache.containsKey(cacheKey)) {
      final cached = _siteNameCache[cacheKey];
      if (cached == null) {
        errors.add(
          CSVImportError(
            row: rowNum,
            field: 'siteName',
            value: siteName,
            message: 'Unknown site name',
          ),
        );
      }
      return cached;
    }

    // Query site by name - try exact match first
    final snapshot = await _siteRepository.collectionRef
        .where('name', isEqualTo: siteName)
        .limit(1)
        .get();

    Site? site;
    if (snapshot.docs.isNotEmpty) {
      final data = Map<String, dynamic>.from(snapshot.docs.first.data());
      data['id'] = snapshot.docs.first.id;
      site = Site.fromJson(data);
    }

    // Try normalized fallback if exact match fails
    if (site == null) {
      final allSites = await _siteRepository.collectionRef.get();
      for (final doc in allSites.docs) {
        final data = doc.data();
        final name = (data['name'] ?? '').toString();
        if (LocalIdMatcher.normalize(name) == cacheKey) {
          final siteData = Map<String, dynamic>.from(data);
          siteData['id'] = doc.id;
          site = Site.fromJson(siteData);
          break;
        }
      }
    }

    _siteNameCache[cacheKey] = site;

    if (site == null) {
      errors.add(
        CSVImportError(
          row: rowNum,
          field: 'siteName',
          value: siteName,
          message: 'Unknown site name',
        ),
      );
    }

    return site;
  }

  Future<Group?> _resolveStructureByName(
    String structureName,
    Site site,
    int rowNum,
    List<CSVImportError> errors,
  ) async {
    final normalizedName = LocalIdMatcher.normalize(structureName);
    final cacheKey = '${site.id}:$normalizedName';
    if (_structureNameCache.containsKey(cacheKey)) {
      final cached = _structureNameCache[cacheKey];
      if (cached == null) {
        errors.add(
          CSVImportError(
            row: rowNum,
            field: 'structureName',
            value: structureName,
            message: 'Unknown structure name within site "${site.name}"',
          ),
        );
      }
      return cached;
    }

    // Query group by name within site - try exact match first
    final snapshot = await _groupRepository.collectionRef
        .where('siteId', isEqualTo: site.id)
        .where('name', isEqualTo: structureName)
        .limit(1)
        .get();

    Group? group;
    if (snapshot.docs.isNotEmpty) {
      final data = Map<String, dynamic>.from(snapshot.docs.first.data());
      data['id'] = snapshot.docs.first.id;
      group = Group.fromJson(data);
    }

    // Try normalized fallback if exact match fails
    if (group == null) {
      final siteGroups = await _groupRepository.collectionRef
          .where('siteId', isEqualTo: site.id)
          .get();
      for (final doc in siteGroups.docs) {
        final data = doc.data();
        final name = (data['name'] ?? '').toString();
        if (LocalIdMatcher.normalize(name) == normalizedName) {
          final groupData = Map<String, dynamic>.from(data);
          groupData['id'] = doc.id;
          group = Group.fromJson(groupData);
          break;
        }
      }
    }

    _structureNameCache[cacheKey] = group;

    if (group == null) {
      errors.add(
        CSVImportError(
          row: rowNum,
          field: 'structureName',
          value: structureName,
          message: 'Unknown structure name within site "${site.name}"',
        ),
      );
    }

    return group;
  }

  Future<OrganismRecord?> _resolveOrganismByLocalId(
    String localId,
    int rowNum,
    List<CSVImportError> errors,
  ) async {
    final cacheKey = LocalIdMatcher.normalize(localId);
    if (_localIdCache.containsKey(cacheKey)) {
      final cached = _localIdCache[cacheKey];
      if (cached == null) {
        errors.add(
          CSVImportError(
            row: rowNum,
            field: 'localId',
            value: localId,
            message: 'Unknown organism local ID',
          ),
        );
      }
      return cached;
    }

    // Query organism by localId - try exact match first
    final snapshot = await _organismRecordRepository.collectionRef
        .where('localId', isEqualTo: localId)
        .limit(1)
        .get();

    OrganismRecord? organism;
    if (snapshot.docs.isNotEmpty) {
      final data = Map<String, dynamic>.from(snapshot.docs.first.data());
      data['id'] = snapshot.docs.first.id;
      organism = OrganismRecord.fromJson(data);
    }

    // Try normalized fallback if exact match fails
    if (organism == null) {
      final allOrganisms = await _organismRecordRepository.collectionRef.get();
      for (final doc in allOrganisms.docs) {
        final data = doc.data();
        final orgLocalId = (data['localId'] ?? '').toString();
        if (LocalIdMatcher.normalize(orgLocalId) == cacheKey) {
          final orgData = Map<String, dynamic>.from(data);
          orgData['id'] = doc.id;
          organism = OrganismRecord.fromJson(orgData);
          break;
        }
      }
    }

    _localIdCache[cacheKey] = organism;

    if (organism == null) {
      errors.add(
        CSVImportError(
          row: rowNum,
          field: 'localId',
          value: localId,
          message: 'Unknown organism local ID',
        ),
      );
    }

    return organism;
  }

  Future<OutplantAllocation?> _resolveAllocation(
    _ParsedAllocationRow row,
    Site site,
    List<CSVImportError> errors,
  ) async {
    // Resolve organism by localId
    final organism = await _resolveOrganismByLocalId(
      row.localId,
      row.rowNumber,
      errors,
    );
    if (organism == null) return null;

    // Optionally resolve structure
    Group? structure;
    if (row.structureName != null) {
      structure = await _resolveStructureByName(
        row.structureName!,
        site,
        row.rowNumber,
        errors,
      );
      if (structure == null) return null;
    }

    return OutplantAllocation(
      organismId: organism.id,
      recordName: row.recordName ?? organism.recordName,
      speciesId: organism.speciesId ?? '',
      genetId: GenetIdResolver.resolve(organism),
      quantity: row.quantity,
      sourcePath: organism.urlPath,
      groupId: structure?.id,
      groupName: structure?.name,
      groupPath: structure?.urlPath,
      tagId: row.tagId,
    );
  }
}

/// Parsed row from CSV before name resolution.
class _ParsedAllocationRow {
  const _ParsedAllocationRow({
    required this.rowNumber,
    required this.eventId,
    required this.eventDate,
    required this.siteName,
    this.structureName,
    required this.localId,
    this.recordName,
    required this.quantity,
    this.eventNotes,
    this.tagId,
  });

  final int rowNumber;
  final String eventId;
  final DateTime eventDate;
  final String siteName;
  final String? structureName;
  final String localId;
  final String? recordName;
  final int quantity;
  final String? eventNotes;
  final String? tagId;
}

/// Grouped event with all allocations and resolved references.
class _ResolvedEventGroup {
  _ResolvedEventGroup({
    required this.eventId,
    required this.eventDate,
    required this.siteName,
    this.eventNotes,
    required this.canonicalRowNumber,
  });

  final String eventId;
  final DateTime eventDate;
  final String siteName;
  final String? eventNotes;
  final int canonicalRowNumber;
  final List<_ParsedAllocationRow> allocations = [];
}
