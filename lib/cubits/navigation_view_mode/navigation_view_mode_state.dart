import 'package:equatable/equatable.dart';

enum NavigationViewMode { community, organization }

/// State for navigation view mode selection.
///
/// Tracks which view mode is active and whether organization access is available:
/// - [NavigationViewMode.community]: Community feed view (always accessible)
/// - [NavigationViewMode.organization]: Organization-specific view (requires access)
///
/// The [canAccessOrganization] guard prevents switching to organization mode
/// when the user lacks organization membership. Initial mode defaults to
/// organization if access is available, otherwise community.
class NavigationViewModeState extends Equatable {
  final NavigationViewMode mode;
  final bool canAccessOrganization;

  const NavigationViewModeState({
    required this.mode,
    required this.canAccessOrganization,
  });

  factory NavigationViewModeState.initial({bool hasOrganization = false}) {
    return NavigationViewModeState(
      mode: hasOrganization
          ? NavigationViewMode.organization
          : NavigationViewMode.community,
      canAccessOrganization: hasOrganization,
    );
  }

  NavigationViewModeState copyWith({
    NavigationViewMode? mode,
    bool? canAccessOrganization,
  }) {
    return NavigationViewModeState(
      mode: mode ?? this.mode,
      canAccessOrganization: canAccessOrganization ?? this.canAccessOrganization,
    );
  }

  @override
  List<Object?> get props => [mode, canAccessOrganization];
}
