import 'package:seafoundry_app/models/models.dart';

/// Derives a canonical provenance/life-stage selection for organisms by
/// preferring the organism's direct provenanceType field, then metadata
/// overrides, and falling back to genet context.
ProvenanceLifeStageSelection buildProvenanceSelection({
  required OrganismRecord organism,
  ProvenanceBase? provenance,
}) {
  // If organism has a direct provenanceType set, use it immediately.
  // This is the strongly-typed field on OrganismRecord, which is the canonical source.
  if (organism.provenanceType != null) {
    return ProvenanceLifeStageSelection(
      provenanceType: organism.provenanceType!,
      lifeStage: organism.lifeStage.stage,
    );
  }

  // If provenance is a Genet, use fromGenet which properly checks metadata
  // before falling back to provenanceKind (which may be incorrectly derived)
  if (provenance is Genet) {
    final genetSelection = ProvenanceLifeStageSelection.fromGenet(provenance);
    // Use organism's life stage if available
    return ProvenanceLifeStageSelection(
      provenanceType: genetSelection.provenanceType,
      lifeStage: organism.lifeStage.stage,
    );
  }

  // Fallback: derive from metadata sources
  final sources = <Map<String, dynamic>>[];
  final organismMetadata = organism.metadata;
  if (organismMetadata != null && organismMetadata.isNotEmpty) {
    sources.add(Map<String, dynamic>.from(organismMetadata));
  }
  final provenanceMetadata = provenance?.metadata;
  if (provenanceMetadata != null && provenanceMetadata.isNotEmpty) {
    sources.add(Map<String, dynamic>.from(provenanceMetadata));
  }
  final fallbackLifeStageId = organism.lifeStage.stage.id;
  if (fallbackLifeStageId.isNotEmpty) {
    sources.add({'lifeStageId': fallbackLifeStageId});
  }
  return ProvenanceLifeStageSelection.fromCanonicalSources(
    sources: sources,
    fallbackProvenanceKind: provenance?.provenanceKind.name,
  );
}

/// Derives provenance/life-stage selection for transfer events by first
/// inspecting manifest metadata, then falling back to the event metadata or
/// the originating genet when canonical fields are missing.
ProvenanceLifeStageSelection buildTransferProvenanceSelection({
  required TransferEvent transfer,
  ProvenanceBase? provenance,
}) {
  final manifestData = transfer.manifest;
  if (manifestData != null) {
    try {
      // Extract metadata from genet.metadata and manifest.metadata
      final sources = <Map<String, dynamic>>[];
      final genetMetadata = manifestData['genet']?['metadata'];
      if (genetMetadata is Map<String, dynamic>) {
        sources.add(Map<String, dynamic>.from(genetMetadata));
      }
      final topLevelMetadata = manifestData['metadata'];
      if (topLevelMetadata is Map<String, dynamic>) {
        sources.add(Map<String, dynamic>.from(topLevelMetadata));
      }
      if (sources.isNotEmpty) {
        final fallbackKind = manifestData['genet']?['provenanceKind']?.toString() ??
                             manifestData['provenanceKind']?.toString();
        return ProvenanceLifeStageSelection.fromCanonicalSources(
          sources: sources,
          fallbackProvenanceKind: fallbackKind,
        );
      }
    } catch (_) {
      // Fall through to event/genet metadata.
    }
  }

  final metadata = transfer.metadata;
  if (metadata != null && metadata.isNotEmpty) {
    return ProvenanceLifeStageSelection.fromCanonicalSources(
      sources: [Map<String, dynamic>.from(metadata)],
      fallbackProvenanceKind: metadata['provenanceKind']?.toString(),
    );
  }

  // We need to handle the case where ProvenanceLifeStageSelection.fromGenet expects a Genet.
  // Since we are moving away from Genet, we should ideally have a fromProvenance method.
  // For now, if provenance is a Genet, we can cast it, or we can rely on fromCanonicalSources.

  if (provenance is Genet) {
    return ProvenanceLifeStageSelection.fromGenet(provenance);
  }

  // Fallback using canonical sources from provenance metadata if available
  if (provenance != null) {
     return ProvenanceLifeStageSelection.fromCanonicalSources(
      sources: [provenance.metadata],
      fallbackProvenanceKind: provenance.provenanceKind.name,
    );
  }

  return ProvenanceLifeStageSelection.fromGenet(null);
}
