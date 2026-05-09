// @tier: community
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/site.dart';
import 'package:seafoundry_app/repositories/inventory/event_repository.dart';
import 'package:seafoundry_app/repositories/inventory/site_repository.dart';
import 'package:seafoundry_app/services/csv/import/csv_import_models.dart';

class OutplantingCsvImporter {
  OutplantingCsvImporter({
    required EventRepository eventRepository,
    required SiteRepository siteRepository,
  })  : _eventRepository = eventRepository,
        _siteRepository = siteRepository;

  final EventRepository _eventRepository;
  final SiteRepository _siteRepository;

  Future<CSVImportResult> import({
    required List<Map<String, String>> rows,
    bool validateOnly = false,
    Map<String, String>? metadata,
    String? sourceName,
    CsvTranslationSummary? translationSummary,
    int? totalRowCount,
  }) async {
    final errors = <CSVImportError>[];
    final parsedRows = <_OutplantImportRow>[];
    final eventCache = <String, OutplantEvent?>{};
    final siteCache = <String, Site?>{};
    int successCount = 0;

    const requiredFields = <String>{
      'eventId',
      'siteUrlPath',
      'eventDate',
      'totalQuantity',
    };

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final rowNum = i + 2;
      final rowErrors = <CSVImportError>[];

      String read(String key) => (row[key] ?? '').trim();

      final eventId = read('eventId');
      final sitePath = read('siteUrlPath');
      final eventDateStr = read('eventDate');
      final totalQuantityStr = read('totalQuantity');
      final allocationsStr = read('allocations');
      final notes = read('notes');
      final deductStr = read('deductFromInventory').toLowerCase();

      for (final field in requiredFields) {
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

      final totalQuantity = int.tryParse(totalQuantityStr);
      if (totalQuantity == null || totalQuantity < 0) {
        rowErrors.add(
          CSVImportError(
            row: rowNum,
            field: 'totalQuantity',
            value: totalQuantityStr,
            message: 'Total quantity must be a non-negative integer',
          ),
        );
      }

      DateTime? eventDate;
      if (eventDateStr.isNotEmpty) {
        eventDate = DateTime.tryParse(eventDateStr);
        if (eventDate == null) {
          rowErrors.add(
            CSVImportError(
              row: rowNum,
              field: 'eventDate',
              value: eventDateStr,
              message: 'Invalid ISO-8601 date',
            ),
          );
        }
      }

      final event = await _lookupOutplantEvent(eventId, eventCache);
      if (event == null) {
        errors.add(
          CSVImportError(
            row: rowNum,
            field: 'eventId',
            value: eventId,
            message: 'Unknown outplant event identifier',
          ),
        );
        continue;
      }

      final desiredQuantity = totalQuantity ?? event.totalQuantity;
      if (event.totalQuantity != desiredQuantity) {
        rowErrors.add(
          CSVImportError(
            row: rowNum,
            field: 'totalQuantity',
            value: totalQuantityStr,
            message:
                'Total quantity does not match existing allocations (${event.totalQuantity}).',
          ),
        );
      }

      var site = await _lookupSite(sitePath, siteCache);
      if (site == null) {
        final normalizedPath = _normalizeSitePath(sitePath);
        if (normalizedPath != sitePath) {
          site = await _lookupSite(normalizedPath, siteCache);
        }
      }

      site ??= await _lookupSite(_normalizeSitePath(event.urlPath), siteCache);

      if (site == null) {
        rowErrors.add(
          CSVImportError(
            row: rowNum,
            field: 'siteUrlPath',
            value: sitePath,
            message: 'Unknown site path',
          ),
        );
      }

      final expectedAllocations = _buildAllocationSummary(event);
      if (allocationsStr.isNotEmpty &&
          !_allocationSummariesMatch(allocationsStr, expectedAllocations)) {
        rowErrors.add(
          CSVImportError(
            row: rowNum,
            field: 'allocations',
            value: allocationsStr,
            message: 'Allocations summary does not match exported data',
          ),
        );
      }

      if (rowErrors.isNotEmpty) {
        errors.addAll(rowErrors);
        continue;
      }

      parsedRows.add(
        _OutplantImportRow(
          rowNumber: rowNum,
          event: event,
          site: site!,
          eventDate: eventDate ?? DateTime.parse(event.createdAt),
          totalQuantity: desiredQuantity,
          notes: notes.isEmpty ? null : notes,
          deductFromInventory:
              deductStr == 'true' || deductStr == '1' || deductStr == 'yes',
          allocationsSummary: allocationsStr.isEmpty ? null : allocationsStr,
        ),
      );

      successCount++;
    }

    final updatedEvents = <OutplantEvent>[];
    if (!validateOnly && errors.isEmpty) {
      for (final row in parsedRows) {
        try {
          final updated = await _applyOutplantRow(row, sourceName: sourceName);
          updatedEvents.add(updated);
        } catch (e) {
          successCount--;
          errors.add(
            CSVImportError(
              row: row.rowNumber,
              field: 'General',
              value: row.event.id,
              message: 'Failed to apply outplant update: $e',
            ),
          );
        }
      }
    }

    return CSVImportResult(
      totalRows: totalRowCount ?? rows.length,
      successfulImports: successCount,
      errors: errors,
      importedGenets: const [],
      importedOrganisms: const [],
      updatedOutplantEvents: updatedEvents,
      translationSummary: translationSummary,
    );
  }

  Future<Site?> _lookupSite(String urlPath, Map<String, Site?> cache) async {
    if (cache.containsKey(urlPath)) return cache[urlPath];
    final snapshot = await _siteRepository.collectionRef
        .where('urlPath', isEqualTo: urlPath)
        .limit(1)
        .get();
    Site? site;
    if (snapshot.docs.isNotEmpty) {
      final data = Map<String, dynamic>.from(snapshot.docs.first.data());
      data['id'] = snapshot.docs.first.id;
      site = Site.fromJson(data);
    }
    cache[urlPath] = site;
    return site;
  }

  Future<OutplantEvent?> _lookupOutplantEvent(
    String eventId,
    Map<String, OutplantEvent?> cache,
  ) async {
    if (cache.containsKey(eventId)) return cache[eventId];
    final record = await _eventRepository.getRecordForId(eventId);
    final outplant = record is OutplantEvent ? record : null;
    cache[eventId] = outplant;
    return outplant;
  }

  Future<OutplantEvent> _applyOutplantRow(
    _OutplantImportRow row, {
    String? sourceName,
  }) async {
    var event = row.event;
    var updated = event;
    var mutated = false;

    if (event.siteId != row.site.id) {
      updated = updated.copyWith(
        siteId: row.site.id,
        recordId: row.site.id,
        urlPath: _normalizeEventUrlPath(row.site.urlPath, event.slug),
        internalPath: '${row.site.internalPath}/${event.id}',
      );
      mutated = true;
    }

    final eventDateIso = row.eventDate.toIso8601String();
    if (event.createdAt != eventDateIso) {
      updated = updated.copyWith(createdAt: eventDateIso);
      mutated = true;
    }

    final desiredComment = row.notes ?? '';
    if ((event.comment ?? '') != desiredComment) {
      updated = updated.copyWith(comment: row.notes);
      mutated = true;
    }

    if (mutated) {
      updated = updated.copyWith(
        updatedAt: DateTime.now().toIso8601String(),
        updatedById: _eventRepository.user.id,
      );
      await _eventRepository.updateRecord(updated);
      event = updated;
    }

    return event;
  }

  String _normalizeSitePath(String sitePath) {
    final normalized = sitePath.trim();
    if (normalized.isEmpty) return normalized;
    final segments = normalized.split('/');
    if (segments.length <= 2) return normalized;
    return segments.sublist(0, segments.length - 1).join('/');
  }

  String _normalizeEventUrlPath(String eventUrlPath, String eventSlug) {
    final normalized = eventUrlPath.trim();
    if (normalized.endsWith('/$eventSlug')) {
      return normalized;
    }
    return '$normalized/$eventSlug';
  }

  String _buildAllocationSummary(OutplantEvent event) {
    return event.allocations
        .map((allocation) {
          final tagId = allocation.tagId;
          final quantity = allocation.quantity.toString();
          final source = allocation.sourcePath;
          if (source.isEmpty) return '$tagId:$quantity';
          return '$tagId:$quantity@$source';
        })
        .where((value) => value.isNotEmpty)
        .join('; ');
  }

  bool _allocationSummariesMatch(String a, String b) {
    String normalize(String input) =>
        input.replaceAll(RegExp(r'\s+'), '').toLowerCase();
    return normalize(a) == normalize(b);
  }
}

class _OutplantImportRow {
  const _OutplantImportRow({
    required this.rowNumber,
    required this.event,
    required this.site,
    required this.eventDate,
    required this.totalQuantity,
    required this.notes,
    required this.deductFromInventory,
    required this.allocationsSummary,
  });

  final int rowNumber;
  final OutplantEvent event;
  final Site site;
  final DateTime eventDate;
  final int totalQuantity;
  final String? notes;
  final bool deductFromInventory;
  final String? allocationsSummary;
}
