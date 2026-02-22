// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

/// Represents an image attachment associated with a monitoring event or observation.
/// 
/// Images can be associated with:
/// - Specific organisms (via `organismIds` / legacy `coralIds`)
/// - Specific groups (via `groupIds`)
/// - Specific tags (via `tagIds`)
/// - The entire site/event (if all target lists are empty)
/// 
/// Orthomosaics (TIFF files) are typically large aerial/satellite images of entire sites,
/// while regular images are time-series photos of specific organisms or groups.
class ImageAttachment extends Equatable {
  const ImageAttachment({
    required this.imageUrl,
    required this.fileName,
    this.fileSizeBytes,
    this.contentType,
    this.uploadedAtIso,
    List<String>? coralIds,
    List<String>? organismIds,
    this.groupIds = const [],
    this.tagIds = const [],
    this.isOrthomosaic = false,
    this.description,
  }) : coralIds = organismIds ?? coralIds ?? const [];

  /// Download URL for the image in Firebase Storage
  final String imageUrl;

  /// Original filename of the uploaded image
  final String fileName;

  /// File size in bytes
  final int? fileSizeBytes;

  /// MIME content type (e.g., 'image/jpeg', 'image/tiff')
  final String? contentType;

  /// ISO 8601 timestamp when the image was uploaded
  final String? uploadedAtIso;

  /// IDs of organisms this image is associated with (empty = site/event level).
  final List<String> coralIds;
  List<String> get organismIds => coralIds;

  /// IDs of groups this image is associated with (empty = site/event level)
  final List<String> groupIds;

  /// IDs of tags this image is associated with
  final List<String> tagIds;

  /// Whether this is an orthomosaic (TIFF) file
  final bool isOrthomosaic;

  /// Optional description or notes about the image
  final String? description;

  /// Creates an ImageAttachment from Firestore JSON data.
  /// 
  /// Handles missing or null fields gracefully, defaulting to empty lists
  /// for target associations and false for orthomosaic flag.
  factory ImageAttachment.fromJson(Map<String, dynamic> json) {
    return ImageAttachment(
      imageUrl: json['imageUrl'] as String? ?? '',
      fileName: json['fileName'] as String? ?? '',
      fileSizeBytes: safeInt(json['fileSizeBytes']),
      contentType: json['contentType'] as String?,
      uploadedAtIso: json['uploadedAt'] as String?,
      coralIds: _parseOrganismIds(json),
      groupIds: json['groupIds'] != null
          ? List<String>.from(json['groupIds'] as List)
          : const [],
      tagIds: json['tagIds'] != null
          ? List<String>.from(json['tagIds'] as List)
          : const [],
      isOrthomosaic: json['isOrthomosaic'] as bool? ?? false,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'imageUrl': imageUrl,
      'fileName': fileName,
      if (fileSizeBytes != null) 'fileSizeBytes': fileSizeBytes,
      if (contentType != null) 'contentType': contentType,
      if (uploadedAtIso != null) 'uploadedAt': uploadedAtIso,
      if (coralIds.isNotEmpty) 'organismIds': coralIds,
      if (groupIds.isNotEmpty) 'groupIds': groupIds,
      if (tagIds.isNotEmpty) 'tagIds': tagIds,
      if (isOrthomosaic) 'isOrthomosaic': isOrthomosaic,
      if (description != null) 'description': description,
    };
  }

  ImageAttachment copyWith({
    String? imageUrl,
    String? fileName,
    int? fileSizeBytes,
    String? contentType,
    String? uploadedAtIso,
    List<String>? coralIds,
    List<String>? organismIds,
    List<String>? groupIds,
    List<String>? tagIds,
    bool? isOrthomosaic,
    String? description,
  }) {
    return ImageAttachment(
      imageUrl: imageUrl ?? this.imageUrl,
      fileName: fileName ?? this.fileName,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      contentType: contentType ?? this.contentType,
      uploadedAtIso: uploadedAtIso ?? this.uploadedAtIso,
      coralIds: organismIds ?? coralIds ?? this.coralIds,
      groupIds: groupIds ?? this.groupIds,
      tagIds: tagIds ?? this.tagIds,
      isOrthomosaic: isOrthomosaic ?? this.isOrthomosaic,
      description: description ?? this.description,
    );
  }

  /// Returns true if this image is associated with specific organisms/groups.
  bool get hasSpecificTargets =>
      coralIds.isNotEmpty || groupIds.isNotEmpty || tagIds.isNotEmpty;

  @override
  List<Object?> get props => [
        imageUrl,
        fileName,
        fileSizeBytes,
        contentType,
        uploadedAtIso,
        coralIds,
        groupIds,
        tagIds,
      isOrthomosaic,
      description,
      ];
}

List<String> _parseOrganismIds(Map<String, dynamic> json) {
  final raw = json['organismIds'] ?? json['coralIds'];
  if (raw is Iterable) {
    return List<String>.from(raw);
  }
  return const [];
}
