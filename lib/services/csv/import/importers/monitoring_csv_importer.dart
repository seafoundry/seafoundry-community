// @tier: community
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/monitoring_event_record.dart';
import 'package:seafoundry_app/models/monitoring/monitoring_entry.dart';
import 'package:seafoundry_app/models/site.dart';
// Morphology is stored separately from physical forms (inventory).
import 'package:seafoundry_app/repositories/inventory/event_repository.dart';
import 'package:seafoundry_app/repositories/inventory/site_repository.dart';
import 'package:seafoundry_app/services/csv/import/csv_import_models.dart';

class MonitoringCsvImporter {
  MonitoringCsvImporter({
    required EventRepository eventRepository,
    required SiteRepository siteRepository,
  }) : _eventRepository = eventRepository,
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
    final createdEvents = <MonitoringEventRecord>[];
    final updatedEvents = <MonitoringEventRecord>[];
    final eventCache = <String, MonitoringEventRecord?>{};
    final outplantEventCache = <String, OutplantEvent?>{};
    final siteCache = <String, Site?>{};
    int successCount = 0;
    var unknownRecordCounter = 0;

    const requiredFields = <String>{
      'monitoringDate',
      'percentCover',
      'percentBleaching',
      'percentDisease',
    };

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final rowNum = i + 2;
      final rowErrors = <CSVImportError>[];

      String read(String key) => (row[key] ?? '').trim();
      String readRecordName() {
        final explicit = read('recordName');
        if (explicit.isNotEmpty) return explicit;
        unknownRecordCounter += 1;
        return 'Unknown $unknownRecordCounter';
      }

      final monitoringId = read('monitoringId');
      final eventId = monitoringId.isNotEmpty ? monitoringId : read('eventId');
      final eventIdField = monitoringId.isNotEmpty ? 'monitoringId' : 'eventId';
      final sitePath = read('siteUrlPath');
      final outplantEventIdRaw = read('outplantEventId');
      final monitoringDateRaw = read('monitoringDate');
      final percentCoverRaw = read('percentCover');
      final percentBleachingRaw = read('percentBleaching');
      final percentDiseaseRaw = read('percentDisease');
      final healthIssueTypeId = read('healthIssueTypeId');
      final imageUrl = read('imageUrl');
      final notes = read('notes');
      final ageDaysRaw = read('ageDays');
      final ageMonthsRaw = read('ageMonths');
      final tagIdRaw = read('tagId');
      final recordName = readRecordName();
      final morphologyRaw = _readMorphologyValue(row);
      final physicalFormRaw = _readPhysicalFormValue(row);
      final sizeBandRaw = _readSizeBandValue(row);

      final volumeMm3Raw = read('estimatedVolumeMm3');
      final growthDeltaRaw = read('growthDeltaMm3');
      final growthPercentRaw = read('growthPercentChange');
      final growthPerDayRaw = read('growthPerDayMm3');

      MonitoringEventRecord? existingEvent;
      if (eventId.isNotEmpty) {
        existingEvent = await _lookupMonitoringEvent(eventId, eventCache);
        if (existingEvent == null) {
          rowErrors.add(
            CSVImportError(
              row: rowNum,
              field: eventIdField,
              value: eventId,
              message: 'Unknown monitoring event identifier',
            ),
          );
        }
      }

      final resolvedOutplantEventId = outplantEventIdRaw.isNotEmpty
          ? outplantEventIdRaw
          : existingEvent?.outplantEventId;
      if (resolvedOutplantEventId == null || resolvedOutplantEventId.isEmpty) {
        rowErrors.add(
          CSVImportError(
            row: rowNum,
            field: 'outplantEventId',
            value: outplantEventIdRaw,
            message:
                'Monitoring rows must reference an existing outplant event (outplantEventId).',
          ),
        );
      }

      OutplantEvent? outplantEvent;
      if (resolvedOutplantEventId != null &&
          resolvedOutplantEventId.isNotEmpty) {
        outplantEvent = await _lookupOutplantEvent(
          resolvedOutplantEventId,
          outplantEventCache,
        );
        if (outplantEvent == null) {
          rowErrors.add(
            CSVImportError(
              row: rowNum,
              field: 'outplantEventId',
              value: resolvedOutplantEventId,
              message: 'Unknown outplant event identifier',
            ),
          );
        } else if (existingEvent != null &&
            existingEvent.outplantEventId != null &&
            existingEvent.outplantEventId != resolvedOutplantEventId) {
          rowErrors.add(
            CSVImportError(
              row: rowNum,
              field: 'outplantEventId',
              value: resolvedOutplantEventId,
              message:
                  'Outplant event does not match existing monitoring event.',
            ),
          );
        }
      }

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

      DateTime? monitoringDate;
      if (monitoringDateRaw.isNotEmpty) {
        monitoringDate = DateTime.tryParse(monitoringDateRaw);
        if (monitoringDate == null) {
          rowErrors.add(
            CSVImportError(
              row: rowNum,
              field: 'monitoringDate',
              value: monitoringDateRaw,
              message: 'Invalid ISO-8601 date',
            ),
          );
        }
      }

      double? parsePercent(String raw) {
        final normalized = raw.trim();
        if (normalized.isEmpty) {
          return null;
        }
        return double.tryParse(normalized);
      }

      final percentCover = parsePercent(percentCoverRaw);
      final percentBleaching = parsePercent(percentBleachingRaw);
      final percentDisease = parsePercent(percentDiseaseRaw);

      if (percentCover == null) {
        rowErrors.add(
          CSVImportError(
            row: rowNum,
            field: 'percentCover',
            value: percentCoverRaw,
            message: 'Percent cover must be numeric',
          ),
        );
      }
      if (percentBleaching == null) {
        rowErrors.add(
          CSVImportError(
            row: rowNum,
            field: 'percentBleaching',
            value: percentBleachingRaw,
            message: 'Percent bleaching must be numeric',
          ),
        );
      }
      if (percentDisease == null) {
        rowErrors.add(
          CSVImportError(
            row: rowNum,
            field: 'percentDisease',
            value: percentDiseaseRaw,
            message: 'Percent disease must be numeric',
          ),
        );
      }

      double? ageDays;
      if (ageDaysRaw.isNotEmpty) {
        ageDays = double.tryParse(ageDaysRaw);
        if (ageDays == null) {
          rowErrors.add(
            CSVImportError(
              row: rowNum,
              field: 'ageDays',
              value: ageDaysRaw,
              message: 'Age (days) must be numeric',
            ),
          );
        }
      }

      double? ageMonths;
      if (ageMonthsRaw.isNotEmpty) {
        ageMonths = double.tryParse(ageMonthsRaw);
        if (ageMonths == null) {
          rowErrors.add(
            CSVImportError(
              row: rowNum,
              field: 'ageMonths',
              value: ageMonthsRaw,
              message: 'Age (months) must be numeric',
            ),
          );
        }
      }

      if (sitePath.isEmpty && existingEvent == null) {
        rowErrors.add(
          CSVImportError(
            row: rowNum,
            field: 'siteUrlPath',
            value: sitePath,
            message: 'Site path is required when creating monitoring events',
          ),
        );
      }

      double? volumeMm3;
      if (volumeMm3Raw.isNotEmpty) {
        volumeMm3 = double.tryParse(volumeMm3Raw);
        if (volumeMm3 == null) {
          rowErrors.add(
            CSVImportError(
              row: rowNum,
              field: 'estimatedVolumeMm3',
              value: volumeMm3Raw,
              message: 'Estimated volume must be numeric',
            ),
          );
        }
      }

      double? growthDeltaMm3;
      if (growthDeltaRaw.isNotEmpty) {
        growthDeltaMm3 = double.tryParse(growthDeltaRaw);
        if (growthDeltaMm3 == null) {
          rowErrors.add(
            CSVImportError(
              row: rowNum,
              field: 'growthDeltaMm3',
              value: growthDeltaRaw,
              message: 'Growth delta must be numeric',
            ),
          );
        }
      }

      double? growthPercentChange;
      if (growthPercentRaw.isNotEmpty) {
        growthPercentChange = double.tryParse(growthPercentRaw);
        if (growthPercentChange == null) {
          rowErrors.add(
            CSVImportError(
              row: rowNum,
              field: 'growthPercentChange',
              value: growthPercentRaw,
              message: 'Growth percent must be numeric',
            ),
          );
        }
      }

      double? growthPerDayMm3;
      if (growthPerDayRaw.isNotEmpty) {
        growthPerDayMm3 = double.tryParse(growthPerDayRaw);
        if (growthPerDayMm3 == null) {
          rowErrors.add(
            CSVImportError(
              row: rowNum,
              field: 'growthPerDayMm3',
              value: growthPerDayRaw,
              message: 'Growth per day must be numeric',
            ),
          );
        }
      }

      if (rowErrors.isNotEmpty) {
        errors.addAll(rowErrors);
        continue;
      }

      if (validateOnly) {
        successCount++;
        continue;
      }

      try {
        final measurements = <String, dynamic>{};
        if (ageDays != null) {
          measurements['ageDays'] = ageDays;
        }
        if (ageMonths != null) {
          measurements['ageMonths'] = ageMonths;
        }
        if (sizeBandRaw.isNotEmpty) {
          measurements['sizeBandId'] = sizeBandRaw;
        }
        if (volumeMm3 != null) {
          measurements['estimatedVolumeMm3'] = volumeMm3;
        }
        if (growthDeltaMm3 != null) {
          measurements['growthDeltaMm3'] = growthDeltaMm3;
        }
        if (growthPercentChange != null) {
          measurements['growthPercentChange'] = growthPercentChange;
        }
        if (growthPerDayMm3 != null) {
          measurements['growthPerDayMm3'] = growthPerDayMm3;
        }
        final bool hasTagId = tagIdRaw.isNotEmpty;
        final bool hasMorphology = morphologyRaw.isNotEmpty;
        final bool hasPhysicalForm = physicalFormRaw.isNotEmpty;
        final bool hasAdditionalMeasurements = measurements.isNotEmpty;
        measurements['recordName'] = recordName;
        if (hasTagId) {
          measurements['tagId'] = tagIdRaw;
        }
        if (hasPhysicalForm) {
          measurements['physicalFormId'] = physicalFormRaw;
        }
        final String? parsedMorphology = morphologyRaw.isNotEmpty
            ? morphologyRaw.toLowerCase().replaceAll(' ', '_')
            : null;
        if (parsedMorphology != null) {
          measurements['morphologyId'] = parsedMorphology;
        }

        Site? site;
        if (sitePath.isNotEmpty) {
          site = await _lookupSite(sitePath, siteCache);
          if (site == null) {
            final normalizedPath = _normalizeSitePath(sitePath);
            if (normalizedPath != sitePath) {
              site = await _lookupSite(normalizedPath, siteCache);
            }
          }
        }

        if (existingEvent != null) {
          var updatedEntries = existingEvent.entries;
          if ((hasTagId ||
                  hasMorphology ||
                  hasPhysicalForm ||
                  hasAdditionalMeasurements) &&
              updatedEntries.isEmpty) {
            updatedEntries = [
              MonitoringEntry(
                genetId: (existingEvent.organismIds?.isNotEmpty ?? false)
                    ? existingEvent.organismIds!.first
                    : '',
                tagId: hasTagId ? tagIdRaw : null,
                physicalForm: hasPhysicalForm
                    ? physicalFormRaw.toLowerCase().replaceAll(' ', '_')
                    : null,
                morphologyId: parsedMorphology,
                healthStatus: existingEvent.healthStatus,
                percentCover: percentCover,
                percentBleaching: percentBleaching,
                percentDisease: percentDisease,
                measurements: measurements.isNotEmpty
                    ? Map<String, dynamic>.from(measurements)
                    : null,
              ),
            ];
          } else if (updatedEntries.isNotEmpty &&
              (hasTagId ||
                  hasMorphology ||
                  hasPhysicalForm ||
                  hasAdditionalMeasurements)) {
            updatedEntries = updatedEntries
                .map(
                  (entry) => entry.copyWith(
                    tagId: hasTagId ? tagIdRaw : entry.tagId,
                    physicalForm: hasPhysicalForm
                        ? physicalFormRaw.toLowerCase().replaceAll(' ', '_')
                        : entry.physicalForm,
                    morphologyId: hasMorphology
                        ? parsedMorphology
                        : entry.morphologyId,
                    measurements: measurements.isNotEmpty
                        ? {...?entry.measurements, ...measurements}
                        : entry.measurements,
                  ),
                )
                .toList(growable: false);
          }

          final updated = existingEvent.copyWith(
            percentCover: percentCover,
            percentBleaching: percentBleaching,
            percentDisease: percentDisease,
            healthIssueTypeId: healthIssueTypeId.isNotEmpty
                ? healthIssueTypeId
                : null,
            imageUrl: imageUrl.isNotEmpty ? imageUrl : existingEvent.imageUrl,
            comment: notes.isNotEmpty ? notes : existingEvent.comment,
            notes: notes.isNotEmpty ? notes : existingEvent.notes,
            monitoringDate: monitoringDate ?? existingEvent.monitoringDate,
            measurements: measurements.isNotEmpty
                ? {...?existingEvent.measurements, ...measurements}
                : existingEvent.measurements,
            updatedAt: DateTime.now().toIso8601String(),
            updatedById: _eventRepository.user.id,
            recordId: site?.id ?? existingEvent.recordId,
            recordModelType: site != null
                ? site.modelType
                : existingEvent.recordModelType,
            entries: updatedEntries,
            totalCount: updatedEntries.isNotEmpty
                ? updatedEntries.length
                : existingEvent.totalCount,
            outplantEventId: outplantEvent?.id ?? existingEvent.outplantEventId,
            outplantEventName:
                outplantEvent?.name ?? existingEvent.outplantEventName,
          );

          await _eventRepository.updateRecord(updated);
          updatedEvents.add(updated);
        } else {
          if (site == null) {
            errors.add(
              CSVImportError(
                row: rowNum,
                field: 'siteUrlPath',
                value: sitePath,
                message: 'Unknown site path',
              ),
            );
            continue;
          }

          final List<MonitoringEntry> createdEntries;
          if (hasTagId || hasMorphology || hasPhysicalForm) {
            createdEntries = [
              MonitoringEntry(
                genetId: '',
                tagId: hasTagId ? tagIdRaw : null,
                physicalForm: hasPhysicalForm
                    ? physicalFormRaw.toLowerCase().replaceAll(' ', '_')
                    : null,
                morphologyId: parsedMorphology,
                measurements: measurements.isNotEmpty
                    ? Map<String, dynamic>.from(measurements)
                    : null,
              ),
            ];
          } else {
            createdEntries = const [];
          }

          var created = await _eventRepository.createMonitoringEvent(
            forRecord: site,
            comment: notes.isNotEmpty ? notes : null,
            imageUrl: imageUrl.isNotEmpty ? imageUrl : null,
            percentCover: percentCover,
            percentBleaching: percentBleaching,
            percentDisease: percentDisease,
            healthIssueTypeId: healthIssueTypeId.isNotEmpty
                ? healthIssueTypeId
                : null,
            monitoringDate: monitoringDate,
            measurements: measurements.isNotEmpty ? measurements : null,
            entries: createdEntries,
            totalCount: createdEntries.isNotEmpty
                ? createdEntries.length
                : null,
          );

          created = created.copyWith(
            outplantEventId: outplantEvent?.id,
            outplantEventName: outplantEvent?.name,
          );

          if (notes.isNotEmpty || measurements.isNotEmpty) {
            created = created.copyWith(
              notes: notes.isNotEmpty ? notes : created.notes,
              measurements: measurements.isNotEmpty
                  ? {...?created.measurements, ...measurements}
                  : created.measurements,
            );
          }
          await _eventRepository.updateRecord(created);

          createdEvents.add(created);
        }

        successCount++;
      } catch (e) {
        errors.add(
          CSVImportError(
            row: rowNum,
            field: 'General',
            value: eventId.isEmpty ? sitePath : eventId,
            message: 'Failed to apply monitoring update: $e',
          ),
        );
      }
    }

    return CSVImportResult(
      totalRows: totalRowCount ?? rows.length,
      successfulImports: successCount,
      errors: errors,
      importedGenets: const [],
      importedOrganisms: const [],
      updatedOutplantEvents: const [],
      createdMonitoringEvents: createdEvents,
      updatedMonitoringEvents: updatedEvents,
      translationSummary: translationSummary,
    );
  }

  Future<OutplantEvent?> _lookupOutplantEvent(
    String eventId,
    Map<String, OutplantEvent?> cache,
  ) async {
    if (eventId.isEmpty) return null;
    if (cache.containsKey(eventId)) return cache[eventId];
    final record = await _eventRepository.getRecordForId(eventId);
    final outplant = record is OutplantEvent ? record : null;
    cache[eventId] = outplant;
    return outplant;
  }

  Future<MonitoringEventRecord?> _lookupMonitoringEvent(
    String eventId,
    Map<String, MonitoringEventRecord?> cache,
  ) async {
    if (eventId.isEmpty) return null;
    if (cache.containsKey(eventId)) return cache[eventId];

    final doc = await _eventRepository.collectionRef.doc(eventId).get();
    MonitoringEventRecord? event;
    final data = doc.data();
    if (doc.exists && data != null) {
      event = MonitoringEventRecord.fromJson(Map<String, dynamic>.from(data));
    }
    cache[eventId] = event;
    return event;
  }

  String _readMorphologyValue(Map<String, String> row) {
    for (final key in ['morphologyId', 'morphology']) {
      final value = row[key];
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }

  String _readPhysicalFormValue(Map<String, String> row) {
    for (final key in ['physicalFormId', 'physicalForm']) {
      final value = row[key];
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }

  String _readSizeBandValue(Map<String, String> row) {
    for (final key in ['sizeBandId', 'sizeBand']) {
      final value = row[key];
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
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

  String _normalizeSitePath(String sitePath) {
    final normalized = sitePath.trim();
    if (normalized.isEmpty) return normalized;
    final segments = normalized.split('/');
    if (segments.length <= 2) return normalized;
    return segments.sublist(0, segments.length - 1).join('/');
  }
}
