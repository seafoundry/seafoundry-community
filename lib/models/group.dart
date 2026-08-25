import 'package:seafoundry_community/models/model_interfaces.dart';
import 'package:seafoundry_community/models/records/graph_node_record.dart';
import 'package:seafoundry_community/models/records/inventory_record.dart';
import 'package:seafoundry_community/models/records/record.dart';
import 'package:seafoundry_community/models/types/group_type.dart';
import 'package:seafoundry_community/models/types/model_type.dart';
import 'package:seafoundry_community/models/utils/json_casts.dart';
import 'package:seafoundry_community/services/logging_service.dart';

class Group extends InventoryRecord with GraphNodeRecord, GroupParent {
  const Group({
    required super.id,
    required super.createdById,
    required super.createdAt,
    required super.updatedAt,
    required super.updatedById,
    required super.organizationId,
    required this.groupTypeId,
    required this.name,
    this.description,
    this.capacity,
    required this.siteId,
    required this.parentId,
    this.rowIndex,
    this.colIndex,
    required super.urlPath,
    required super.internalPath,
    required super.slug,
    super.metadata,
  });

  Group.fromJson(super.json)
    : groupTypeId = json['groupTypeId'] ??
          json['createdEvent']?['groupTypeId'] ??
          Missing.string,
      name = json['name'] ?? json['createdEvent']?['name'] ?? Missing.string,
      description = json['description'] ?? json['createdEvent']?['description'],
      capacity = json['capacity'] ?? json['createdEvent']?['capacity'],
      siteId =
          json['siteId'] ?? json['createdEvent']?['siteId'] ?? Missing.string,
      parentId = json['parentId'] ??
          json['createdEvent']?['parentId'] ??
          '',  // Empty string for root groups, not Missing.string
      rowIndex =
          safeInt(json['rowIndex']) ??
          safeInt(json['createdEvent']?['rowIndex']),
      colIndex =
          safeInt(json['colIndex']) ??
          safeInt(json['createdEvent']?['colIndex']),
      super.fromJson();

  Group.partial({
    super.json,
    super.id,
    super.internalPath,
    super.slug,
    super.urlPath,
    super.createdById,
    super.createdAt,
    super.updatedAt,
    super.updatedById,
    super.organizationId,
    String? groupTypeId,
    String? name,
    String? description,
    int? capacity,
    String? siteId,
    String? parentId,
    int? rowIndex,
    int? colIndex,
  }) : groupTypeId = groupTypeId ?? json?['groupTypeId'] ?? Missing.string,
       name = name ?? json?['name'] ?? Missing.string,
       description = description ?? json?['description'],
       capacity = capacity ?? json?['capacity'],
       siteId = siteId ?? json?['siteId'] ?? Missing.string,
       parentId = parentId ?? json?['parentId'] ?? Missing.string,
       rowIndex = rowIndex ?? safeInt(json?['rowIndex']),
       colIndex = colIndex ?? safeInt(json?['colIndex']),
       super.partial();

  GroupType get groupType {
    final type = GroupType.builtins[groupTypeId];
    if (type == null) {
      LoggingService.instance.warning(
        'Unknown groupTypeId "$groupTypeId" for group "$name", '
        'falling back to GroupType.group',
      );
      return GroupType.group;
    }
    return type;
  }

  @override
  ModelType get modelType => ModelType.group;

  @override
  final String name;
  final String groupTypeId;
  @override
  final String siteId;
  final String parentId;
  final String? description;
  final int? capacity;
  final int? rowIndex;
  final int? colIndex;

  @override
  Map<String, dynamic> toJson() {
    return {
      "groupTypeId": groupTypeId,
      "name": name,
      "siteId": siteId,
      "parentId": parentId,
      "description": description,
      "capacity": capacity,
      if (rowIndex != null) "rowIndex": rowIndex,
      if (colIndex != null) "colIndex": colIndex,
      ...super.toJson(),
    };
  }

  @override
  Group copyWith({
    String? id,
    String? groupTypeId,
    String? name,
    String? siteId,
    String? parentId,
    String? description,
    int? capacity,
    String? createdAt,
    String? createdById,
    String? updatedAt,
    String? updatedById,
    String? organizationId,
    String? urlPath,
    String? internalPath,
    String? slug,
    int? rowIndex,
    int? colIndex,
    Map<String, dynamic>? metadata,
  }) => Group(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    createdById: createdById ?? this.createdById,
    updatedAt: updatedAt ?? this.updatedAt,
    updatedById: updatedById ?? this.updatedById,
    organizationId: organizationId ?? this.organizationId,
    groupTypeId: groupTypeId ?? this.groupTypeId,
    name: name ?? this.name,
    description: description ?? this.description,
    capacity: capacity ?? this.capacity,
    siteId: siteId ?? this.siteId,
    parentId: parentId ?? this.parentId,
    rowIndex: rowIndex ?? this.rowIndex,
    colIndex: colIndex ?? this.colIndex,
    urlPath: urlPath ?? this.urlPath,
    internalPath: internalPath ?? this.internalPath,
    slug: slug ?? this.slug,
    metadata: metadata ?? this.metadata,
  );

  @override
  bool validate() {
    // Check required fields explicitly
    if (groupTypeId.isEmpty || name.isEmpty) {
      return false;
    }

    // Check base record validation (required fields only)
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
      [groupTypeId, name, description, capacity, rowIndex, colIndex];
}
