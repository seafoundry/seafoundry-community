// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/types/coral_morphology.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

/// MonitoringEntry represents a single entry in a monitoring event.
/// Used to track individual organism monitoring data within a batch event.
class MonitoringEntry extends Equatable {
  final String genetId;
  final String? tagId;
  final String? physicalForm;
  final String? morphologyId;
  final String? notes;
  final String? healthStatus;
  final double? percentCover;
  final double? percentBleaching;
  final double? percentDisease;
  final Map<String, dynamic>? measurements;

  const MonitoringEntry({
    required this.genetId,
    this.tagId,
    this.physicalForm,
    this.morphologyId,
    this.notes,
    this.healthStatus,
    this.percentCover,
    this.percentBleaching,
    this.percentDisease,
    this.measurements,
  });

  /// Create a MonitoringEntry from JSON
  factory MonitoringEntry.fromJson(Map<String, dynamic> json) {
    final measurements = safeMapCast(json['measurements']);
    final physicalForm =
        json['physicalFormId']?.toString() ??
        measurements?['physicalFormId']?.toString();
    final morphologyRaw =
        json['morphologyId']?.toString() ??
        measurements?['morphologyId']?.toString();
    final derivedMorphology = CoralMorphologyX.tryParse(morphologyRaw)?.id;
    return MonitoringEntry(
      genetId: json['genetId'] ?? '',
      tagId: json['tagId'] ?? measurements?['tagId'],
      physicalForm: physicalForm,
      morphologyId: derivedMorphology,
      notes: json['notes'],
      healthStatus: json['healthStatus'],
      percentCover: safeDouble(json['percentCover']),
      percentBleaching: safeDouble(json['percentBleaching']),
      percentDisease: safeDouble(json['percentDisease']),
      measurements: measurements,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'genetId': genetId,
      if (tagId != null) 'tagId': tagId,
      if (physicalForm != null) 'physicalFormId': physicalForm,
      if (morphologyId != null) 'morphologyId': morphologyId,
      'notes': notes,
      'healthStatus': healthStatus,
      'percentCover': percentCover,
      'percentBleaching': percentBleaching,
      'percentDisease': percentDisease,
      'measurements': measurements,
    };
  }

  /// Create a copy with optional new values
  MonitoringEntry copyWith({
    String? genetId,
    String? tagId,
    String? physicalForm,
    String? morphologyId,
    String? notes,
    String? healthStatus,
    double? percentCover,
    double? percentBleaching,
    double? percentDisease,
    Map<String, dynamic>? measurements,
  }) {
    return MonitoringEntry(
      genetId: genetId ?? this.genetId,
      tagId: tagId ?? this.tagId,
      physicalForm: physicalForm ?? this.physicalForm,
      morphologyId: morphologyId ?? this.morphologyId,
      notes: notes ?? this.notes,
      healthStatus: healthStatus ?? this.healthStatus,
      percentCover: percentCover ?? this.percentCover,
      percentBleaching: percentBleaching ?? this.percentBleaching,
      percentDisease: percentDisease ?? this.percentDisease,
      measurements: measurements ?? this.measurements,
    );
  }

  @override
  List<Object?> get props => [
    genetId,
    tagId,
    physicalForm,
    morphologyId,
    notes,
    healthStatus,
    percentCover,
    percentBleaching,
    percentDisease,
    measurements,
  ];
}
