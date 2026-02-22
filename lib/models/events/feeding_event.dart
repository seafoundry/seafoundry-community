// @tier: community
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/husbandry_event.dart';
import 'package:seafoundry_app/models/types/husbandry_event_type.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

/// Types of food used for feeding
class FoodType {
  final String id;
  final String label;

  const FoodType._({required this.id, required this.label});

  /// Create a FoodType from an ID
  static FoodType? fromId(String? id) {
    if (id == null) return null;
    return values.firstWhere(
      (type) => type.id == id,
      orElse: () => FoodType._(id: id, label: 'Custom'),
    );
  }

  /// Rotifers
  static const FoodType rotifers = FoodType._(
    id: 'rotifers',
    label: 'Rotifers',
  );

  /// Artemia (brine shrimp)
  static const FoodType artemia = FoodType._(id: 'artemia', label: 'Artemia');

  /// Phytoplankton
  static const FoodType phytoplankton = FoodType._(
    id: 'phytoplankton',
    label: 'Phytoplankton',
  );

  /// Zooplankton
  static const FoodType zooplankton = FoodType._(
    id: 'zooplankton',
    label: 'Zooplankton',
  );

  /// Coral food
  static const FoodType coralFood = FoodType._(
    id: 'coral_food',
    label: 'Coral Food',
  );

  /// Other food type
  static const FoodType other = FoodType._(id: 'other', label: 'Other');

  /// List of all food types
  static const List<FoodType> values = [
    rotifers,
    artemia,
    phytoplankton,
    zooplankton,
    coralFood,
    other,
  ];
}

/// An event representing a feeding activity
class FeedingEvent extends HusbandryEvent {
  /// Type of food used
  final String foodTypeId;

  /// Amount of food in milliliters
  final double? amount;

  /// Unit of measurement (ml, g, etc.)
  final String? unit;

  FeedingEvent({
    required super.id,
    required this.foodTypeId,
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
  }) : super(eventTypeId: HusbandryEventType.feedingId);

  FeedingEvent.fromJson(super.json)
    : foodTypeId = json['foodTypeId'] ?? 'other',
      amount = safeDouble(json['amount']),
      unit = json['unit'],
      super.fromJson();

  FeedingEvent.partial({
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
    String? foodTypeId,
    double? amount,
    String? unit,
  }) : foodTypeId = foodTypeId ?? json?['foodTypeId'] ?? 'other',
       amount =
           amount ??
           safeDouble(json?['amount']),
       unit = unit ?? json?['unit'],
       super.partial();

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'foodTypeId': foodTypeId,
      if (amount != null) 'amount': amount,
      if (unit != null) 'unit': unit,
    };
  }

  @override
  bool validate() {
    return super.validate() && foodTypeId.isNotEmpty;
  }

  @override
  FeedingEvent copyWith({
    String? id,
    String? foodTypeId,
    double? amount,
    String? unit,
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
    return FeedingEvent(
      id: id ?? this.id,
      foodTypeId: foodTypeId ?? this.foodTypeId,
      amount: amount ?? this.amount,
      unit: unit ?? this.unit,
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
  List<Object?> get props => super.props + [foodTypeId, amount, unit];

  /// Get the food type
  FoodType get foodType => FoodType.fromId(foodTypeId) ?? FoodType.other;

  /// Get the formatted amount with unit
  String? get formattedAmount {
    if (amount == null) return null;

    final formattedValue = amount == amount!.toInt()
        ? amount!.toInt().toString()
        : amount.toString();

    return unit != null ? '$formattedValue $unit' : formattedValue;
  }
}
