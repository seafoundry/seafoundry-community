// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/cubits/base/safe_cubit.dart';
import 'package:seafoundry_app/models/public_read_models/brand_profile.dart';
import 'package:seafoundry_app/models/public_read_models/media_asset.dart';
import 'package:seafoundry_app/models/public_read_models/public_impact_point.dart';
import 'package:seafoundry_app/services/public/public_preview_access_service.dart';
import 'package:seafoundry_app/services/public_read_models_service.dart';

part 'public_org_state.dart';

/// Cubit for managing public organization screen state.
///
/// Handles preview access evaluation, view mode switching, and stream management.
class PublicOrgCubit extends SafeCubit<PublicOrgState> {
  PublicOrgCubit({
    required String orgId,
    required bool previewMode,
    PublicReadModelsService? readModelsService,
    PublicOrgViewMode initialView = PublicOrgViewMode.highlights,
  })  : _orgId = orgId,
        _previewMode = previewMode,
        _service = readModelsService ?? PublicReadModelsService(),
        _initialView = initialView,
        super(const PublicOrgInitial());

  final String _orgId;
  final bool _previewMode;
  final PublicReadModelsService _service;
  final PublicOrgViewMode _initialView;

  /// Initialize the cubit and evaluate preview access if needed.
  Future<void> initialize() async {
    if (state is PublicOrgLoading) return;

    emit(const PublicOrgLoading());

    try {
      // If not in preview mode, allow immediately
      if (!_previewMode) {
        _emitLoadedState(
          previewAccess: const PreviewAccessDecision.allowed(),
        );
        return;
      }

      // Evaluate preview access asynchronously
      final decision =
          await PublicPreviewAccessService().evaluate(_orgId);

      _emitLoadedState(previewAccess: decision);
    } catch (e) {
      emit(PublicOrgError(message: 'Failed to initialize: $e'));
    }
  }

  void _emitLoadedState({
    required PreviewAccessDecision previewAccess,
    PublicOrgViewMode? activeView,
  }) {
    final previewEnabled = _previewMode && previewAccess.allowed;

    emit(PublicOrgLoaded(
      previewAccess: previewAccess,
      activeView: activeView ?? _initialView,
      brandStream: _service.streamBrandProfile(
        _orgId,
        preview: previewEnabled,
      ),
      mediaStream: _service.streamPublicMedia(
        _orgId,
        preview: previewEnabled,
      ),
      impactStream: _service.streamImpactPoints(_orgId),
    ));
  }

  /// Switch the active view mode
  void setActiveView(PublicOrgViewMode view) {
    if (state is! PublicOrgLoaded) return;

    final currentState = state as PublicOrgLoaded;
    if (currentState.activeView == view) return;

    emit(currentState.copyWith(activeView: view));
  }

  /// Refresh preview access (useful after login)
  Future<void> refreshPreviewAccess() async {
    if (!_previewMode) return;
    if (state is! PublicOrgLoaded) return;

    final currentState = state as PublicOrgLoaded;
    final currentView = currentState.activeView;

    emit(const PublicOrgLoading());

    try {
      final decision =
          await PublicPreviewAccessService().evaluate(_orgId);
      _emitLoadedState(
        previewAccess: decision,
        activeView: currentView,
      );
    } catch (e) {
      emit(PublicOrgError(message: 'Failed to refresh access: $e'));
    }
  }
}
