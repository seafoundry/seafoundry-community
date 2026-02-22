// @tier: community
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/husbandry_event.dart';
import 'package:seafoundry_app/models/types/husbandry_event_type.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/types/water_quality_parameter.dart';

/// An event representing a water quality test with multiple parameter measurements
class WaterQualityTestEvent extends HusbandryEvent {
  /// Map of parameter IDs to measured values
  final Map<String, double> parameterValues;

  WaterQualityTestEvent({
    required super.id,
    required this.parameterValues,
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
  }) : super(eventTypeId: HusbandryEventType.waterQualityTestId);

  WaterQualityTestEvent.fromJson(super.json)
    : parameterValues = json['parameterValues'] != null
          ? Map<String, double>.from(
              json['parameterValues'].map(
                (key, value) =>
                    MapEntry(key, value is int ? value.toDouble() : value),
              ),
            )
          : {},
      super.fromJson();

  WaterQualityTestEvent.partial({
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
    Map<String, double>? parameterValues,
  }) : parameterValues =
           parameterValues ??
           (json?['parameterValues'] != null
               ? Map<String, double>.from(
                   json?['parameterValues'].map(
                     (key, value) =>
                         MapEntry(key, value is int ? value.toDouble() : value),
                   ),
                 )
               : {}),
       super.partial();

  @override
  Map<String, dynamic> toJson() {
    return {...super.toJson(), 'parameterValues': parameterValues};
  }

  @override
  bool validate() {
    return super.validate() && parameterValues.isNotEmpty;
  }

  @override
  WaterQualityTestEvent copyWith({
    String? id,
    String? comment,
    String? imageUrl,
    Map<String, double>? parameterValues,
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
    return WaterQualityTestEvent(
      id: id ?? this.id,
      comment: comment ?? this.comment,
      imageUrl: imageUrl ?? this.imageUrl,
      parameterValues:
          parameterValues ?? Map<String, double>.from(this.parameterValues),
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
  List<Object?> get props => super.props + [comment, imageUrl, parameterValues];

  /// Get a specific parameter value
  double? getParameterValue(String parameterId) {
    return parameterValues[parameterId];
  }

  /// Get a specific parameter value with its formatted display string
  String? getParameterDisplayValue(String parameterId) {
    final value = parameterValues[parameterId];
    if (value == null) return null;

    final parameter = WaterQualityParameter.fromId(parameterId);
    return parameter?.getDisplayString(value) ?? value.toString();
  }

  /// Check if a specific parameter is out of range
  bool isParameterOutOfRange(String parameterId) {
    final value = parameterValues[parameterId];
    if (value == null) return false;

    final parameter = WaterQualityParameter.fromId(parameterId);
    return parameter != null && !parameter.isValueInRange(value);
  }

  /// Get all parameters that are out of range
  List<String> getOutOfRangeParameters() {
    return parameterValues.entries
        .where((entry) => isParameterOutOfRange(entry.key))
        .map((entry) => entry.key)
        .toList();
  }

  /// Add or update a parameter value
  WaterQualityTestEvent withParameterValue(String parameterId, double value) {
    final updatedValues = Map<String, double>.from(parameterValues);
    updatedValues[parameterId] = value;

    return copyWith(parameterValues: updatedValues);
  }

  /// Remove a parameter value
  WaterQualityTestEvent withoutParameter(String parameterId) {
    final updatedValues = Map<String, double>.from(parameterValues);
    updatedValues.remove(parameterId);

    return copyWith(parameterValues: updatedValues);
  }
}
