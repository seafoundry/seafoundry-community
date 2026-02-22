// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

/// Requirements a mission has for an assigned vessel (capacity, range, capabilities)
class VesselRequirements extends Equatable {
  final int? minimumCrewCapacity;
  final List<String> requiredCapabilities;
  final double? minimumRangeNauticalMiles;

  const VesselRequirements({
    this.minimumCrewCapacity,
    List<String>? requiredCapabilities,
    this.minimumRangeNauticalMiles,
  }) : requiredCapabilities = requiredCapabilities ?? const [];

  factory VesselRequirements.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const VesselRequirements();
    return VesselRequirements(
      minimumCrewCapacity: safeInt(json['minimumCrewCapacity']),
      requiredCapabilities: json['requiredCapabilities'] != null
          ? List<String>.from(json['requiredCapabilities'])
          : const [],
      minimumRangeNauticalMiles:
          safeDouble(json['minimumRangeNauticalMiles']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (minimumCrewCapacity != null)
        'minimumCrewCapacity': minimumCrewCapacity,
      if (requiredCapabilities.isNotEmpty)
        'requiredCapabilities': requiredCapabilities,
      if (minimumRangeNauticalMiles != null)
        'minimumRangeNauticalMiles': minimumRangeNauticalMiles,
    };
  }

  VesselRequirements copyWith({
    int? minimumCrewCapacity,
    List<String>? requiredCapabilities,
    double? minimumRangeNauticalMiles,
  }) {
    return VesselRequirements(
      minimumCrewCapacity: minimumCrewCapacity ?? this.minimumCrewCapacity,
      requiredCapabilities:
          requiredCapabilities ?? List.of(this.requiredCapabilities),
      minimumRangeNauticalMiles:
          minimumRangeNauticalMiles ?? this.minimumRangeNauticalMiles,
    );
  }

  @override
  List<Object?> get props => [
        minimumCrewCapacity,
        requiredCapabilities,
        minimumRangeNauticalMiles,
      ];
}
