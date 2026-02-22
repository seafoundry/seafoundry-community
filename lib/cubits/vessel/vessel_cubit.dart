// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/base/cubit_stream_subscription_mixin.dart';
import 'package:seafoundry_app/cubits/vessel/vessel_state.dart';
import 'package:seafoundry_app/models/operations/vessel.dart';
import 'package:seafoundry_app/repositories/vessel_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Cubit for managing vessel CRUD operations.
///
/// Uses [CubitStreamSubscriptionMixin] for automatic stream lifecycle management.
/// All subscriptions are automatically cancelled when the cubit is closed.
class VesselCubit extends Cubit<VesselState> with CubitStreamSubscriptionMixin {
  final VesselRepository _repository;
  final String _organizationId;

  VesselCubit({
    required VesselRepository repository,
    required String organizationId,
  })  : _repository = repository,
        _organizationId = organizationId,
        super(const VesselState());

  /// Start watching vessels for the organization
  void watchVessels() {
    emit(state.copyWith(loading: true));
    listenWithKey<List<Vessel>>(
      'vessels',
      _repository.watchVesselsForOrg(_organizationId),
      onData: (vessels) {
        if (!isClosed) {
          emit(state.copyWith(vessels: vessels, loading: false));
        }
      },
      onError: (error, stackTrace) {
        if (!isClosed) {
          LoggingService.instance.error('Error watching vessels', error, stackTrace);
          emit(
            state.copyWith(
              loading: false,
              errorMessage: 'Failed to load vessels: $error',
            ),
          );
        }
      },
    );
  }

  /// Load vessels once
  Future<void> loadVessels() async {
    emit(state.copyWith(loading: true, errorMessage: null));
    try {
      final vessels = await _repository.getVesselsForOrg(_organizationId);
      if (!isClosed) {
        emit(state.copyWith(vessels: vessels, loading: false));
      }
    } on FirebaseException catch (e, stackTrace) {
      if (!isClosed) {
        LoggingService.instance.error('Firebase error loading vessels: ${e.message}', e, stackTrace);
        emit(
          state.copyWith(
            loading: false,
            errorMessage: 'Failed to load vessels: ${e.message}',
          ),
        );
      }
    } catch (e, stackTrace) {
      if (!isClosed) {
        LoggingService.instance.error('Error loading vessels', e, stackTrace);
        emit(
          state.copyWith(
            loading: false,
            errorMessage: 'Failed to load vessels: $e',
          ),
        );
      }
    }
  }

  /// Create a new vessel
  Future<bool> createVessel(Vessel vessel) async {
    emit(state.copyWith(loading: true, errorMessage: null));
    try {
      await _repository.createVessel(vessel);
      if (!isClosed) {
        emit(state.copyWith(loading: false));
        return true;
      }
    } on FirebaseException catch (e, stackTrace) {
      if (!isClosed) {
        LoggingService.instance.error('Firebase error creating vessel: ${e.message}', e, stackTrace);
        emit(
          state.copyWith(
            loading: false,
            errorMessage: 'Failed to create vessel: ${e.message}',
          ),
        );
      }
    } catch (e, stackTrace) {
      if (!isClosed) {
        LoggingService.instance.error('Error creating vessel', e, stackTrace);
        emit(
          state.copyWith(
            loading: false,
            errorMessage: 'Failed to create vessel: $e',
          ),
        );
      }
    }
    return false;
  }

  /// Update an existing vessel
  Future<bool> updateVessel(Vessel vessel) async {
    emit(state.copyWith(loading: true, errorMessage: null));
    try {
      await _repository.updateVessel(vessel);
      if (!isClosed) {
        emit(state.copyWith(loading: false));
        return true;
      }
    } on FirebaseException catch (e, stackTrace) {
      if (!isClosed) {
        LoggingService.instance.error('Firebase error updating vessel: ${e.message}', e, stackTrace);
        emit(
          state.copyWith(
            loading: false,
            errorMessage: 'Failed to update vessel: ${e.message}',
          ),
        );
      }
    } catch (e, stackTrace) {
      if (!isClosed) {
        LoggingService.instance.error('Error updating vessel', e, stackTrace);
        emit(
          state.copyWith(
            loading: false,
            errorMessage: 'Failed to update vessel: $e',
          ),
        );
      }
    }
    return false;
  }

  /// Delete a vessel
  Future<bool> deleteVessel(String vesselId) async {
    emit(state.copyWith(loading: true, errorMessage: null));
    try {
      await _repository.deleteVessel(vesselId);
      if (!isClosed) {
        emit(state.copyWith(loading: false));
        return true;
      }
    } on FirebaseException catch (e, stackTrace) {
      if (!isClosed) {
        LoggingService.instance.error('Firebase error deleting vessel: ${e.message}', e, stackTrace);
        emit(
          state.copyWith(
            loading: false,
            errorMessage: 'Failed to delete vessel: ${e.message}',
          ),
        );
      }
    } catch (e, stackTrace) {
      if (!isClosed) {
        LoggingService.instance.error('Error deleting vessel', e, stackTrace);
        emit(
          state.copyWith(
            loading: false,
            errorMessage: 'Failed to delete vessel: $e',
          ),
        );
      }
    }
    return false;
  }

  /// Update vessel status
  Future<bool> updateVesselStatus(String vesselId, VesselStatus status) async {
    emit(state.copyWith(loading: true, errorMessage: null));
    try {
      await _repository.updateVesselStatus(vesselId, status);
      if (!isClosed) {
        emit(state.copyWith(loading: false));
        return true;
      }
    } on FirebaseException catch (e, stackTrace) {
      if (!isClosed) {
        LoggingService.instance.error('Firebase error updating vessel status: ${e.message}', e, stackTrace);
        emit(
          state.copyWith(
            loading: false,
            errorMessage: 'Failed to update vessel status: ${e.message}',
          ),
        );
      }
    } catch (e, stackTrace) {
      if (!isClosed) {
        LoggingService.instance.error('Error updating vessel status', e, stackTrace);
        emit(
          state.copyWith(
            loading: false,
            errorMessage: 'Failed to update vessel status: $e',
          ),
        );
      }
    }
    return false;
  }

  /// Select a vessel
  void selectVessel(Vessel vessel) {
    emit(state.copyWith(selectedVessel: vessel));
  }

  /// Clear selected vessel
  void clearSelection() {
    emit(state.copyWith(selectedVessel: null));
  }

  // Note: close() is automatically handled by CubitStreamSubscriptionMixin
}
