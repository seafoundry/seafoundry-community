import 'package:seafoundry_app/models/alias.dart';
import 'package:seafoundry_app/models/genet.dart';
import 'package:seafoundry_app/models/inventory/physical_form_config.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/inventory/size_spec.dart';
import 'package:seafoundry_app/models/population_measurement.dart';
import 'package:seafoundry_app/models/types/health_status.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/services/csv/import/importers/inventory/inventory_import_row.dart';
import 'package:seafoundry_app/services/genet_id_resolver.dart';

/// Applies metadata updates to organism records during CSV import.
///
/// Handles field-by-field comparison and update logic for organism records,
/// including group assignment, species, health status, size spec, genet, and aliases.
class OrganismMetadataUpdater {
  OrganismMetadataUpdater({
    required OrganismRecordRepository organismRecordRepository,
  }) : _organismRecordRepository = organismRecordRepository;

  final OrganismRecordRepository _organismRecordRepository;

  /// Applies the import row changes to the organism record.
  ///
  /// Returns the updated organism, or the original if no changes were needed.
  Future<OrganismRecord?> applyInventoryRow(
    InventoryImportRow row, {
    String? sourceName,
  }) async {
    var organism = row.organism;
    var updated = organism;
    var mutated = false;

    // Extract current metadata values
    final currentValues = _extractCurrentValues(organism);

    // Apply group change
    if (row.targetGroup.id != organism.groupId) {
      updated = updated.copyWith(
        groupId: row.targetGroup.id,
        siteId: row.targetGroup.siteId,
      );
      mutated = true;
    }

    // Apply local ID change
    if (row.localGenetId.isNotEmpty && row.localGenetId != (organism.localGenetId ?? '')) {
      updated = updated.copyWith(localGenetId: row.localGenetId);
      mutated = true;
    }

    // Apply species change
    if (row.speciesId.isNotEmpty && row.speciesId != organism.speciesId) {
      updated = updated.copyWith(speciesId: row.speciesId);
      mutated = true;
    }

    // Apply record name change
    final nextName = row.tagId.trim();
    if (nextName.isNotEmpty && nextName != currentValues.tagId) {
      updated = updated.copyWith(tagId: nextName);
      mutated = true;
    }

    final incomingSizeBandId = row.sizeSpec.sizeBandId;
    final shouldUpdatePhysicalForm = row.physicalFormId.isNotEmpty &&
        (row.physicalFormId != currentValues.formId ||
            (incomingSizeBandId != null &&
                incomingSizeBandId.isNotEmpty &&
                incomingSizeBandId != currentValues.sizeBandId));
    if (shouldUpdatePhysicalForm) {
      updated = _updateMetadata(
        updated,
        physicalFormId: row.physicalFormId,
        sizeBandId: incomingSizeBandId,
        healthStatus: currentValues.healthStatus,
        notes: currentValues.notes,
        readyForPropagation: currentValues.readyForPropagation,
        readyForOutplant: currentValues.readyForOutplant,
        genetRecordId: currentValues.genetRecordId,
      );
      mutated = true;
    }

    // Apply genet change
    if (row.updateGenet &&
        row.genet != null &&
        row.genet!.id != currentValues.genetRecordId) {
      updated = _applyGenetUpdate(updated, row.genet!);
      mutated = true;
    }

    // Apply size spec change
    if (row.updateSizeSpec && row.sizeSpec != currentValues.sizeSpec) {
      updated = _updateMetadata(
        updated,
        physicalFormId: updated.physicalForm?.formId ??
            currentValues.formId ??
            row.physicalFormId,
        sizeBandId: row.sizeSpec.sizeBandId,
        sizeSpec: row.sizeSpec,
        healthStatus: currentValues.healthStatus,
        notes: currentValues.notes,
        readyForPropagation: currentValues.readyForPropagation,
        readyForOutplant: currentValues.readyForOutplant,
        genetRecordId: currentValues.genetRecordId,
      );
      mutated = true;
    }

    // Apply health status change
    if (row.updateHealthStatus &&
        row.healthStatus != null &&
        row.healthStatus != currentValues.healthStatus) {
      updated = _updateMetadata(
        updated,
        physicalFormId: updated.physicalForm?.formId ??
            currentValues.formId ??
            row.physicalFormId,
        sizeBandId: updated.physicalForm?.sizeBandId,
        healthStatus: row.healthStatus!,
        notes: currentValues.notes,
        readyForPropagation: currentValues.readyForPropagation,
        readyForOutplant: currentValues.readyForOutplant,
        genetRecordId: currentValues.genetRecordId,
      );
      mutated = true;
    }

    // Apply notes change
    if (row.shouldUpdateNotes) {
      final desiredNotes = row.notes ?? '';
      if ((currentValues.notes ?? '') != desiredNotes) {
        updated = _updateMetadata(
          updated,
          physicalFormId: updated.physicalForm?.formId ??
              currentValues.formId ??
              row.physicalFormId,
          sizeBandId: updated.physicalForm?.sizeBandId,
          healthStatus: currentValues.healthStatus,
          notes: desiredNotes,
          readyForPropagation: currentValues.readyForPropagation,
          readyForOutplant: currentValues.readyForOutplant,
          genetRecordId: currentValues.genetRecordId,
        );
        mutated = true;
      }
    }

    // Apply aliases change
    if (row.aliases.isNotEmpty) {
      final aliasesChanged = _haveAliasesChanged(organism.aliases, row.aliases);
      if (aliasesChanged) {
        updated = updated.copyWith(aliases: row.aliases);
        mutated = true;
      }
    }

    // Apply population measurement change
    if (row.populationMeasurement != null &&
        row.populationMeasurement != organism.measurement) {
      updated = updated.copyWith(measurement: row.populationMeasurement!);
      mutated = true;
    }

    // Persist changes
    if (mutated) {
      organism = await _persistChanges(updated, row, organism);
    } else if (row.lastEventAt != null &&
        row.quantity == organism.measurement.value.round() &&
        organism.updatedAt != row.lastEventAt) {
      // No mutations but we have a timestamp to apply
      organism = await _applyTimestampOnly(organism, row.lastEventAt!);
    }

    return organism;
  }

  _CurrentValues _extractCurrentValues(OrganismRecord organism) {
    final genetRecordId = GenetIdResolver.resolve(organism);
    final healthStatus = HealthStatus.fromId(
        organism.metadata?['healthStatus'] as String? ?? 'healthy');
    final notes = organism.metadata?['notes'] as String?;
    final tagId = organism.tagId.trim();
    final formId = organism.physicalForm?.formId ??
        organism.metadata?['physicalFormId'] as String?;
    final sizeBandId = organism.physicalForm?.sizeBandId;
    final sizeSpec = organism.sizeSpec;
    final readyForPropagation =
        organism.metadata?['readyForPropagation'] as bool? ?? false;
    final readyForOutplant =
        organism.metadata?['readyForOutplant'] as bool? ?? false;

    return _CurrentValues(
      genetRecordId: genetRecordId,
      healthStatus: healthStatus,
      notes: notes,
      tagId: tagId,
      formId: formId,
      sizeBandId: sizeBandId,
      sizeSpec: sizeSpec,
      readyForPropagation: readyForPropagation,
      readyForOutplant: readyForOutplant,
    );
  }

  OrganismRecord _updateMetadata(
    OrganismRecord organism, {
    required String physicalFormId,
    String? sizeBandId,
    SizeSpec? sizeSpec,
    required HealthStatus healthStatus,
    required String? notes,
    required bool readyForPropagation,
    required bool readyForOutplant,
    required String? genetRecordId,
    PopulationMeasurement? measurement,
  }) {
    final resolvedSizeBandId = _resolveSizeBandId(
      sizeBandId,
      organism.physicalForm?.sizeBandId,
    );
    final updatedMetadata = {
      ...?organism.metadata,
      'physicalFormId': physicalFormId,
      'healthStatus': healthStatus.id,
      'readyForPropagation': readyForPropagation,
      'readyForOutplant': readyForOutplant,
      if (notes != null) 'notes': notes,
    };

    return organism.copyWith(
      physicalForm: PhysicalFormInstance(
        formId: physicalFormId,
        sizeBandId: resolvedSizeBandId,
      ),
      sizeSpec: sizeSpec ?? organism.sizeSpec,
      metadata: updatedMetadata,
      genetRecordId: genetRecordId ?? organism.genetRecordId,
      measurement: measurement ?? organism.measurement,
    );
  }

  String _resolveSizeBandId(String? incoming, String? current) {
    final candidate = incoming?.trim();
    if (candidate != null && candidate.isNotEmpty) {
      return candidate;
    }
    if (current != null && current.trim().isNotEmpty) {
      return current.trim();
    }
    return 'medium';
  }

  OrganismRecord _applyGenetUpdate(OrganismRecord organism, Genet genet) {
    final foreignKeys =
        Map<String, ForeignKeyReference>.from(organism.foreignKeys);
    final foreignKeyMetadata = <String, dynamic>{
      if (genet.localGenetId != null) 'localGenetId': genet.localGenetId,
      'provenanceId': genet.provenanceId,
      'displayName': genet.displayName,
    };
    foreignKeys['genetRecordId'] = ForeignKeyReference(
      id: genet.id,
      metadata: foreignKeyMetadata,
    );
    return organism.copyWith(foreignKeys: foreignKeys, genetRecordId: genet.id);
  }

  bool _haveAliasesChanged(
    List<OrganismAlias> currentAliases,
    List<OrganismAlias> newAliases,
  ) {
    final currentSet =
        currentAliases.map((alias) => alias.value.trim()).toSet();
    final incomingSet = newAliases.map((alias) => alias.value.trim()).toSet();
    return incomingSet.isNotEmpty &&
        (incomingSet.difference(currentSet).isNotEmpty ||
            currentSet.difference(incomingSet).isNotEmpty);
  }

  Future<OrganismRecord> _persistChanges(
    OrganismRecord updated,
    InventoryImportRow row,
    OrganismRecord original,
  ) async {
    // Use the provided lastEventAt timestamp when available; otherwise use now.
    // Note: If quantity changed, we always use now() since the quantity change
    // represents a new event that supersedes the provided timestamp.
    final quantityUnchanged =
        row.quantity == original.measurement.value.round();
    final timestamp = row.lastEventAt != null && quantityUnchanged
        ? row.lastEventAt!
        : DateTime.now().toIso8601String();
    updated = updated.copyWith(
      updatedAt: timestamp,
      updatedById: _organismRecordRepository.user.id,
    );
    await _organismRecordRepository.updateRecord(updated);
    return updated;
  }

  Future<OrganismRecord> _applyTimestampOnly(
    OrganismRecord organism,
    String lastEventAt,
  ) async {
    // No mutations but we have a timestamp to apply. Only apply if quantity
    // matches (unchanged), as a quantity change would be a new event.
    final timestamped = organism.copyWith(
      updatedAt: lastEventAt,
      updatedById: _organismRecordRepository.user.id,
    );
    await _organismRecordRepository.updateRecord(timestamped);
    return timestamped;
  }
}

/// Internal helper for current organism values.
class _CurrentValues {
  const _CurrentValues({
    required this.genetRecordId,
    required this.healthStatus,
    required this.notes,
    required this.tagId,
    required this.formId,
    required this.sizeBandId,
    required this.sizeSpec,
    required this.readyForPropagation,
    required this.readyForOutplant,
  });

  final String? genetRecordId;
  final HealthStatus healthStatus;
  final String? notes;
  final String tagId;
  final String? formId;
  final String? sizeBandId;
  final SizeSpec sizeSpec;
  final bool readyForPropagation;
  final bool readyForOutplant;
}
