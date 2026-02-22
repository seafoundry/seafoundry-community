// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/utils/json_casts.dart';

/// Target allocation for a specific site within a deliverable.
///
/// Contains a point-in-time snapshot of the site name to preserve
/// the historical record of what site was targeted at the time the
/// deliverable was created, even if the site is later renamed or deleted.
class SiteAllocation extends Equatable {
  final String siteId;

  /// Point-in-time snapshot of site name when allocation was created.
  /// Intentionally denormalized for historical audit purposes.
  final String siteNameSnapshot;
  final int targetCount;

  const SiteAllocation({
    required this.siteId,
    required this.siteNameSnapshot,
    required this.targetCount,
  });

  factory SiteAllocation.fromJson(Map<String, dynamic> json) {
    return SiteAllocation(
      siteId: json['siteId'] ?? '',
      // Support both old 'siteName' and new 'siteNameSnapshot' keys
      siteNameSnapshot: json['siteNameSnapshot'] ?? json['siteName'] ?? '',
      targetCount: safeInt(json['targetCount']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'siteId': siteId,
      'siteNameSnapshot': siteNameSnapshot,
      'targetCount': targetCount,
    };
  }

  SiteAllocation copyWith({
    String? siteId,
    String? siteNameSnapshot,
    int? targetCount,
  }) {
    return SiteAllocation(
      siteId: siteId ?? this.siteId,
      siteNameSnapshot: siteNameSnapshot ?? this.siteNameSnapshot,
      targetCount: targetCount ?? this.targetCount,
    );
  }

  @override
  List<Object?> get props => [siteId, siteNameSnapshot, targetCount];
}
