// @tier: community
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/husbandry_event.dart';
import 'package:seafoundry_app/models/types/husbandry_event_type.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

/// Types of treatments
class TreatmentType {
  final String id;
  final String label;

  const TreatmentType._({required this.id, required this.label});

  static TreatmentType? fromId(String? id) {
    if (id == null) return null;
    return values.firstWhere(
      (type) => type.id == id,
      orElse: () => TreatmentType._(id: id, label: 'Unknown'),
    );
  }

  static const TreatmentType medication = TreatmentType._(
    id: 'medication',
    label: 'Medication',
  );

  static const TreatmentType antibiotics = TreatmentType._(
    id: 'antibiotics',
    label: 'Antibiotics',
  );

  static const TreatmentType antifungal = TreatmentType._(
    id: 'antifungal',
    label: 'Antifungal',
  );

  static const TreatmentType parasiticide = TreatmentType._(
    id: 'parasiticide',
    label: 'Parasiticide',
  );

  static const TreatmentType dip = TreatmentType._(
    id: 'dip',
    label: 'Dip/Bath',
  );

  static const TreatmentType iodine = TreatmentType._(
    id: 'iodine',
    label: 'Iodine Treatment',
  );

  static const TreatmentType freshwaterDip = TreatmentType._(
    id: 'freshwater_dip',
    label: 'Freshwater Dip',
  );

  static const TreatmentType other = TreatmentType._(
    id: 'other',
    label: 'Other',
  );

  static const List<TreatmentType> values = [
    medication,
    antibiotics,
    antifungal,
    parasiticide,
    dip,
    iodine,
    freshwaterDip,
    other,
  ];
}

/// An event representing a treatment activity
class TreatmentEvent extends HusbandryEvent {
  /// Type of treatment applied
  final String treatmentTypeId;

  /// Name of medication or treatment product
  final String? medicationName;

  /// Dosage amount
  final double? dosage;

  /// Dosage unit (ml, mg, drops, etc.)
  final String? dosageUnit;

  /// Duration of treatment in minutes (for dips/baths)
  final int? durationMinutes;

  TreatmentEvent({
    required super.id,
    required this.treatmentTypeId,
    this.medicationName,
    this.dosage,
    this.dosageUnit,
    this.durationMinutes,
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
  }) : super(eventTypeId: HusbandryEventType.treatmentId);

  TreatmentEvent.fromJson(super.json)
    : treatmentTypeId = json['treatmentTypeId'] ?? 'other',
      medicationName = json['medicationName'],
      dosage = safeDouble(json['dosage']),
      dosageUnit = json['dosageUnit'],
      durationMinutes = json['durationMinutes'],
      super.fromJson();

  TreatmentEvent.partial({
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
    String? treatmentTypeId,
    String? medicationName,
    double? dosage,
    String? dosageUnit,
    int? durationMinutes,
  }) : treatmentTypeId = treatmentTypeId ?? json?['treatmentTypeId'] ?? 'other',
       medicationName = medicationName ?? json?['medicationName'],
       dosage =
           dosage ??
           safeDouble(json?['dosage']),
       dosageUnit = dosageUnit ?? json?['dosageUnit'],
       durationMinutes = durationMinutes ?? json?['durationMinutes'],
       super.partial();

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'treatmentTypeId': treatmentTypeId,
      if (medicationName != null) 'medicationName': medicationName,
      if (dosage != null) 'dosage': dosage,
      if (dosageUnit != null) 'dosageUnit': dosageUnit,
      if (durationMinutes != null) 'durationMinutes': durationMinutes,
    };
  }

  @override
  bool validate() {
    return super.validate() && treatmentTypeId.isNotEmpty;
  }

  @override
  TreatmentEvent copyWith({
    String? id,
    String? treatmentTypeId,
    String? medicationName,
    double? dosage,
    String? dosageUnit,
    int? durationMinutes,
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
    return TreatmentEvent(
      id: id ?? this.id,
      treatmentTypeId: treatmentTypeId ?? this.treatmentTypeId,
      medicationName: medicationName ?? this.medicationName,
      dosage: dosage ?? this.dosage,
      dosageUnit: dosageUnit ?? this.dosageUnit,
      durationMinutes: durationMinutes ?? this.durationMinutes,
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
    treatmentTypeId,
    medicationName,
    dosage,
    dosageUnit,
    durationMinutes,
  ];

  /// Get the treatment type
  TreatmentType get treatmentType =>
      TreatmentType.fromId(treatmentTypeId) ?? TreatmentType.other;

  /// Get formatted dosage with unit
  String? get formattedDosage {
    if (dosage == null) return null;
    final value = dosage == dosage!.toInt()
        ? dosage!.toInt().toString()
        : dosage.toString();
    return dosageUnit != null ? '$value $dosageUnit' : value;
  }
}
