// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/group.dart';
import 'package:seafoundry_app/models/site.dart';

class OrganismSelectionState extends Equatable {
  const OrganismSelectionState({
    this.allOrganisms = const [],
    this.filteredOrganisms = const [],
    this.selectedOrganisms = const [],
    this.searchQuery = '',
    this.isLoading = false,
    this.error,
    this.selectedSiteType,
    this.selectedSite,
    this.selectedGroup,
    this.selectedSpecies,
    this.sites = const [],
    this.groups = const [],
  });

  final List<OrganismRecord> allOrganisms;
  final List<OrganismRecord> filteredOrganisms;
  final List<OrganismRecord> selectedOrganisms;
  final String searchQuery;
  final bool isLoading;
  final String? error;
  final String? selectedSiteType;
  final String? selectedSite;
  final String? selectedGroup;
  final String? selectedSpecies;
  final List<Site> sites;
  final List<Group> groups;

  OrganismSelectionState copyWith({
    List<OrganismRecord>? allOrganisms,
    List<OrganismRecord>? filteredOrganisms,
    List<OrganismRecord>? selectedOrganisms,
    String? searchQuery,
    bool? isLoading,
    String? error,
    bool clearError = false,
    String? selectedSiteType,
    String? selectedSite,
    String? selectedGroup,
    String? selectedSpecies,
    List<Site>? sites,
    List<Group>? groups,
  }) {
    return OrganismSelectionState(
      allOrganisms: allOrganisms ?? this.allOrganisms,
      filteredOrganisms: filteredOrganisms ?? this.filteredOrganisms,
      selectedOrganisms: selectedOrganisms ?? this.selectedOrganisms,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      selectedSiteType: selectedSiteType ?? this.selectedSiteType,
      selectedSite: selectedSite ?? this.selectedSite,
      selectedGroup: selectedGroup ?? this.selectedGroup,
      selectedSpecies: selectedSpecies ?? this.selectedSpecies,
      sites: sites ?? this.sites,
      groups: groups ?? this.groups,
    );
  }

  @override
  List<Object?> get props => [
    allOrganisms,
    filteredOrganisms,
    selectedOrganisms,
    searchQuery,
    isLoading,
    error,
    selectedSiteType,
    selectedSite,
    selectedGroup,
    selectedSpecies,
    sites,
    groups,
  ];
}
