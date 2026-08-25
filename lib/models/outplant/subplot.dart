import 'package:seafoundry_community/models/events/outplant_geometry.dart';
import 'package:seafoundry_community/models/records/graph_node_record.dart';
import 'package:seafoundry_community/models/records/inventory_record.dart';
import 'package:seafoundry_community/models/records/record.dart';
import 'package:seafoundry_community/models/types/model_type.dart';
import 'package:seafoundry_community/models/utils/json_casts.dart';

/// A subplot within a zone at an outplanting site.
///
/// Subplots are the second level of subdivision in the site hierarchy:
/// Site -> Zone -> Subplot -> Tag
///
/// Each subplot can have its own GPS location and serves as the organizational
/// unit for individual tagged organisms. Subplots are useful for tracking
/// organisms in a specific micro-location within a larger zone.
class Subplot extends InventoryRecord with GraphNodeRecord {
  const Subplot({
    required super.id,
    required super.createdAt,
    required super.createdById,
    required super.updatedAt,
    required super.updatedById,
    required super.organizationId,
    required super.urlPath,
    required super.internalPath,
    required super.slug,
    required this.zoneId,
    required this.siteId,
    required this.name,
    this.description,
    this.location,
    this.tagPrefix,
    this.capacity,
    this.sortOrder,
    super.metadata,
  });

  Subplot.fromJson(super.json)
    : zoneId = json['zoneId'] ?? Missing.string,
      siteId = json['siteId'] ?? Missing.string,
      name = json['name'] ?? Missing.string,
      description = json['description'],
      location = json['location'] is Map<String, dynamic>
          ? GeoCoordinate.fromJson(
              Map<String, dynamic>.from(json['location'] as Map),
            )
          : null,
      tagPrefix = json['tagPrefix'],
      capacity = safeInt(json['capacity']),
      sortOrder = safeInt(json['sortOrder']),
      super.fromJson();

  Subplot.partial({
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
    String? zoneId,
    String? siteId,
    String? name,
    String? description,
    GeoCoordinate? location,
    String? tagPrefix,
    int? capacity,
    int? sortOrder,
    super.metadata,
  }) : zoneId = zoneId ?? json?['zoneId'] ?? Missing.string,
       siteId = siteId ?? json?['siteId'] ?? Missing.string,
       name = name ?? json?['name'] ?? Missing.string,
       description = description ?? json?['description'],
       location = location ??
           (json?['location'] is Map<String, dynamic>
               ? GeoCoordinate.fromJson(
                   Map<String, dynamic>.from(json!['location'] as Map),
                 )
               : null),
       tagPrefix = tagPrefix ?? json?['tagPrefix'],
       capacity = capacity ?? safeInt(json?['capacity']),
       sortOrder = sortOrder ?? safeInt(json?['sortOrder']),
       super.partial();

  /// The ID of the parent zone this subplot belongs to.
  final String zoneId;

  /// The ID of the site this subplot belongs to (denormalized for queries).
  final String siteId;

  /// Display name for this subplot (e.g., "Subplot 1", "Coral Head A").
  @override
  final String name;

  /// Optional description providing additional context about the subplot.
  final String? description;

  /// GPS location of this subplot for precise positioning.
  final GeoCoordinate? location;

  /// Optional prefix for auto-generating tag IDs within this subplot.
  /// For example, "S1-" would generate tags like "S1-001", "S1-002".
  final String? tagPrefix;

  /// Optional maximum number of organisms this subplot can hold.
  final int? capacity;

  /// Optional sort order for display purposes.
  final int? sortOrder;

  @override
  ModelType get modelType => ModelType.subplot;

  @override
  Map<String, dynamic> toJson() {
    return {
      'zoneId': zoneId,
      'siteId': siteId,
      'name': name,
      if (description != null) 'description': description,
      if (location != null) 'location': location!.toJson(),
      if (tagPrefix != null) 'tagPrefix': tagPrefix,
      if (capacity != null) 'capacity': capacity,
      if (sortOrder != null) 'sortOrder': sortOrder,
      ...super.toJson(),
    };
  }

  @override
  Subplot copyWith({
    String? id,
    String? createdAt,
    String? createdById,
    String? updatedAt,
    String? updatedById,
    String? organizationId,
    String? urlPath,
    String? internalPath,
    String? slug,
    String? zoneId,
    String? siteId,
    String? name,
    String? description,
    GeoCoordinate? location,
    bool clearLocation = false,
    String? tagPrefix,
    int? capacity,
    int? sortOrder,
    Map<String, dynamic>? metadata,
  }) {
    return Subplot(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      createdById: createdById ?? this.createdById,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedById: updatedById ?? this.updatedById,
      organizationId: organizationId ?? this.organizationId,
      urlPath: urlPath ?? this.urlPath,
      internalPath: internalPath ?? this.internalPath,
      slug: slug ?? this.slug,
      zoneId: zoneId ?? this.zoneId,
      siteId: siteId ?? this.siteId,
      name: name ?? this.name,
      description: description ?? this.description,
      location: clearLocation ? null : (location ?? this.location),
      tagPrefix: tagPrefix ?? this.tagPrefix,
      capacity: capacity ?? this.capacity,
      sortOrder: sortOrder ?? this.sortOrder,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool validate() {
    if (zoneId.isEmpty || siteId.isEmpty || name.isEmpty) {
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
      [zoneId, siteId, name, description, location, tagPrefix, capacity, sortOrder];

  /// Whether this subplot has GPS coordinates defined.
  bool get hasLocation => location != null;

  /// Generate a tag ID using this subplot's prefix and a sequence number.
  /// Returns null if no tagPrefix is configured.
  String? generateTagId(int sequenceNumber) {
    if (tagPrefix == null) return null;
    return '$tagPrefix${sequenceNumber.toString().padLeft(3, '0')}';
  }
}
