// @tier: community
import 'package:seafoundry_app/models/records/records.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

/// Status of a vessel's availability
enum VesselStatus {
  available('available', 'Available'),
  inMaintenance('in_maintenance', 'In Maintenance'),
  deployed('deployed', 'Deployed'),
  retired('retired', 'Retired');

  final String id;
  final String displayName;

  const VesselStatus(this.id, this.displayName);

  static VesselStatus fromId(String? id) {
    if (id == null) return available;
    return values.firstWhere(
      (status) => status.id == id,
      orElse: () => available,
    );
  }

  bool get isAvailable => this == VesselStatus.available;
  bool get isInMaintenance => this == VesselStatus.inMaintenance;
  bool get isDeployed => this == VesselStatus.deployed;
  bool get isRetired => this == VesselStatus.retired;
  bool get isActive => isAvailable || isDeployed;
}

/// Represents an operational vessel/boat used for field missions
///
/// Extends Record (NOT InventoryRecord) as vessels are static resources
/// with availability status, not dynamic inventory undergoing transformations.
/// Vessel availability is computed from Mission queries, not stored state.
class Vessel extends Record {
  static const Object _unset = Object();

  final String name;
  final String registrationNumber;
  final int crewCapacity;
  final double maxSpeedKnots;
  final String? homePortSiteId;
  final List<String> capabilities;
  final double fuelCapacityGallons;
  final double rangeNauticalMiles;
  final VesselStatus status;
  final Map<String, dynamic>? specifications;

  const Vessel({
    required super.id,
    required super.createdById,
    required super.createdAt,
    required super.updatedAt,
    required super.updatedById,
    required super.organizationId,
    required this.name,
    required this.registrationNumber,
    required this.crewCapacity,
    required this.maxSpeedKnots,
    this.homePortSiteId,
    List<String>? capabilities,
    required this.fuelCapacityGallons,
    required this.rangeNauticalMiles,
    VesselStatus? status,
    this.specifications,
    super.metadata,
  }) : capabilities = capabilities ?? const [],
       status = status ?? VesselStatus.available;

  Vessel.fromJson(super.json)
    : name = json['name'] ?? 'Untitled Vessel',
      registrationNumber = json['registrationNumber'] ?? '',
      crewCapacity = json['crewCapacity'] ?? 0,
      maxSpeedKnots = safeDouble(json['maxSpeedKnots']) ?? 0.0,
      homePortSiteId = json['homePortSiteId'],
      capabilities = json['capabilities'] != null
          ? List<String>.from(json['capabilities'])
          : const [],
      fuelCapacityGallons =
          safeDouble(json['fuelCapacityGallons']) ?? 0.0,
      rangeNauticalMiles =
          safeDouble(json['rangeNauticalMiles']) ?? 0.0,
      status = VesselStatus.fromId(json['statusId']),
      specifications = safeMapCast(json['specifications']),
      super.fromJson();

  Vessel.partial({
    super.json,
    super.id,
    super.createdById,
    super.createdAt,
    super.updatedAt,
    super.updatedById,
    super.organizationId,
    super.metadata,
    String? name,
    String? registrationNumber,
    int? crewCapacity,
    double? maxSpeedKnots,
    String? homePortSiteId,
    List<String>? capabilities,
    double? fuelCapacityGallons,
    double? rangeNauticalMiles,
    VesselStatus? status,
    Map<String, dynamic>? specifications,
  }) : name = name ?? json?['name'] ?? 'Untitled Vessel',
       registrationNumber =
           registrationNumber ?? json?['registrationNumber'] ?? '',
       crewCapacity = crewCapacity ?? json?['crewCapacity'] ?? 0,
       maxSpeedKnots =
           maxSpeedKnots ?? safeDouble(json?['maxSpeedKnots']) ?? 0.0,
       homePortSiteId = homePortSiteId ?? json?['homePortSiteId'],
       capabilities =
           capabilities ??
           (json?['capabilities'] != null
               ? List<String>.from(json!['capabilities'])
               : const []),
       fuelCapacityGallons =
           fuelCapacityGallons ??
           safeDouble(json?['fuelCapacityGallons']) ??
           0.0,
       rangeNauticalMiles =
           rangeNauticalMiles ??
           safeDouble(json?['rangeNauticalMiles']) ??
           0.0,
       status = status ?? VesselStatus.fromId(json?['statusId']),
       specifications =
           specifications ?? safeMapCast(json?['specifications']),
       super.partial();

  @override
  ModelType get modelType => ModelType.vessel;

  @override
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'registrationNumber': registrationNumber,
      'crewCapacity': crewCapacity,
      'maxSpeedKnots': maxSpeedKnots,
      if (homePortSiteId != null) 'homePortSiteId': homePortSiteId,
      'capabilities': capabilities,
      'fuelCapacityGallons': fuelCapacityGallons,
      'rangeNauticalMiles': rangeNauticalMiles,
      'statusId': status.id,
      if (specifications != null) 'specifications': specifications,
      ...super.toJson(),
    };
  }

  @override
  Vessel copyWith({
    Object? id = _unset,
    Object? createdById = _unset,
    Object? createdAt = _unset,
    Object? updatedAt = _unset,
    Object? updatedById = _unset,
    Object? organizationId = _unset,
    Object? name = _unset,
    Object? registrationNumber = _unset,
    Object? crewCapacity = _unset,
    Object? maxSpeedKnots = _unset,
    Object? homePortSiteId = _unset,
    Object? capabilities = _unset,
    Object? fuelCapacityGallons = _unset,
    Object? rangeNauticalMiles = _unset,
    Object? status = _unset,
    Object? specifications = _unset,
    Map<String, dynamic>? metadata,
  }) {
    return Vessel(
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
      name: identical(name, _unset) ? this.name : name as String,
      registrationNumber: identical(registrationNumber, _unset)
          ? this.registrationNumber
          : registrationNumber as String,
      crewCapacity: identical(crewCapacity, _unset)
          ? this.crewCapacity
          : crewCapacity as int,
      maxSpeedKnots: identical(maxSpeedKnots, _unset)
          ? this.maxSpeedKnots
          : maxSpeedKnots as double,
      homePortSiteId: identical(homePortSiteId, _unset)
          ? this.homePortSiteId
          : homePortSiteId as String?,
      capabilities: identical(capabilities, _unset)
          ? this.capabilities
          : capabilities as List<String>,
      fuelCapacityGallons: identical(fuelCapacityGallons, _unset)
          ? this.fuelCapacityGallons
          : fuelCapacityGallons as double,
      rangeNauticalMiles: identical(rangeNauticalMiles, _unset)
          ? this.rangeNauticalMiles
          : rangeNauticalMiles as double,
      status: identical(status, _unset) ? this.status : status as VesselStatus,
      specifications: identical(specifications, _unset)
          ? this.specifications
          : specifications as Map<String, dynamic>?,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool validate() {
    return super.validate() &&
        name.isNotEmpty &&
        registrationNumber.isNotEmpty &&
        crewCapacity > 0 &&
        maxSpeedKnots >= 0 &&
        fuelCapacityGallons >= 0 &&
        rangeNauticalMiles >= 0;
  }

  @override
  List<Object?> get props =>
      super.props +
      [
        name,
        registrationNumber,
        crewCapacity,
        maxSpeedKnots,
        homePortSiteId,
        capabilities,
        fuelCapacityGallons,
        rangeNauticalMiles,
        status,
        specifications,
      ];

  // Helper methods
  bool get hasHomePort => homePortSiteId != null;
  bool get hasCapabilities => capabilities.isNotEmpty;
  bool get hasSpecifications =>
      specifications != null && specifications!.isNotEmpty;

  /// Update vessel status
  Vessel updateStatus(VesselStatus newStatus) {
    return copyWith(status: newStatus);
  }

  /// Mark vessel as available
  Vessel markAvailable() {
    return copyWith(status: VesselStatus.available);
  }

  /// Mark vessel as in maintenance
  Vessel markInMaintenance() {
    return copyWith(status: VesselStatus.inMaintenance);
  }

  /// Mark vessel as deployed
  Vessel markDeployed() {
    return copyWith(status: VesselStatus.deployed);
  }

  /// Mark vessel as retired
  Vessel markRetired() {
    return copyWith(status: VesselStatus.retired);
  }

  /// Add a capability to the vessel
  Vessel addCapability(String capability) {
    if (capabilities.contains(capability)) return this;
    final updatedCapabilities = [...capabilities, capability];
    return copyWith(capabilities: updatedCapabilities);
  }

  /// Remove a capability from the vessel
  Vessel removeCapability(String capability) {
    final updatedCapabilities = capabilities
        .where((c) => c != capability)
        .toList();
    return copyWith(capabilities: updatedCapabilities);
  }
}
