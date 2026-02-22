// @tier: community
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/husbandry_event.dart';
import 'package:seafoundry_app/models/types/gene_bank_event_type.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

/// An event representing temperature monitoring for gene bank storage
///
/// Tracks temperature readings to ensure optimal storage conditions
/// for genetic material. General monitoring (not cryo-specific).
class GeneBankTemperatureMonitoringEvent extends HusbandryEvent {
  /// Temperature reading in Celsius
  final double temperatureCelsius;

  /// Whether temperature is within acceptable range
  final bool isWithinRange;

  /// Minimum acceptable temperature (if specified)
  final double? minTemperature;

  /// Maximum acceptable temperature (if specified)
  final double? maxTemperature;

  /// Location or structure identifier where measurement was taken
  final String? measurementLocation;

  GeneBankTemperatureMonitoringEvent({
    required super.id,
    required this.temperatureCelsius,
    this.isWithinRange = true,
    this.minTemperature,
    this.maxTemperature,
    this.measurementLocation,
    super.comment,
    super.imageUrl,
    required super.createdById,
    required super.createdAt,
    required super.updatedAt,
    required super.updatedById,
    required super.organizationId,
    required super.recordId,
    required super.recordModelType,
    required super.urlPath,
    required super.internalPath,
    required super.slug,
    super.missionId,
    super.metadata,
    super.base,
  }) : super(
         eventTypeId: GeneBankEventType.temperatureMonitoringId,
       );

  GeneBankTemperatureMonitoringEvent.fromJson(super.json)
    : temperatureCelsius =
          safeDouble(json['temperatureCelsius']) ?? 0.0,
      isWithinRange = json['isWithinRange'] != false,
      minTemperature = safeDouble(json['minTemperature']),
      maxTemperature = safeDouble(json['maxTemperature']),
      measurementLocation = json['measurementLocation'],
      super.fromJson();

  GeneBankTemperatureMonitoringEvent.partial({
    super.json,
    super.id,
    super.createdById,
    super.createdAt,
    super.updatedAt,
    super.updatedById,
    super.organizationId,
    super.recordId,
    super.recordModelType,
    super.urlPath,
    super.internalPath,
    super.slug,

    super.metadata,

    super.base,
    super.eventTypeId,
    super.comment,
    super.imageUrl,
    double? temperatureCelsius,
    bool? isWithinRange,
    double? minTemperature,
    double? maxTemperature,
    String? measurementLocation,
  }) : temperatureCelsius =
           temperatureCelsius ??
           safeDouble(json?['temperatureCelsius']) ??
           0.0,
       isWithinRange = isWithinRange ?? json?['isWithinRange'] != false,
       minTemperature =
           minTemperature ?? safeDouble(json?['minTemperature']),
       maxTemperature =
           maxTemperature ?? safeDouble(json?['maxTemperature']),
       measurementLocation =
           measurementLocation ?? json?['measurementLocation'],
       super.partial();

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'temperatureCelsius': temperatureCelsius,
      'isWithinRange': isWithinRange,
      if (minTemperature != null) 'minTemperature': minTemperature,
      if (maxTemperature != null) 'maxTemperature': maxTemperature,
      if (measurementLocation != null)
        'measurementLocation': measurementLocation,
    };
  }

  @override
  bool validate() {
    return super.validate() &&
        temperatureCelsius > -273.15; // Above absolute zero
  }

  @override
  GeneBankTemperatureMonitoringEvent copyWith({
    String? id,
    double? temperatureCelsius,
    bool? isWithinRange,
    double? minTemperature,
    double? maxTemperature,
    String? measurementLocation,
    String? comment,
    String? imageUrl,
    String? eventTypeId,
    String? createdById,
    String? createdAt,
    String? updatedAt,
    String? updatedById,
    String? organizationId,
    String? recordId,
    ModelType? recordModelType,
    String? missionId,
    bool clearMissionId = false,
    String? urlPath,
    String? internalPath,
    String? slug,
    Map<String, dynamic>? metadata,
    EventPermitMetadata? permitMetadata,
    OutplantGeometry? geometry,
  }) {
    return GeneBankTemperatureMonitoringEvent(
      id: id ?? this.id,
      temperatureCelsius: temperatureCelsius ?? this.temperatureCelsius,
      isWithinRange: isWithinRange ?? this.isWithinRange,
      minTemperature: minTemperature ?? this.minTemperature,
      maxTemperature: maxTemperature ?? this.maxTemperature,
      measurementLocation: measurementLocation ?? this.measurementLocation,
      comment: comment ?? this.comment,
      imageUrl: imageUrl ?? this.imageUrl,
      createdById: createdById ?? this.createdById,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedById: updatedById ?? this.updatedById,
      organizationId: organizationId ?? this.organizationId,
      recordId: recordId ?? this.recordId,
      recordModelType: recordModelType ?? this.recordModelType,
      urlPath: urlPath ?? this.urlPath,
      internalPath: internalPath ?? this.internalPath,
      slug: slug ?? this.slug,
      missionId: clearMissionId ? null : (missionId ?? this.missionId),
      metadata: metadata ?? this.metadata,
      base: resolveBaseParams(
        permitMetadata: permitMetadata,
        geometry: geometry,
      ),
    );
  }

  @override
  List<Object?> get props =>
      super.props +
      [
        temperatureCelsius,
        isWithinRange,
        minTemperature,
        maxTemperature,
        measurementLocation,
      ];
}
