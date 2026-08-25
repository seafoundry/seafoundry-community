import 'package:seafoundry_community/models/events/outplant_geometry.dart';
import 'package:seafoundry_community/models/records/graph_node_record.dart';
import 'package:seafoundry_community/models/records/inventory_record.dart';
import 'package:seafoundry_community/models/records/record.dart';
import 'package:seafoundry_community/models/types/model_type.dart';
import 'package:seafoundry_community/models/utils/json_casts.dart';

/// A zone within an outplanting site.
///
/// Zones are the first level of subdivision in the site hierarchy:
/// Site -> Zone -> Subplot -> Tag
///
/// Each zone can have its own GPS coordinates (centroid) and boundary polygon
/// for precise geographic tracking of outplanted organisms.
class Zone extends InventoryRecord with GraphNodeRecord {
  const Zone({
    required super.id,
    required super.createdAt,
    required super.createdById,
    required super.updatedAt,
    required super.updatedById,
    required super.organizationId,
    required super.urlPath,
    required super.internalPath,
    required super.slug,
    required this.siteId,
    required this.name,
    this.description,
    this.centroid,
    this.boundary,
    this.sortOrder,
    super.metadata,
  });

  Zone.fromJson(super.json)
    : siteId = json['siteId'] ?? Missing.string,
      name = json['name'] ?? Missing.string,
      description = json['description'],
      centroid = json['centroid'] is Map<String, dynamic>
          ? GeoCoordinate.fromJson(
              Map<String, dynamic>.from(json['centroid'] as Map),
            )
          : null,
      boundary = _parseBoundary(json['boundary']),
      sortOrder = safeInt(json['sortOrder']),
      super.fromJson();

  Zone.partial({
    super.json,
    super.id,
    super.createdAt,
    super.createdById,
    super.updatedAt,
    super.updatedById,
    super.organizationId,
    super.urlPath,
    super.internalPath,
    super.slug,
    String? siteId,
    String? name,
    String? description,
    GeoCoordinate? centroid,
    List<GeoCoordinate>? boundary,
    int? sortOrder,
    super.metadata,
  }) : siteId = siteId ?? json?['siteId'] ?? Missing.string,
       name = name ?? json?['name'] ?? Missing.string,
       description = description ?? json?['description'],
       centroid = centroid ??
           (json?['centroid'] is Map<String, dynamic>
               ? GeoCoordinate.fromJson(
                   Map<String, dynamic>.from(json!['centroid'] as Map),
                 )
               : null),
       boundary = boundary ?? _parseBoundary(json?['boundary']),
       sortOrder = sortOrder ?? safeInt(json?['sortOrder']),
       super.partial();

  /// The ID of the parent site this zone belongs to.
  final String siteId;

  /// Display name for this zone (e.g., "Zone A", "North Reef Section").
  @override
  final String name;

  /// Optional description providing additional context about the zone.
  final String? description;

  /// Center point of this zone for map display and distance calculations.
  final GeoCoordinate? centroid;

  /// Polygon boundary defining the geographic extent of this zone.
  /// Used for spatial queries and map visualization.
  final List<GeoCoordinate>? boundary;

  /// Optional sort order for display purposes.
  final int? sortOrder;

  @override
  ModelType get modelType => ModelType.zone;

  @override
  Map<String, dynamic> toJson() {
    return {
      'siteId': siteId,
      'name': name,
      if (description != null) 'description': description,
      if (centroid != null) 'centroid': centroid!.toJson(),
      if (boundary != null && boundary!.isNotEmpty)
        'boundary': boundary!.map((c) => c.toJson()).toList(),
      if (sortOrder != null) 'sortOrder': sortOrder,
      ...super.toJson(),
    };
  }

  @override
  Zone copyWith({
    String? id,
    String? createdAt,
    String? createdById,
    String? updatedAt,
    String? updatedById,
    String? organizationId,
    String? urlPath,
    String? internalPath,
    String? slug,
    String? siteId,
    String? name,
    String? description,
    GeoCoordinate? centroid,
    bool clearCentroid = false,
    List<GeoCoordinate>? boundary,
    bool clearBoundary = false,
    int? sortOrder,
    Map<String, dynamic>? metadata,
  }) {
    return Zone(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      createdById: createdById ?? this.createdById,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedById: updatedById ?? this.updatedById,
      organizationId: organizationId ?? this.organizationId,
      urlPath: urlPath ?? this.urlPath,
      internalPath: internalPath ?? this.internalPath,
      slug: slug ?? this.slug,
      siteId: siteId ?? this.siteId,
      name: name ?? this.name,
      description: description ?? this.description,
      centroid: clearCentroid ? null : (centroid ?? this.centroid),
      boundary: clearBoundary ? null : (boundary ?? this.boundary),
      sortOrder: sortOrder ?? this.sortOrder,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool validate() {
    if (siteId.isEmpty || name.isEmpty) {
      return false;
    }
    return super.validate() &&
        id.isNotEmpty &&
        createdAt.isNotEmpty &&
        createdById.isNotEmpty &&
        updatedAt.isNotEmpty &&
        updatedById.isNotEmpty &&
        organizationId.isNotEmpty &&
        urlPath.isNotEmpty &&
        internalPath.isNotEmpty &&
        slug.isNotEmpty;
  }

  @override
  List<Object?> get props =>
      super.props +
      [siteId, name, description, centroid, boundary, sortOrder];

  /// Whether this zone has geographic coordinates defined.
  bool get hasGeometry => centroid != null || (boundary?.isNotEmpty ?? false);

  static List<GeoCoordinate>? _parseBoundary(dynamic raw) {
    if (raw is! List) return null;
    final coords = <GeoCoordinate>[];
    for (final entry in raw) {
      if (entry is Map<String, dynamic>) {
        coords.add(GeoCoordinate.fromJson(entry));
      } else if (entry is Map) {
        coords.add(GeoCoordinate.fromJson(Map<String, dynamic>.from(entry)));
      }
    }
    return coords.isEmpty ? null : List<GeoCoordinate>.unmodifiable(coords);
  }
}
