// @tier: community
import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:seafoundry_app/models/events/events.dart';
import 'package:seafoundry_app/models/genet.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/site.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/repositories/record_repository.dart';
import 'package:seafoundry_app/services/genet_id_resolver.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/models/provenance_life_stage_selection.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/utils/provenance_selection_utils.dart';

class EventTaxonomy {
  const EventTaxonomy({
    this.speciesId,
    this.genetId,
    this.provenanceTypeId,
    this.physicalFormId,
    this.siteId,
    this.siteName,
    this.lifeStageId,
    this.provenanceType,
  });

  final String? speciesId;
  final String? genetId;
  final String? provenanceTypeId;
  final String? physicalFormId;
  final String? siteId;
  final String? siteName;
  final String? lifeStageId;
  final String? provenanceType;
}

@visibleForTesting
class HusbandryEventTaxonomyResolver {
  const HusbandryEventTaxonomyResolver._();

  static Future<EventTaxonomy> resolve({
    required Event event,
    required RecordRepository recordRepository,
    required String? organizationId,
    Map<String, OrganismRecord?>? organismCache,
    Map<String, Genet?>? genetCache,
    Map<String, Site?>? siteCache,
  }) async {
    final organismStore = organismCache ?? <String, OrganismRecord?>{};
    final genetStore = genetCache ?? <String, Genet?>{};
    final siteStore = siteCache ?? <String, Site?>{};

    final taxonomyFromEvent = await _taxonomyFromEvent(
      event: event,
      recordRepository: recordRepository,
      organizationId: organizationId,
      organismStore: organismStore,
      genetStore: genetStore,
      siteStore: siteStore,
    );
    if (taxonomyFromEvent != null) {
      return taxonomyFromEvent;
    }

    return _taxonomyFromMetadata(
      event,
      recordRepository,
      siteStore,
    );
  }

  static Future<EventTaxonomy?> _taxonomyFromEvent({
    required Event event,
    required RecordRepository recordRepository,
    required String? organizationId,
    required Map<String, OrganismRecord?> organismStore,
    required Map<String, Genet?> genetStore,
    required Map<String, Site?> siteStore,
  }) async {
    if (event is InventoryEvent) {
      final snapshot = event.snapshot;
      if (snapshot is OrganismRecord) {
        final siteId = snapshot.siteId;
        final site = siteId != null && siteId.isNotEmpty
            ? await _loadSite(siteId, recordRepository, siteStore)
            : null;
        final genetId = GenetIdResolver.resolve(snapshot);
        final genet = genetId != null && genetId.isNotEmpty
            ? await _loadGenet(
                genetId,
                recordRepository,
                genetStore,
                organizationId: organizationId,
              )
            : null;
        final selection = buildProvenanceSelection(
          organism: snapshot,
          provenance: genet,
        );
        return EventTaxonomy(
          speciesId: snapshot.speciesId,
          genetId: genetId,
          provenanceTypeId: genet?.provenanceTypeId,
          physicalFormId: snapshot.physicalForm?.formId,
          siteId: siteId,
          siteName: site?.name,
          lifeStageId: selection.lifeStage.id,
          provenanceType: selection.provenanceType.id,
        );
      }
      if (snapshot is Genet) {
        final selection = ProvenanceLifeStageSelection.fromGenet(snapshot);
        return EventTaxonomy(
          speciesId: snapshot.speciesId,
          genetId: snapshot.id,
          provenanceTypeId: snapshot.provenanceTypeId,
          lifeStageId: selection.lifeStage.id,
          provenanceType: selection.provenanceType.id,
        );
      }
    }

    if (event is TransferEvent && (event.genetId?.isNotEmpty ?? false)) {
      final genetId = event.genetId!;
      final genet = await _loadGenet(
        genetId,
        recordRepository,
        genetStore,
        organizationId: organizationId,
      );
      final selection = genet != null
          ? ProvenanceLifeStageSelection.fromGenet(genet)
          : null;
      return EventTaxonomy(
        speciesId: genet?.speciesId,
        genetId: genetId,
        provenanceTypeId: genet?.provenanceTypeId,
        lifeStageId: selection?.lifeStage.id,
        provenanceType: selection?.provenanceType.id,
      );
    }

    switch (event.recordModelType) {
      case ModelType.organismRecord:
        if (event.recordId.isEmpty) return null;
        final organism = await _loadOrganism(
          event.recordId,
          recordRepository,
          organismStore,
          organizationId: organizationId,
        );
        if (organism == null) return null;
        final siteId = organism.siteId;
        final site = siteId != null && siteId.isNotEmpty
            ? await _loadSite(siteId, recordRepository, siteStore)
            : null;
        final genetId = GenetIdResolver.resolve(organism);
        final genet = genetId != null && genetId.isNotEmpty
            ? await _loadGenet(
                genetId,
                recordRepository,
                genetStore,
                organizationId: organizationId,
              )
            : null;
        final orgSelection = buildProvenanceSelection(
          organism: organism,
          provenance: genet,
        );
        return EventTaxonomy(
          speciesId: organism.speciesId,
          genetId: genetId,
          provenanceTypeId: genet?.provenanceTypeId,
          physicalFormId: organism.physicalForm?.formId,
          siteId: organism.siteId,
          siteName: site?.name,
          lifeStageId: orgSelection.lifeStage.id,
          provenanceType: orgSelection.provenanceType.id,
        );
      case ModelType.genet:
        if (event.recordId.isEmpty) return null;
        final genet = await _loadGenet(
          event.recordId,
          recordRepository,
          genetStore,
          organizationId: organizationId,
        );
        if (genet == null) return null;
        final genetSelection = ProvenanceLifeStageSelection.fromGenet(genet);
        return EventTaxonomy(
          speciesId: genet.speciesId,
          genetId: genet.id,
          provenanceTypeId: genet.provenanceTypeId,
          lifeStageId: genetSelection.lifeStage.id,
          provenanceType: genetSelection.provenanceType.id,
        );
      default:
        return null;
    }
  }

  static Future<EventTaxonomy> _taxonomyFromMetadata(
    Event event,
    RecordRepository recordRepository,
    Map<String, Site?> siteStore,
  ) async {
    final metadata = event.metadata;
    if (metadata == null || metadata.isEmpty) {
      return const EventTaxonomy();
    }

    final speciesId = _metadataString(metadata, 'speciesId');
    final provenanceTypeId = _metadataString(metadata, 'provenanceTypeId');
    final physicalFormId = _metadataString(metadata, 'physicalFormId');
    final siteId = _metadataString(metadata, 'siteId');
    final siteName = _metadataString(metadata, 'siteName');
    final lifeStageId = _metadataString(metadata, 'lifeStageId');
    final provenanceType = _metadataString(metadata, 'provenanceType');

    Site? site;
    if (siteId != null && siteId.isNotEmpty) {
      site = await _loadSite(siteId, recordRepository, siteStore);
    }

    return EventTaxonomy(
      speciesId: speciesId,
      provenanceTypeId: provenanceTypeId,
      physicalFormId: physicalFormId,
      siteId: siteId ?? site?.id,
      siteName: site?.name ?? siteName,
      lifeStageId: lifeStageId,
      provenanceType: provenanceType,
    );
  }

  static Future<OrganismRecord?> _loadOrganism(
    String id,
    RecordRepository recordRepository,
    Map<String, OrganismRecord?> cache, {
    String? organizationId,
  }) async {
    if (cache.containsKey(id)) {
      return cache[id];
    }
    try {
      final organism = await recordRepository.getRecord<OrganismRecord>(
        ModelType.organismRecord,
        id,
        organizationId: organizationId,
      );
      cache[id] = organism;
      return organism;
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'Failed to load organism $id for husbandry event taxonomy',
        error,
        stackTrace,
      );
      cache[id] = null;
      return null;
    }
  }

  static Future<Genet?> _loadGenet(
    String id,
    RecordRepository recordRepository,
    Map<String, Genet?> cache, {
    String? organizationId,
  }) async {
    if (cache.containsKey(id)) {
      return cache[id];
    }
    try {
      final genet = await recordRepository.getRecord<Genet>(
        ModelType.genet,
        id,
        organizationId: organizationId,
      );
      cache[id] = genet;
      return genet;
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'Failed to load genet $id for husbandry event taxonomy',
        error,
        stackTrace,
      );
      cache[id] = null;
      return null;
    }
  }

  static Future<Site?> _loadSite(
    String id,
    RecordRepository recordRepository,
    Map<String, Site?> cache,
  ) async {
    if (cache.containsKey(id)) {
      return cache[id];
    }
    try {
      final site = await recordRepository.getRecord<Site>(ModelType.site, id);
      cache[id] = site;
      return site;
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'Failed to load site $id for husbandry event taxonomy',
        error,
        stackTrace,
      );
      cache[id] = null;
      return null;
    }
  }

  static String? _metadataString(Map<String, dynamic> metadata, String key) {
    final value = metadata[key] ?? metadata[_snakeCase(key)];
    return _stringValue(value);
  }

  static String _snakeCase(String input) {
    return input.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => '_${match.group(0)!.toLowerCase()}',
    );
  }

  static String? _stringValue(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    final converted = value.toString().trim();
    return converted.isEmpty ? null : converted;
  }
}

Future<Map<String, EventTaxonomy>> buildHusbandryTaxonomyIndex({
  required List<Event> events,
  required RecordRepository recordRepository,
}) async {
  final index = <String, EventTaxonomy>{};
  final organismCache = <String, OrganismRecord?>{};
  final genetCache = <String, Genet?>{};
  final siteCache = <String, Site?>{};

  await Future.wait(
    events.map((event) async {
      index[event.id] = await HusbandryEventTaxonomyResolver.resolve(
        event: event,
        recordRepository: recordRepository,
        organizationId: event.organizationId,
        organismCache: organismCache,
        genetCache: genetCache,
        siteCache: siteCache,
      );
    }),
  );

  return index;
}
