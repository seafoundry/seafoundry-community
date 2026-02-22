// @tier: community
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/husbandry_event.dart';
import 'package:seafoundry_app/models/types/gene_bank_event_type.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

/// An event representing a viability test for gene bank genetic material
///
/// Tracks viability testing to assess the health and potential for successful
/// propagation of stored genetic material.
class GeneBankViabilityTestEvent extends HusbandryEvent {
  /// Test type (e.g., "visual", "culture", "staining", "other")
  final String testType;

  /// Viability percentage (0-100)
  final double? viabilityPercentage;

  /// Number of samples tested
  final int? samplesTested;

  /// Overall result (e.g., "viable", "marginal", "non-viable")
  final String? result;

  /// Notes about test methodology or conditions
  final String? testNotes;

  GeneBankViabilityTestEvent({
    required super.id,
    required this.testType,
    this.viabilityPercentage,
    this.samplesTested,
    this.result,
    this.testNotes,
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
  }) : super(eventTypeId: GeneBankEventType.viabilityTestId);

  GeneBankViabilityTestEvent.fromJson(super.json)
    : testType = json['testType'] ?? 'visual',
      viabilityPercentage = safeDouble(json['viabilityPercentage']),
      samplesTested = safeInt(json['samplesTested']),
      result = json['result'],
      testNotes = json['testNotes'],
      super.fromJson();

  GeneBankViabilityTestEvent.partial({
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
    String? testType,
    double? viabilityPercentage,
    int? samplesTested,
    String? result,
    String? testNotes,
  }) : testType = testType ?? json?['testType'] ?? 'visual',
       viabilityPercentage =
           viabilityPercentage ??
           safeDouble(json?['viabilityPercentage']),
       samplesTested = samplesTested ?? safeInt(json?['samplesTested']),
       result = result ?? json?['result'],
       testNotes = testNotes ?? json?['testNotes'],
       super.partial();

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      'testType': testType,
      if (viabilityPercentage != null)
        'viabilityPercentage': viabilityPercentage,
      if (samplesTested != null) 'samplesTested': samplesTested,
      if (result != null) 'result': result,
      if (testNotes != null) 'testNotes': testNotes,
    };
  }

  @override
  bool validate() {
    return super.validate() &&
        testType.isNotEmpty &&
        (viabilityPercentage == null ||
            (viabilityPercentage! >= 0 && viabilityPercentage! <= 100));
  }

  @override
  GeneBankViabilityTestEvent copyWith({
    String? id,
    String? testType,
    double? viabilityPercentage,
    int? samplesTested,
    String? result,
    String? testNotes,
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
    return GeneBankViabilityTestEvent(
      id: id ?? this.id,
      testType: testType ?? this.testType,
      viabilityPercentage: viabilityPercentage ?? this.viabilityPercentage,
      samplesTested: samplesTested ?? this.samplesTested,
      result: result ?? this.result,
      testNotes: testNotes ?? this.testNotes,
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
      [testType, viabilityPercentage, samplesTested, result, testNotes];
}
