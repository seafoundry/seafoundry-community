// @tier: community
import 'package:seafoundry_app/cubits/summary_statistics/summary_filter_matcher.dart';
import 'package:seafoundry_app/cubits/summary_statistics/summary_statistics_state.dart';
import 'package:seafoundry_app/models/group.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/types/health_status.dart';
import 'package:seafoundry_app/services/genet_id_resolver.dart';

typedef OrganismPredicate = bool Function(OrganismRecord record);

enum SummaryCardFilter {
  totalOrganisms,
  byGenotype,
}

extension SummaryCardFilterX on SummaryCardFilter {
  OrganismPredicate predicate({
    required bool Function(String siteId) isOutplantingSite,
    SummaryStatisticsState? filterState,
    HealthStatus? status,
    bool excludeOutplantingSites = true,
    Map<String, Group>? groupLookup,
  }) {
    return (record) {
      if (excludeOutplantingSites && isOutplantingSite(record.siteId ?? '')) {
        return false;
      }
      if (!_matchesHealthFilter(record, filterState)) {
        return false;
      }
      if (!SummaryFilterMatcher.matches(
        record,
        filterState,
        groupLookup: groupLookup,
      )) {
        return false;
      }

      switch (this) {
        case SummaryCardFilter.totalOrganisms:
          return true;
        case SummaryCardFilter.byGenotype:
          return GenetIdResolver.resolve(record) != null;
      }
    };
  }

  bool _matchesHealthFilter(
    OrganismRecord record,
    SummaryStatisticsState? filterState,
  ) {
    if (filterState == null) return true;
    final healthStatus = record.healthStatus;
    if (filterState.onlyIssues) {
      return healthStatus != HealthStatus.healthy;
    }
    if (filterState.selectedHealth == null) {
      return true;
    }
    return healthStatus == filterState.selectedHealth;
  }
}
