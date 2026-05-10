part of 'genetics_events_table.dart';

const Set<String> _supportedEventTypeIds = {
  'event_create',
  'event_update',
  LoanEventType.loanId,
  LoanEventType.legacyTransferId,
  'event_genet_modification',
};

const Map<String, String> _eventLabelOverrides = {
  'event_create': 'Created',
  'event_update': 'Updated',
  'event_loan': 'Transfer',
  'event_transfer': 'Transfer',
  'event_genet_modification': 'Record Modified',
};

const Map<String, String> _genetFieldLabels = {
  'name': 'Local ID',
  'localGenetId': 'Local ID',
  'provenanceTypeId': 'Provenance Type',
  'speciesId': 'Species',
  'provenanceId': 'Provenance ID',
  'clonalId': 'Clonal ID',
  'accessionNumber': 'Accession #',
  'notes': 'Notes',
  'parentGameteIds': 'Parent Gametes',
  'parentCohortId': 'Parent Cohort',
  'donorGenotypeId': 'Donor Genotype',
  'metadata.provenanceTypeId': 'Provenance Type',
  'metadata.lifeStageId': 'Life Stage',
};

const Map<String, String> _coralFieldLabels = {
  'name': 'Record Name',
  'tagId': 'Record Name',
  'localGenetId': 'Local ID',
  'quantity': 'Quantity',
  'physicalForm.formId': 'Physical Form',
  'genetRecordId': 'Genet ID',
  'siteId': 'Site',
  'groupId': 'Structure',
  'notes': 'Notes',
  'metadata.lifeStageId': 'Life Stage',
  'metadata.physicalFormId': 'Physical Form',
};

const List<SpreadsheetColumn> _geneticsEventColumns = [
  SpreadsheetColumn(key: 'timestamp', title: 'Timestamp', width: 170),
  SpreadsheetColumn(key: 'event', title: 'Event', width: 180),
  SpreadsheetColumn(key: 'record', title: 'Record', width: 220),
  SpreadsheetColumn(key: 'details', title: 'Details', width: 320),
  SpreadsheetColumn(key: 'aliases', title: 'Aliases', width: 220),
  SpreadsheetColumn(key: 'species', title: 'Species', width: 180),
  SpreadsheetColumn(key: 'provenanceType', title: 'Provenance Type', width: 180),
  SpreadsheetColumn(key: 'lifeStage', title: 'Life Stage', width: 150),
  SpreadsheetColumn(key: 'user', title: 'User', width: 160),
];

class _GeneticsEventCandidate {
  const _GeneticsEventCandidate(this.event, this.eventTypeId);

  final Event event;
  final String eventTypeId;
}

class _GeneticsEventRow {
  _GeneticsEventRow({
    required this.eventId,
    required this.eventTypeId,
    required this.eventLabel,
    required this.recordModelType,
    required this.recordId,
    required this.recordDisplay,
    required this.recordLink,
    required this.createdAt,
    required this.userName,
    required this.description,
    required this.speciesName,
    required this.provenanceTypeLabel,
    required this.lifeStageLabel,
    required this.aliases,
  });

  final String eventId;
  final String eventTypeId;
  final String eventLabel;
  final ModelType recordModelType;
  final String recordId;
  final String recordDisplay;
  final Widget? recordLink;
  final DateTime? createdAt;
  final String? userName;
  final String description;
  final String? speciesName;
  final String? provenanceTypeLabel;
  final String? lifeStageLabel;
  final List<OrganismAlias> aliases;

  static Future<_GeneticsEventRow?> fromEvent({
    required Event event,
    required String eventTypeId,
    required Future<String> Function(String) resolveUserName,
    required Future<Genet?> Function(String?) resolveGenet,
    required Future<OrganismRecord?> Function(String?) resolveOrganism,
  }) =>
      _hydrateGeneticsEventRow(
        event: event,
        eventTypeId: eventTypeId,
        resolveUserName: resolveUserName,
        resolveGenet: resolveGenet,
        resolveOrganism: resolveOrganism,
      );

  Map<String, dynamic> toJson() => {
        'eventId': eventId,
        'eventTypeId': eventTypeId,
        'eventLabel': eventLabel,
        'recordType': recordModelType.name,
        'recordId': recordId,
        'recordDisplay': recordDisplay,
        'createdAt': createdAt?.toIso8601String(),
        'userName': userName,
        'description': description,
        'speciesName': speciesName,
        'provenanceType': provenanceTypeLabel,
        'lifeStage': lifeStageLabel,
        'aliasLabels':
            aliases.map((alias) => alias.label ?? alias.value).toList(),
      };
}
