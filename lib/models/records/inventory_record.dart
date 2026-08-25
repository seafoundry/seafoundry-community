import 'package:meta/meta.dart';
import 'package:seafoundry_community/models/records/record.dart';

abstract class InventoryRecord extends Record {
  final String urlPath;
  final String internalPath;
  final String slug;

  const InventoryRecord({
    required super.id,
    required super.createdAt,
    required super.createdById,
    required super.updatedAt,
    required super.updatedById,
    required super.organizationId,
    required this.urlPath,
    required this.internalPath,
    required this.slug,
    super.metadata,
  });

  InventoryRecord.fromJson(super.json)
    : urlPath = json['urlPath'] ?? '',
      internalPath = json['internalPath'] ?? '',
      slug = json['slug'] ?? '',
      super.fromJson();

  InventoryRecord.partial({
    super.json,
    super.id,
    super.createdAt,
    super.createdById,
    super.updatedAt,
    super.updatedById,
    super.organizationId,
    String? internalPath,
    String? slug,
    String? urlPath,
    super.metadata,
  }) : urlPath = urlPath ?? json?['urlPath'] ?? Missing.string,
       internalPath = internalPath ?? json?['internalPath'] ?? Missing.string,
       slug = slug ?? json?['slug'] ?? Missing.string,
       super.partial();

  @override
  @mustCallSuper
  Map<String, dynamic> toJson() {
    return {'urlPath': urlPath, 'internalPath': internalPath, 'slug': slug, ...super.toJson()};
  }

  @override
  InventoryRecord copyWith({
    String? id,
    String? createdById,
    String? createdAt,
    String? updatedById,
    String? updatedAt,
    String? organizationId,
    String? urlPath,
    String? internalPath,
    String? slug,
    Map<String, dynamic>? metadata,
  });

  List<String> get urlSegments => urlPath.split('/');

  @override
  bool get stringify => true;

  @override
  List<Object?> get props => [...super.props, urlPath, internalPath, slug];
}
