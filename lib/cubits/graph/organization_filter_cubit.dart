// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/models.dart';

/// Filter categories for site display.
///
/// **Design Note**: These categories filter by site function/type:
/// - **landBasedNurseries**: Ex-situ sites where organisms are grown in facilities
/// - **inWaterNurseries**: In-situ nursery sites where organisms are grown in the water
/// - **outplanting**: Sites where organisms are permanently placed for restoration
/// - **baseline**: Non-intervention monitoring sites for scientific comparison
/// - **reference**: Healthy reef reference sites for scientific comparison
///
/// When multiple filters are selected, sites matching ANY filter are shown (OR logic).
enum SiteFilterCategory {
  landBasedNurseries,
  inWaterNurseries,
  outplanting,
  baseline,
  reference,
}

extension SiteFilterCategoryX on SiteFilterCategory {
  String get label {
    switch (this) {
      case SiteFilterCategory.landBasedNurseries:
        return 'Land-Based Nurseries';
      case SiteFilterCategory.inWaterNurseries:
        return 'In-Water Nurseries';
      case SiteFilterCategory.outplanting:
        return 'Outplanting';
      case SiteFilterCategory.baseline:
        return 'Baseline';
      case SiteFilterCategory.reference:
        return 'Reference';
    }
  }

  IconData get icon {
    switch (this) {
      case SiteFilterCategory.landBasedNurseries:
        return Icons.business;
      case SiteFilterCategory.inWaterNurseries:
        return Icons.waves;
      case SiteFilterCategory.outplanting:
        return Icons.eco;
      case SiteFilterCategory.baseline:
        return Icons.analytics_outlined;
      case SiteFilterCategory.reference:
        return Icons.verified_outlined;
    }
  }

  bool matches(SiteType siteType) {
    switch (this) {
      case SiteFilterCategory.landBasedNurseries:
        // Ex-situ sites for growing organisms in facilities
        return siteType.id == SiteType.nurseryExSitu.id ||
            siteType.id == SiteType.geneBank.id ||
            siteType.id == SiteType.growOutPond.id ||
            siteType.id == SiteType.racewaySite.id;
      case SiteFilterCategory.inWaterNurseries:
        // In-situ nursery sites only (not outplanting/monitoring)
        return siteType.id == SiteType.nurseryInSitu.id ||
            siteType.id == SiteType.kelpFarm.id ||
            siteType.id == SiteType.reefAquaculture.id;
      case SiteFilterCategory.outplanting:
        // Sites for permanent placement and restoration
        return siteType.id == SiteType.outplanting.id ||
            siteType.id == SiteType.seagrassPlot.id ||
            siteType.id == SiteType.mangroveOutplant.id ||
            siteType.id == SiteType.releaseSite.id ||
            siteType.id == SiteType.fieldCollection.id;
      case SiteFilterCategory.baseline:
        return siteType.id == SiteType.baselineSite.id;
      case SiteFilterCategory.reference:
        return siteType.id == SiteType.referenceSite.id;
    }
  }
}

class OrganizationFilterState extends Equatable {
  const OrganizationFilterState({
    this.selectedFilters = const {},
  });

  final Set<SiteFilterCategory> selectedFilters;

  OrganizationFilterState copyWith({
    Set<SiteFilterCategory>? selectedFilters,
  }) {
    return OrganizationFilterState(
      selectedFilters: selectedFilters ?? this.selectedFilters,
    );
  }

  /// Returns true when no filters are active (all sites should be shown).
  ///
  /// When this is true, the UI shows all sites without filtering.
  /// When false, only sites matching at least one selected filter are shown.
  bool get hasNoActiveFilters => selectedFilters.isEmpty;

  bool contains(SiteFilterCategory filter) => selectedFilters.contains(filter);

  @override
  List<Object?> get props => [selectedFilters];
}

class OrganizationFilterCubit extends Cubit<OrganizationFilterState> {
  OrganizationFilterCubit() : super(const OrganizationFilterState());

  void toggleFilter(SiteFilterCategory filter) {
    final current = Set<SiteFilterCategory>.from(state.selectedFilters);
    if (current.contains(filter)) {
      current.remove(filter);
    } else {
      current.add(filter);
    }
    emit(state.copyWith(selectedFilters: current));
  }

  void clearFilters() {
    emit(state.copyWith(selectedFilters: {}));
  }
}
