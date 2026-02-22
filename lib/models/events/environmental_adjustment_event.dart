// @tier: community
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/husbandry_event.dart';
import 'package:seafoundry_app/models/types/husbandry_event_type.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

/// Types of environmental adjustments
class EnvironmentalAdjustmentType {
  final String id;
  final String label;

  const EnvironmentalAdjustmentType._({required this.id, required this.label});

  static EnvironmentalAdjustmentType? fromId(String? id) {
    if (id == null) return null;
    return values.firstWhere(
      (type) => type.id == id,
      orElse: () => EnvironmentalAdjustmentType._(id: id, label: 'Unknown'),
    );
  }

  static const EnvironmentalAdjustmentType lightingChange =
      EnvironmentalAdjustmentType._(
        id: 'lighting_change',
        label: 'Lighting Change',
      );

  static const EnvironmentalAdjustmentType temperatureAdjustment =
      EnvironmentalAdjustmentType._(
        id: 'temperature_adjustment',
        label: 'Temperature Adjustment',
      );

  static const EnvironmentalAdjustmentType flowAdjustment =
      EnvironmentalAdjustmentType._(
        id: 'flow_adjustment',
        label: 'Flow Adjustment',
      );

  static const EnvironmentalAdjustmentType waterChange =
      EnvironmentalAdjustmentType._(id: 'water_change', label: 'Water Change');

  static const EnvironmentalAdjustmentType salinityAdjustment =
      EnvironmentalAdjustmentType._(
        id: 'salinity_adjustment',
        label: 'Salinity Adjustment',
      );

  static const EnvironmentalAdjustmentType phAdjustment =
      EnvironmentalAdjustmentType._(
        id: 'ph_adjustment',
        label: 'pH Adjustment',
      );

  static const EnvironmentalAdjustmentType other =
      EnvironmentalAdjustmentType._(id: 'other', label: 'Other');

  static const List<EnvironmentalAdjustmentType> values = [
    lightingChange,
    temperatureAdjustment,
    flowAdjustment,
    waterChange,
    salinityAdjustment,
    phAdjustment,
    other,
  ];
}

/// An event representing an environmental adjustment
class EnvironmentalAdjustmentEvent extends HusbandryEvent {
  /// Type of adjustment made
  final String adjustmentTypeId;

  /// Previous value or setting
  final String? previousValue;

  /// New value or setting
  final String? newValue;

  /// Amount changed (for water changes, etc.)
  final double? amount;

  /// Unit for amount (liters, gallons, %, etc.)
  final String? unit;

  EnvironmentalAdjustmentEvent({
    required super.id,
    required this.adjustmentTypeId,
    this.previousValue,
    this.newValue,
    this.amount,
    this.unit,
    super.imageUrl,
    super.comment,
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
         eventTypeId: HusbandryEventType.environmentalAdjustmentId,
       );

  EnvironmentalAdjustmentEvent.fromJson(super.json)
    : adjustmentTypeId = json['adjustmentTypeId'] ?? 'other',
      previousValue = json['previousValue'],
      newValue = json['newValue'],
      amount = safeDouble(json['amount']),
      unit = json['unit'],
      super.fromJson();

  EnvironmentalAdjustmentEvent.partial({
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
    String? adjustmentTypeId,
    String? previousValue,
    String? newValue,
    double? amount,
    String? unit,
  }) : adjustmentTypeId =
           adjustmentTypeId ?? json?['adjustmentTypeId'] ?? 'other',
       previousValue = previousValue ?? json?['previousValue'],
       newValue = newValue ?? json?['newValue'],
       amount =
           amount ??
           safeDouble(json?['amount']),
       unit = unit ?? json?['unit'],
       super.partial();

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'adjustmentTypeId': adjustmentTypeId,
      if (previousValue != null) 'previousValue': previousValue,
      if (newValue != null) 'newValue': newValue,
      if (amount != null) 'amount': amount,
      if (unit != null) 'unit': unit,
    };
  }

  @override
  bool validate() {
    return super.validate() && adjustmentTypeId.isNotEmpty;
  }

  @override
  EnvironmentalAdjustmentEvent copyWith({
    String? id,
    String? adjustmentTypeId,
    String? previousValue,
    String? newValue,
    double? amount,
    String? unit,
    String? imageUrl,
    String? comment,
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
    return EnvironmentalAdjustmentEvent(
      id: id ?? this.id,
      adjustmentTypeId: adjustmentTypeId ?? this.adjustmentTypeId,
      previousValue: previousValue ?? this.previousValue,
      newValue: newValue ?? this.newValue,
      amount: amount ?? this.amount,
      unit: unit ?? this.unit,
      imageUrl: imageUrl ?? this.imageUrl,
      comment: comment ?? this.comment,
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
  List<Object?> get props => [
    ...super.props,
    adjustmentTypeId,
    previousValue,
    newValue,
    amount,
    unit,
  ];

  /// Get the adjustment type
  EnvironmentalAdjustmentType get adjustmentType =>
      EnvironmentalAdjustmentType.fromId(adjustmentTypeId) ??
      EnvironmentalAdjustmentType.other;

  /// Get formatted amount with unit
  String? get formattedAmount {
    if (amount == null) return null;
    final value = amount == amount!.toInt()
        ? amount!.toInt().toString()
        : amount.toString();
    return unit != null ? '$value $unit' : value;
  }

  /// Get change description
  String? get changeDescription {
    if (previousValue != null && newValue != null) {
      return '$previousValue → $newValue';
    }
    return newValue;
  }
}
