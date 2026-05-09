import 'package:seafoundry_app/models/records/record.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/utils/date_time_converter.dart';

/// Type of permit for regulatory compliance
enum PermitType {
  coral('coral', 'Coral'),
  research('research', 'Research'),
  collection('collection', 'Collection'),
  outplanting('outplanting', 'Outplanting'),
  other('other', 'Other');

  final String id;
  final String displayName;

  const PermitType(this.id, this.displayName);

  static PermitType fromId(String? id) {
    if (id == null) return other;
    return values.firstWhere((type) => type.id == id, orElse: () => other);
  }
}

/// A regulatory permit that authorizes field operations at specific sites
class Permit extends Record {
  static const Object _unset = Object();

  final String permitNumber;
  final String name;
  final String issuingAuthority;
  final DateTime validFrom;
  final DateTime validTo;
  final PermitType type;
  final List<String> siteIds;
  final String? contactName;
  final String? contactEmail;

  // Activity attachment - which activities this permit covers
  final List<String> authorizedActivities;

  // Regulatory details
  final String? regulatoryAgency;
  final String? permitConditions;
  final List<String> attachmentUrls;

  const Permit({
    required super.id,
    required super.createdById,
    required super.createdAt,
    required super.updatedAt,
    required super.updatedById,
    required super.organizationId,
    required this.permitNumber,
    required this.name,
    required this.issuingAuthority,
    required this.validFrom,
    required this.validTo,
    PermitType? type,
    List<String>? siteIds,
    this.contactName,
    this.contactEmail,
    List<String>? authorizedActivities,
    this.regulatoryAgency,
    this.permitConditions,
    List<String>? attachmentUrls,
    super.metadata,
  }) : type = type ?? PermitType.other,
       siteIds = siteIds ?? const [],
       authorizedActivities = authorizedActivities ?? const [],
       attachmentUrls = attachmentUrls ?? const [];

  Permit.fromJson(super.json)
    : permitNumber = json['permitNumber'] ?? '',
      name = json['name'] ?? 'Untitled Permit',
      issuingAuthority = json['issuingAuthority'] ?? '',
      validFrom = DateTimeConverter.parseWithFallback(
          json['validFrom'],
          fallback: DateTime.now(),
          fieldName: 'validFrom',
          modelType: 'Permit',
          recordId: json['id'],
        ),
      validTo = DateTimeConverter.parseWithFallback(
          json['validTo'],
          fallback: DateTime.now().add(const Duration(days: 365)),
          fieldName: 'validTo',
          modelType: 'Permit',
          recordId: json['id'],
        ),
      type = PermitType.fromId(json['typeId']),
      siteIds = json['siteIds'] != null
          ? List<String>.from(json['siteIds'])
          : const [],
      contactName = json['contactName'],
      contactEmail = json['contactEmail'],
      authorizedActivities = json['authorizedActivities'] != null
          ? List<String>.from(json['authorizedActivities'])
          : const [],
      regulatoryAgency = json['regulatoryAgency'],
      permitConditions = json['permitConditions'],
      attachmentUrls = json['attachmentUrls'] != null
          ? List<String>.from(json['attachmentUrls'])
          : const [],
      super.fromJson();

  Permit.partial({
    super.json,
    super.id,
    super.createdById,
    super.createdAt,
    super.updatedAt,
    super.updatedById,
    super.organizationId,
    super.metadata,
    String? permitNumber,
    String? name,
    String? issuingAuthority,
    DateTime? validFrom,
    DateTime? validTo,
    PermitType? type,
    List<String>? siteIds,
    String? contactName,
    String? contactEmail,
    List<String>? authorizedActivities,
    String? regulatoryAgency,
    String? permitConditions,
    List<String>? attachmentUrls,
  }) : permitNumber = permitNumber ?? json?['permitNumber'] ?? '',
       name = name ?? json?['name'] ?? 'Untitled Permit',
       issuingAuthority = issuingAuthority ?? json?['issuingAuthority'] ?? '',
       validFrom =
           validFrom ??
           DateTimeConverter.parseWithFallback(
             json?['validFrom'],
             fallback: DateTime.now(),
             fieldName: 'validFrom',
             modelType: 'Permit',
             recordId: json?['id'],
           ),
       validTo =
           validTo ??
           DateTimeConverter.parseWithFallback(
             json?['validTo'],
             fallback: DateTime.now().add(const Duration(days: 365)),
             fieldName: 'validTo',
             modelType: 'Permit',
             recordId: json?['id'],
           ),
       type = type ?? PermitType.fromId(json?['typeId']),
       siteIds =
           siteIds ??
           (json?['siteIds'] != null
               ? List<String>.from(json!['siteIds'])
               : const []),
       contactName = contactName ?? json?['contactName'],
       contactEmail = contactEmail ?? json?['contactEmail'],
       authorizedActivities =
           authorizedActivities ??
           (json?['authorizedActivities'] != null
               ? List<String>.from(json!['authorizedActivities'])
               : const []),
       regulatoryAgency = regulatoryAgency ?? json?['regulatoryAgency'],
       permitConditions = permitConditions ?? json?['permitConditions'],
       attachmentUrls =
           attachmentUrls ??
           (json?['attachmentUrls'] != null
               ? List<String>.from(json!['attachmentUrls'])
               : const []),
       super.partial();

  @override
  ModelType get modelType => ModelType.permit;

  @override
  Map<String, dynamic> toJson() {
    return {
      'permitNumber': permitNumber,
      'name': name,
      'issuingAuthority': issuingAuthority,
      'validFrom': validFrom.toIso8601String(),
      'validTo': validTo.toIso8601String(),
      'typeId': type.id,
      'siteIds': siteIds,
      if (contactName != null) 'contactName': contactName,
      if (contactEmail != null) 'contactEmail': contactEmail,
      if (authorizedActivities.isNotEmpty)
        'authorizedActivities': authorizedActivities,
      if (regulatoryAgency != null) 'regulatoryAgency': regulatoryAgency,
      if (permitConditions != null) 'permitConditions': permitConditions,
      if (attachmentUrls.isNotEmpty) 'attachmentUrls': attachmentUrls,
      ...super.toJson(),
    };
  }

  @override
  Permit copyWith({
    Object? id = _unset,
    Object? createdById = _unset,
    Object? createdAt = _unset,
    Object? updatedAt = _unset,
    Object? updatedById = _unset,
    Object? organizationId = _unset,
    Object? permitNumber = _unset,
    Object? name = _unset,
    Object? issuingAuthority = _unset,
    Object? validFrom = _unset,
    Object? validTo = _unset,
    Object? type = _unset,
    Object? siteIds = _unset,
    Object? contactName = _unset,
    Object? contactEmail = _unset,
    Object? authorizedActivities = _unset,
    Object? regulatoryAgency = _unset,
    Object? permitConditions = _unset,
    Object? attachmentUrls = _unset,
    Map<String, dynamic>? metadata,
  }) {
    return Permit(
      id: identical(id, _unset) ? this.id : id as String,
      createdById: identical(createdById, _unset)
          ? this.createdById
          : createdById as String,
      createdAt: identical(createdAt, _unset)
          ? this.createdAt
          : createdAt as String,
      updatedAt: identical(updatedAt, _unset)
          ? this.updatedAt
          : updatedAt as String,
      updatedById: identical(updatedById, _unset)
          ? this.updatedById
          : updatedById as String,
      organizationId: identical(organizationId, _unset)
          ? this.organizationId
          : organizationId as String,
      permitNumber: identical(permitNumber, _unset)
          ? this.permitNumber
          : permitNumber as String,
      name: identical(name, _unset) ? this.name : name as String,
      issuingAuthority: identical(issuingAuthority, _unset)
          ? this.issuingAuthority
          : issuingAuthority as String,
      validFrom: identical(validFrom, _unset)
          ? this.validFrom
          : validFrom as DateTime,
      validTo: identical(validTo, _unset) ? this.validTo : validTo as DateTime,
      type: identical(type, _unset) ? this.type : type as PermitType,
      siteIds: identical(siteIds, _unset)
          ? this.siteIds
          : siteIds as List<String>,
      contactName: identical(contactName, _unset)
          ? this.contactName
          : contactName as String?,
      contactEmail: identical(contactEmail, _unset)
          ? this.contactEmail
          : contactEmail as String?,
      authorizedActivities: identical(authorizedActivities, _unset)
          ? this.authorizedActivities
          : authorizedActivities as List<String>,
      regulatoryAgency: identical(regulatoryAgency, _unset)
          ? this.regulatoryAgency
          : regulatoryAgency as String?,
      permitConditions: identical(permitConditions, _unset)
          ? this.permitConditions
          : permitConditions as String?,
      attachmentUrls: identical(attachmentUrls, _unset)
          ? this.attachmentUrls
          : attachmentUrls as List<String>,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool validate() {
    return super.validate() &&
        permitNumber.isNotEmpty &&
        name.isNotEmpty &&
        issuingAuthority.isNotEmpty;
  }

  @override
  List<Object?> get props =>
      super.props +
      [
        permitNumber,
        name,
        issuingAuthority,
        validFrom,
        validTo,
        type,
        siteIds,
        contactName,
        contactEmail,
        authorizedActivities,
        regulatoryAgency,
        permitConditions,
        attachmentUrls,
      ];

  // Computed properties
  bool get isActive {
    final now = DateTime.now();
    // Use inclusive boundaries - permit is active on both start and end dates
    return !now.isBefore(validFrom) && !now.isAfter(validTo);
  }

  bool get isExpired => DateTime.now().isAfter(validTo);

  bool get isUpcoming => DateTime.now().isBefore(validFrom);

  int get daysUntilExpiration {
    final now = DateTime.now();
    if (isExpired) return 0;
    return validTo.difference(now).inDays;
  }

  /// Default threshold for administrative "expiring soon" warnings
  static const int defaultExpiringThresholdDays = 90;

  bool get isExpiringSoon =>
      isActive && daysUntilExpiration <= defaultExpiringThresholdDays;

  /// Check if permit is expiring within the given duration.
  /// Only applies to active permits (excludes upcoming permits that haven't started).
  /// Useful for UI components that need different warning thresholds.
  bool isExpiringWithin(Duration duration) =>
      isActive && validTo.isBefore(DateTime.now().add(duration));

  bool get hasSites => siteIds.isNotEmpty;

  bool get hasActivities => authorizedActivities.isNotEmpty;

  /// Check if a specific activity is authorized by this permit
  bool isActivityAuthorized(String activity) =>
      authorizedActivities.contains(activity);

  /// Add a site to this permit's coverage
  Permit addSite(String siteId) {
    if (siteIds.contains(siteId)) return this;
    return copyWith(siteIds: [...siteIds, siteId]);
  }

  /// Remove a site from this permit's coverage
  Permit removeSite(String siteId) {
    final updatedSiteIds = siteIds.where((id) => id != siteId).toList();
    return copyWith(siteIds: updatedSiteIds);
  }

  /// Add an authorized activity to this permit
  Permit addActivity(String activity) {
    if (authorizedActivities.contains(activity)) return this;
    return copyWith(authorizedActivities: [...authorizedActivities, activity]);
  }

  /// Remove an authorized activity from this permit
  Permit removeActivity(String activity) {
    final updated =
        authorizedActivities.where((a) => a != activity).toList();
    return copyWith(authorizedActivities: updated);
  }

  /// Extend the permit's validity period
  Permit extendValidity(DateTime newValidTo) {
    return copyWith(validTo: newValidTo);
  }
}
