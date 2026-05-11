import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/navigation_view_mode/navigation_view_mode_state.dart';

/// Manages the toggle between community and organization views in navigation.
///
/// Controls which view mode is active and enforces access control logic:
/// - [setMode]: Switches between community/organization views (respects access)
/// - [setOrganizationAccess]: Updates organization access and auto-switches to
///   community mode if access is revoked while in organization mode
///
/// Prevents switching to organization view when [canAccessOrganization] is false.
class NavigationViewModeCubit extends Cubit<NavigationViewModeState> {
  NavigationViewModeCubit({bool hasOrganization = false})
      : super(NavigationViewModeState.initial(hasOrganization: hasOrganization));

  void setMode(NavigationViewMode mode) {
    if (!state.canAccessOrganization && mode == NavigationViewMode.organization) {
      // Can't switch to org view without org access
      return;
    }
    emit(state.copyWith(mode: mode));
  }

  void setOrganizationAccess(bool hasAccess) {
    emit(
      state.copyWith(
        canAccessOrganization: hasAccess,
        // If losing org access and in org mode, switch to community
        mode: (!hasAccess && state.mode == NavigationViewMode.organization)
            ? NavigationViewMode.community
            : state.mode,
      ),
    );
  }
}
