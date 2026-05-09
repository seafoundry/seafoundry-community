import 'package:seafoundry_app/models/records/record.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/types/record_type.dart';

class CustomRecordType extends Record implements RecordType {
  const CustomRecordType({
    required super.id,
    required this.name,
    required super.organizationId,
    required super.createdAt,
    required super.createdById,
    required super.updatedAt,
    required super.updatedById,
  });

  CustomRecordType.fromJson(super.json) : name = json['name'], super.fromJson();

  CustomRecordType.partial({super.json, String? name})
    : name = name ?? json?['name'] ?? Missing.string,
      super.partial();

  @override
  ModelType get modelType => ModelType.recordType;

  @override
  final String name;

  @override
  List<Object?> get props => [name];

  @override
  Map<String, dynamic> toJson() => {'name': name, ...super.toJson()};

  @override
  CustomRecordType copyWith({
    String? name,
    String? id,
    String? createdAt,
    String? createdById,
    String? updatedAt,
    String? updatedById,
    String? organizationId,
  }) {
    return CustomRecordType(
      id: id ?? this.id,
      name: name ?? this.name,
      organizationId: organizationId ?? this.organizationId,
      createdAt: createdAt ?? this.createdAt,
      createdById: createdById ?? this.createdById,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedById: updatedById ?? this.updatedById,
    );
  }
}
