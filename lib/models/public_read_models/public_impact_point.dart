// @tier: community
import 'package:seafoundry_app/models/records/record.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

enum PublicImpactPointType { holding, outplant }

/// Sanitized holdings/outplant snapshot for the public impact map.
class PublicImpactPoint extends Record {
  const PublicImpactPoint({
    required super.id,
    required super.createdAt,
    required super.createdById,
    required super.updatedAt,
    required super.updatedById,
    required super.organizationId,
    super.metadata,
    required this.latitude,
    required this.longitude,
    required this.pointType,
    required this.magnitude,
    this.label,
    this.siteId,
    this.genetBreakdown = const {},
    this.provenanceIdBreakdown = const {},
    this.speciesBreakdown = const {},
  });

  PublicImpactPoint.fromJson(super.json)
    : latitude = safeDouble(json['latitude']) ?? 0,
      longitude = safeDouble(json['longitude']) ?? 0,
      pointType = _typeFrom(json['pointType']) ?? PublicImpactPointType.holding,
      magnitude = safeInt(json['magnitude']) ?? 0,
      label = json['label'] is String ? json['label'] as String : null,
      siteId = json['siteId'] is String
          ? json['siteId'] as String
          : (json['metadata'] is Map<String, dynamic>
              ? (json['metadata'] as Map<String, dynamic>)['siteId'] as String?
              : null),
      genetBreakdown = _parseBreakdown(
        json['genetBreakdown'] ??
            (json['metadata'] is Map<String, dynamic>
                ? (json['metadata'] as Map<String, dynamic>)['genetBreakdown']
                : null),
      ),
      provenanceIdBreakdown = _parseBreakdown(
        json['provenanceIdBreakdown'] ??
            (json['metadata'] is Map<String, dynamic>
                ? (json['metadata'] as Map<String, dynamic>)
                    ['provenanceIdBreakdown']
                : null),
      ),
      speciesBreakdown = _parseBreakdown(
        json['speciesBreakdown'] ??
            (json['metadata'] is Map<String, dynamic>
                ? (json['metadata'] as Map<String, dynamic>)
                    ['speciesBreakdown']
                : null),
      ),
      super.fromJson();

  /// Convenience constructor for preview/sample data.
  const PublicImpactPoint.sample({
    required super.id,
    required super.organizationId,
    required this.latitude,
    required this.longitude,
    required this.pointType,
    required this.magnitude,
    this.label,
    this.siteId,
    this.genetBreakdown = const {},
    this.provenanceIdBreakdown = const {},
    this.speciesBreakdown = const {},
  }) : super(
         createdAt: Missing.dateTimeString,
         createdById: Missing.string,
         updatedAt: Missing.dateTimeString,
         updatedById: Missing.string,
       );

  final double latitude;
  final double longitude;
  final PublicImpactPointType pointType;
  final int magnitude;
  final String? label;
  final String? siteId;
  final Map<String, int> genetBreakdown;
  final Map<String, int> provenanceIdBreakdown;
  final Map<String, int> speciesBreakdown;

  @override
  ModelType get modelType => ModelType.publicImpactPoint;

  @override
  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'pointType': pointType.name,
    'magnitude': magnitude,
    if (label != null && label!.isNotEmpty) 'label': label,
    if (siteId != null && siteId!.isNotEmpty) 'siteId': siteId,
    if (genetBreakdown.isNotEmpty) 'genetBreakdown': genetBreakdown,
    if (provenanceIdBreakdown.isNotEmpty)
      'provenanceIdBreakdown': provenanceIdBreakdown,
    if (speciesBreakdown.isNotEmpty) 'speciesBreakdown': speciesBreakdown,
    ...super.toJson(),
  };

  @override
  PublicImpactPoint copyWith({
    String? id,
    String? createdAt,
    String? createdById,
    String? updatedAt,
    String? updatedById,
    String? organizationId,
    double? latitude,
    double? longitude,
    PublicImpactPointType? pointType,
    int? magnitude,
    String? label,
    String? siteId,
    Map<String, int>? genetBreakdown,
    Map<String, int>? provenanceIdBreakdown,
    Map<String, int>? speciesBreakdown,
    Map<String, dynamic>? metadata,
  }) => PublicImpactPoint(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    createdById: createdById ?? this.createdById,
    updatedAt: updatedAt ?? this.updatedAt,
    updatedById: updatedById ?? this.updatedById,
    organizationId: organizationId ?? this.organizationId,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    pointType: pointType ?? this.pointType,
    magnitude: magnitude ?? this.magnitude,
    label: label ?? this.label,
    siteId: siteId ?? this.siteId,
    genetBreakdown: genetBreakdown ?? this.genetBreakdown,
    provenanceIdBreakdown:
        provenanceIdBreakdown ?? this.provenanceIdBreakdown,
    speciesBreakdown: speciesBreakdown ?? this.speciesBreakdown,
    metadata: metadata ?? this.metadata,
  );

  @override
  List<Object?> get props =>
      super.props +
      [
        latitude,
        longitude,
        pointType,
        magnitude,
        label,
        siteId,
        genetBreakdown,
        provenanceIdBreakdown,
        speciesBreakdown,
      ];

  static PublicImpactPointType? _typeFrom(dynamic raw) {
    if (raw is String) {
      try {
        return PublicImpactPointType.values.byName(raw);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static Map<String, int> _parseBreakdown(dynamic raw) {
    if (raw is Map) {
      final parsed = <String, int>{};
      raw.forEach((key, value) {
        final id = key?.toString().trim();
        if (id == null || id.isEmpty) return;
        final count = _parseBreakdownValue(value);
        if (count == null || count <= 0) return;
        parsed[id] = count;
      });
      return Map.unmodifiable(parsed);
    }
    return const {};
  }

  static int? _parseBreakdownValue(dynamic raw) {
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }
}
