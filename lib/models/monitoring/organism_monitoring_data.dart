// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/types/coral_morphology.dart';
import 'package:seafoundry_app/models/types/health_status.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';
import 'package:seafoundry_app/services/genet_id_resolver.dart';

/// OrganismMonitoringData represents monitoring data for an organism.
/// This is used as a data transfer object between the UI and the repository.
///
/// NOTE: This is a transient DTO, not persisted to Firestore. The denormalized
/// name fields (speciesName, siteName, groupName) are populated at runtime from
/// the UI context for display convenience. These could theoretically be resolved
/// at display time instead, but would require breaking changes to the API.
/// Tech debt: Consider refactoring to resolve names at display time.
class OrganismMonitoringData extends Equatable {
  final String organismId;
  final String recordName;
  final String? recordUrlPath;
  final String speciesId;

  /// Transient display name - populated at runtime, not persisted.
  final String speciesName;
  final String genetId;
  final String? siteId;

  /// Transient display name - populated at runtime, not persisted.
  final String? siteName;
  final String? groupId;

  /// Transient display name - populated at runtime, not persisted.
  final String? groupName;
  final HealthStatus oldHealthStatus;
  final HealthStatus? newHealthStatus;
  final String? healthIssueTypeId;
  final double? percentCover;
  final double? percentBleaching;
  final double? percentDisease;
  final Map<String, dynamic>? measurements;
  final String? imageUrl;
  final String? comment;
  final DateTime monitoringDate;
  final bool createTask;
  final String? tagId;

  /// Physical form ID (fragment, colony, etc.).
  final String? physicalForm;

  /// Coral morphology ID (branching, massive, etc.).
  final String? morphologyId;

  const OrganismMonitoringData({
    required this.organismId,
    required this.recordName,
    this.recordUrlPath,
    required this.speciesId,
    required this.speciesName,
    required this.genetId,
    this.siteId,
    this.siteName,
    this.groupId,
    this.groupName,
    required this.oldHealthStatus,
    this.newHealthStatus,
    this.healthIssueTypeId,
    this.percentCover,
    this.percentBleaching,
    this.percentDisease,
    this.measurements,
    this.imageUrl,
    this.comment,
    required this.monitoringDate,
    this.createTask = false,
    this.tagId,
    this.physicalForm,
    this.morphologyId,
  });

  /// Create an OrganismMonitoringData from an OrganismRecord.
  factory OrganismMonitoringData.fromOrganism(
    OrganismRecord organism, {
    String? siteName,
    String? groupName,
    String? speciesName,
    HealthStatus? newHealthStatus,
    String? healthIssueTypeId,
    double? percentCover,
    double? percentBleaching,
    double? percentDisease,
    Map<String, dynamic>? measurements,
    String? imageUrl,
    String? comment,
    DateTime? monitoringDate,
    bool createTask = false,
    String? tagId,
    String? physicalForm,
    String? morphologyId,
  }) {
    return OrganismMonitoringData(
      organismId: organism.id,
      recordName: organism.localId ?? organism.recordName,
      recordUrlPath: organism.urlPath,
      speciesId: organism.speciesId ?? '',
      speciesName: speciesName ?? '',
      genetId: GenetIdResolver.resolve(organism) ?? organism.id,
      siteId: organism.siteId,
      siteName: siteName,
      groupId: organism.groupId,
      groupName: groupName,
      oldHealthStatus: HealthStatus.fromId(
        organism.metadata?['healthStatus'] as String? ?? 'healthy',
      ),
      newHealthStatus: newHealthStatus,
      healthIssueTypeId: healthIssueTypeId,
      percentCover: percentCover,
      percentBleaching: percentBleaching,
      percentDisease: percentDisease,
      measurements: measurements,
      imageUrl: imageUrl,
      comment: comment,
      monitoringDate: monitoringDate ?? DateTime.now(),
      createTask: createTask,
      tagId: tagId,
      physicalForm: physicalForm,
      morphologyId: morphologyId,
    );
  }

  /// Create a copy with modified fields.
  OrganismMonitoringData copyWith({
    String? organismId,
    String? recordName,
    String? recordUrlPath,
    String? speciesId,
    String? speciesName,
    String? genetId,
    String? siteId,
    String? siteName,
    String? groupId,
    String? groupName,
    HealthStatus? oldHealthStatus,
    HealthStatus? newHealthStatus,
    String? healthIssueTypeId,
    double? percentCover,
    double? percentBleaching,
    double? percentDisease,
    Map<String, dynamic>? measurements,
    String? imageUrl,
    String? comment,
    DateTime? monitoringDate,
    bool? createTask,
    String? tagId,
    String? physicalForm,
    String? morphologyId,
  }) {
    return OrganismMonitoringData(
      organismId: organismId ?? this.organismId,
      recordName: recordName ?? this.recordName,
      recordUrlPath: recordUrlPath ?? this.recordUrlPath,
      speciesId: speciesId ?? this.speciesId,
      speciesName: speciesName ?? this.speciesName,
      genetId: genetId ?? this.genetId,
      siteId: siteId ?? this.siteId,
      siteName: siteName ?? this.siteName,
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      oldHealthStatus: oldHealthStatus ?? this.oldHealthStatus,
      newHealthStatus: newHealthStatus ?? this.newHealthStatus,
      healthIssueTypeId: healthIssueTypeId ?? this.healthIssueTypeId,
      percentCover: percentCover ?? this.percentCover,
      percentBleaching: percentBleaching ?? this.percentBleaching,
      percentDisease: percentDisease ?? this.percentDisease,
      measurements: measurements ?? this.measurements,
      imageUrl: imageUrl ?? this.imageUrl,
      comment: comment ?? this.comment,
      monitoringDate: monitoringDate ?? this.monitoringDate,
      createTask: createTask ?? this.createTask,
      tagId: tagId ?? this.tagId,
      physicalForm: physicalForm ?? this.physicalForm,
      morphologyId: morphologyId ?? this.morphologyId,
    );
  }

  /// Convert to a map for JSON serialization.
  Map<String, dynamic> toJson() {
    return {
      'organismId': organismId,
      'recordName': recordName,
      if (recordUrlPath != null) 'recordUrlPath': recordUrlPath,
      'speciesId': speciesId,
      'speciesName': speciesName,
      'genetId': genetId,
      'siteId': siteId,
      'siteName': siteName,
      'groupId': groupId,
      'groupName': groupName,
      'oldHealthStatus': oldHealthStatus.id,
      'newHealthStatus': newHealthStatus?.id,
      'healthIssueTypeId': healthIssueTypeId,
      'percentCover': percentCover,
      'percentBleaching': percentBleaching,
      'percentDisease': percentDisease,
      'measurements': measurements,
      'imageUrl': imageUrl,
      'comment': comment,
      'monitoringDate': monitoringDate.toIso8601String(),
      'createTask': createTask,
      'tagId': tagId,
      'physicalFormId': physicalForm,
      'morphologyId': morphologyId,
    };
  }

  /// Create from a JSON map.
  factory OrganismMonitoringData.fromJson(Map<String, dynamic> json) {
    final rawPhysicalForm = (json['physicalFormId'] ?? json['physical_form_id'])
        ?.toString();
    final rawMorphology = (json['morphologyId'] ?? json['morphology_id'])
        ?.toString();
    final derivedMorphology = CoralMorphologyX.tryParse(rawMorphology)?.id;
    return OrganismMonitoringData(
      organismId: json['organismId'] ?? json['coralId'],
      recordName: json['recordName'],
      recordUrlPath: json['recordUrlPath'] ?? json['record_url_path'],
      speciesId: json['speciesId'],
      speciesName: json['speciesName'],
      genetId: json['genetId'],
      siteId: json['siteId'],
      siteName: json['siteName'],
      groupId: json['groupId'],
      groupName: json['groupName'],
      oldHealthStatus: HealthStatus.fromId(json['oldHealthStatus']),
      newHealthStatus: HealthStatus.maybeFromId(json['newHealthStatus']),
      healthIssueTypeId: json['healthIssueTypeId'],
      percentCover: safeDouble(json['percentCover']),
      percentBleaching: safeDouble(json['percentBleaching']),
      percentDisease: safeDouble(json['percentDisease']),
      measurements: safeMapCast(json['measurements']),
      imageUrl: json['imageUrl'],
      comment: json['comment'],
      monitoringDate: DateTime.parse(json['monitoringDate']),
      createTask: json['createTask'] ?? false,
      tagId: json['tagId'] ?? json['tag_id'],
      physicalForm: rawPhysicalForm,
      morphologyId: derivedMorphology,
    );
  }

  @override
  List<Object?> get props => [
    organismId,
    recordName,
    recordUrlPath,
    speciesId,
    speciesName,
    genetId,
    siteId,
    siteName,
    groupId,
    groupName,
    oldHealthStatus,
    newHealthStatus,
    healthIssueTypeId,
    percentCover,
    percentBleaching,
    percentDisease,
    measurements,
    imageUrl,
    comment,
    monitoringDate,
    createTask,
    tagId,
    physicalForm,
    morphologyId,
  ];
}
