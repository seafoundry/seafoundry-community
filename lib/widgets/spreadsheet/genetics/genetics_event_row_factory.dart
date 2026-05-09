part of 'genetics_events_table.dart';

/// Builds a [_GeneticsEventRow] from a raw [Event], resolving genets,
/// organisms, and labels via the supplied async resolvers.
///
/// Returns `null` when the event cannot be represented (unsupported
/// snapshot type, unsupported record model, or unsupported runtime type).
Future<_GeneticsEventRow?> _hydrateGeneticsEventRow({
  required Event event,
  required String eventTypeId,
  required Future<String> Function(String) resolveUserName,
  required Future<Genet?> Function(String?) resolveGenet,
  required Future<OrganismRecord?> Function(String?) resolveOrganism,
}) async {
  final createdAt = DateTime.tryParse(event.createdAt);
  final userName = await resolveUserName(event.createdById);

  String recordDisplay = event.recordId;
  Widget? recordLink;
  String? speciesName;
  String? provenanceTypeLabel;
  String? lifeStageLabel;
  String? provenanceTypeId;
  String? fallbackLifeStageId;
  String description = '';
  List<OrganismAlias> aliases = const <OrganismAlias>[];

  void applySelection(ProvenanceLifeStageSelection? selection) {
    if (selection == null) return;
    provenanceTypeLabel = selection.provenanceType.displayName;
    lifeStageLabel = selection.lifeStage.displayName;
  }

  if (event is InventoryEvent) {
    final snapshot = event.snapshot;
    if (snapshot is Genet) {
      recordDisplay = _asNonEmptyString(snapshot.name) ?? event.recordId;
      recordLink = GenetIdLink(
        localGenetId: snapshot.localGenetId ?? snapshot.name,
        genetRecordId: snapshot.id,
        showUnderline: true,
      );
      speciesName = _speciesLabel(snapshot.speciesId);
      provenanceTypeId = snapshot.provenanceTypeId;
      applySelection(ProvenanceLifeStageSelection.fromGenet(snapshot));
      fallbackLifeStageId = snapshot.provenance?['lifeStageId']?.toString();
      description = _describeGenetInventoryEvent(event, snapshot);
      aliases = snapshot.aliasEntries;
    } else if (snapshot is OrganismRecord) {
      recordDisplay = _asNonEmptyString(snapshot.name) ?? event.recordId;
      recordLink = OrganismReferenceLinks(
        tagId: snapshot.tagId,
        localGenetId: snapshot.localGenetId,
        urlPath: snapshot.urlPath,
        genetRecordId: snapshot.genetRecordId,
        showUnderline: true,
      );
      speciesName = _speciesLabel(snapshot.speciesId);
      fallbackLifeStageId = snapshot.lifeStage.stage.id;
      final genetRecordId = GenetIdResolver.resolve(snapshot);
      final genet = await resolveGenet(genetRecordId);
      provenanceTypeId = genet?.provenanceTypeId;
      applySelection(
        buildProvenanceSelection(organism: snapshot, provenance: genet),
      );
      description = _describeOrganismInventoryEvent(event, snapshot);
      aliases = genet?.aliasEntries ?? const <OrganismAlias>[];
    } else {
      LoggingService.instance.warning(
        'GeneticsEventsTable: InventoryEvent ${event.id} has unsupported snapshot type: '
        '${snapshot.runtimeType} (modelType: ${snapshot.modelType})',
      );
      return null;
    }
  } else if (event is GenetModificationEvent) {
    final genet = await resolveGenet(event.recordId);
    recordDisplay = genet?.name ?? event.recordId;
    if (genet != null) {
      recordLink = GenetIdLink(
        localGenetId: genet.localGenetId ?? genet.name,
        genetRecordId: genet.id,
        showUnderline: true,
      );
    }
    speciesName = _speciesLabel(genet?.speciesId);
    provenanceTypeId = genet?.provenanceTypeId;
    applySelection(ProvenanceLifeStageSelection.fromGenet(genet));
    description = _formatGenetModificationDescription(event);
    aliases = genet?.aliasEntries ?? const <OrganismAlias>[];
  } else if (event is UpdateEvent) {
    OrganismRecord? resolvedOrganism;
    if (event.recordModelType == ModelType.genet) {
      final genet = await resolveGenet(event.recordId);
      recordDisplay = genet?.name ?? event.recordId;
      if (genet != null) {
        recordLink = GenetIdLink(
          localGenetId: genet.localGenetId ?? genet.name,
          genetRecordId: genet.id,
          showUnderline: true,
        );
      }
      speciesName = _speciesLabel(genet?.speciesId);
      provenanceTypeId = genet?.provenanceTypeId;
      applySelection(ProvenanceLifeStageSelection.fromGenet(genet));
      aliases = genet?.aliasEntries ?? const <OrganismAlias>[];
    } else if (event.recordModelType == ModelType.organismRecord) {
      final organism = await resolveOrganism(event.recordId);
      resolvedOrganism = organism;
      recordDisplay = organism != null
          ? formatOrganismReferenceLabel(
              localGenetId: organism.localGenetId,
              tagId: organism.tagId,
              fallback: organism.name,
            )
          : event.recordId;
      if (organism != null) {
        recordLink = OrganismReferenceLinks(
          tagId: organism.tagId,
          localGenetId: organism.localGenetId,
          urlPath: organism.urlPath,
          genetRecordId: organism.genetRecordId,
          showUnderline: true,
        );
      }
      speciesName = _speciesLabel(organism?.speciesId);
      fallbackLifeStageId =
          organism?.lifeStage.stage.id ?? fallbackLifeStageId;
      if (organism != null) {
        final genetRecordId = GenetIdResolver.resolve(organism);
        final genet = await resolveGenet(genetRecordId);
        provenanceTypeId = genet?.provenanceTypeId ?? provenanceTypeId;
        applySelection(
          buildProvenanceSelection(organism: organism, provenance: genet),
        );
        if (genet != null) {
          aliases = genet.aliasEntries;
        }
      }
    } else {
      return null;
    }
    description = _formatUpdateDescription(
      event,
      event.recordModelType,
      organism: resolvedOrganism,
    );
  } else if (event is TransferEvent) {
    final manifestGenet =
        event.manifest?['genet'] as Map<String, dynamic>? ?? const {};
    final manifestName = _asNonEmptyString(manifestGenet['name']) ??
        _asNonEmptyString(manifestGenet['localGenetId']);
    recordDisplay = manifestName ?? event.genetRecordId ?? event.recordId;

    final manifestSpeciesId = _asNonEmptyString(manifestGenet['speciesId']);
    if (manifestSpeciesId != null) {
      speciesName = _speciesLabel(manifestSpeciesId);
    }

    final manifestProvenanceTypeId =
        _asNonEmptyString(manifestGenet['provenanceTypeId']) ??
            _asNonEmptyString((manifestGenet['provenanceType'] as Map?)?['id']);
    if (manifestProvenanceTypeId != null) {
      provenanceTypeId = manifestProvenanceTypeId;
    }
    final manifestLifeStageId =
        _asNonEmptyString(manifestGenet['lifeStageId']) ??
            _asNonEmptyString((manifestGenet['lifeStage'] as Map?)?['id']);
    fallbackLifeStageId ??= manifestLifeStageId;

    applySelection(
      buildTransferProvenanceSelection(
        transfer: event,
        provenance: await resolveGenet(event.genetRecordId),
      ),
    );

    description = _formatTransferDescription(event);
    aliases = _aliasesFromRaw(manifestGenet['aliases']);
  } else {
    return null;
  }

  provenanceTypeLabel ??= _provenanceLabelFromTypeId(provenanceTypeId);
  lifeStageLabel ??= _lifeStageLabelFromId(fallbackLifeStageId);

  return _GeneticsEventRow(
    eventId: event.id,
    eventTypeId: eventTypeId,
    eventLabel: _geneticsAwareEventLabel(eventTypeId, provenanceTypeLabel),
    recordModelType: event.recordModelType,
    recordId: event.recordId,
    recordDisplay: recordDisplay,
    recordLink: recordLink,
    createdAt: createdAt,
    userName: userName,
    description: description,
    speciesName: speciesName,
    provenanceTypeLabel: provenanceTypeLabel,
    lifeStageLabel: lifeStageLabel,
    aliases: aliases,
  );
}
