// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/types/planned_action_type.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

/// A planned allocation of organisms for a mission.
///
/// [MissionAllocation] represents a specific organism and quantity that is
/// planned to be used during a mission. It includes optional metadata for
/// display purposes (record name, species, genet) and references to
/// the source and target groups.
///
/// ## Usage
/// ```dart
/// final allocation = MissionAllocation(
///   organismId: 'coral-123',
///   recordName: 'Coral Colony A',
///   speciesId: 'species-456',
///   quantity: 10,
///   plannedActionType: PlannedActionType.outplant,
///   targetGroupId: 'plot-789',
/// );
/// ```
class MissionAllocation extends Equatable {
  /// Unique identifier of the organism being allocated
  final String organismId;

  /// Display name of the record (snapshot for display purposes)
  final String? recordName;

  /// Species identifier for the organism
  final String? speciesId;

  /// Genet identifier for the organism (for clonal tracking)
  final String? genetId;

  /// Source group ID where the organism currently resides
  final String? sourceGroupId;

  /// Number of units (fragments, colonies, etc.) allocated
  final int quantity;

  /// Target group ID for the allocation (e.g., target plot/patch for outplanting)
  final String? targetGroupId;

  /// The type of action planned for this allocation
  ///
  /// Common values:
  /// - [PlannedActionType.outplant] - Transplant to reef
  /// - [PlannedActionType.fragment] - Create fragments
  /// - [PlannedActionType.monitor] - Observation/monitoring
  final PlannedActionType? plannedActionType;

  /// Additional notes about this allocation
  final String? notes;

  const MissionAllocation({
    required this.organismId,
    this.recordName,
    this.speciesId,
    this.genetId,
    this.sourceGroupId,
    required this.quantity,
    this.targetGroupId,
    this.plannedActionType,
    this.notes,
  });

  /// Maximum allowed quantity for an allocation.
  /// Prevents unreasonable values from data entry errors or malformed data.
  static const int maxQuantity = 10000;

  /// Creates a [MissionAllocation] from a JSON map.
  ///
  /// Throws [FormatException] if [organismId] is missing or empty,
  /// as an allocation without an organism is invalid.
  ///
  /// For lenient parsing that returns null on invalid data, use [tryFromJson].
  factory MissionAllocation.fromJson(Map<String, dynamic> json) {
    final organismId = json['organismId'] as String?;
    if (organismId == null || organismId.isEmpty) {
      throw FormatException(
        'MissionAllocation requires a non-empty organismId, got: $organismId',
      );
    }

    return MissionAllocation(
      organismId: organismId,
      recordName: json['recordName'] as String?,
      speciesId: json['speciesId'] as String?,
      genetId: json['genetId'] as String?,
      sourceGroupId: json['sourceGroupId'] as String?,
      quantity: safeInt(json['quantity']) ?? 0,
      targetGroupId: json['targetGroupId'] as String?,
      plannedActionType:
          PlannedActionType.fromId(json['plannedActionTypeId'] as String?),
      notes: json['notes'] as String?,
    );
  }

  /// Attempts to create a [MissionAllocation] from a JSON map.
  ///
  /// Returns `null` if [organismId] is missing or empty.
  /// Use this for lenient parsing where invalid allocations should be skipped.
  static MissionAllocation? tryFromJson(Map<String, dynamic> json) {
    final organismId = json['organismId'] as String?;
    if (organismId == null || organismId.isEmpty) {
      return null;
    }

    return MissionAllocation(
      organismId: organismId,
      recordName: json['recordName'] as String?,
      speciesId: json['speciesId'] as String?,
      genetId: json['genetId'] as String?,
      sourceGroupId: json['sourceGroupId'] as String?,
      quantity: safeInt(json['quantity']) ?? 0,
      targetGroupId: json['targetGroupId'] as String?,
      plannedActionType:
          PlannedActionType.fromId(json['plannedActionTypeId'] as String?),
      notes: json['notes'] as String?,
    );
  }

  /// Converts this allocation to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'organismId': organismId,
      if (recordName != null) 'recordName': recordName,
      if (speciesId != null) 'speciesId': speciesId,
      if (genetId != null) 'genetId': genetId,
      if (sourceGroupId != null) 'sourceGroupId': sourceGroupId,
      'quantity': quantity,
      if (targetGroupId != null) 'targetGroupId': targetGroupId,
      if (plannedActionType != null)
        'plannedActionTypeId': plannedActionType!.id,
      if (notes != null) 'notes': notes,
    };
  }

  /// Whether this allocation has valid data.
  ///
  /// Requires a non-empty [organismId] and a [quantity] between 1 and [maxQuantity].
  bool get isValid =>
      organismId.isNotEmpty && quantity > 0 && quantity <= maxQuantity;

  /// Creates a copy of this allocation with the specified fields replaced
  MissionAllocation copyWith({
    String? organismId,
    String? recordName,
    String? speciesId,
    String? genetId,
    String? sourceGroupId,
    int? quantity,
    String? targetGroupId,
    PlannedActionType? plannedActionType,
    String? notes,
    bool clearRecordName = false,
    bool clearSpeciesId = false,
    bool clearGenetId = false,
    bool clearSourceGroupId = false,
    bool clearTargetGroupId = false,
    bool clearPlannedActionType = false,
    bool clearNotes = false,
  }) {
    return MissionAllocation(
      organismId: organismId ?? this.organismId,
      recordName: clearRecordName ? null : (recordName ?? this.recordName),
      speciesId: clearSpeciesId ? null : (speciesId ?? this.speciesId),
      genetId: clearGenetId ? null : (genetId ?? this.genetId),
      sourceGroupId:
          clearSourceGroupId ? null : (sourceGroupId ?? this.sourceGroupId),
      quantity: quantity ?? this.quantity,
      targetGroupId:
          clearTargetGroupId ? null : (targetGroupId ?? this.targetGroupId),
      plannedActionType: clearPlannedActionType
          ? null
          : (plannedActionType ?? this.plannedActionType),
      notes: clearNotes ? null : (notes ?? this.notes),
    );
  }

  @override
  List<Object?> get props => [
        organismId,
        recordName,
        speciesId,
        genetId,
        sourceGroupId,
        quantity,
        targetGroupId,
        plannedActionType,
        notes,
      ];
}
