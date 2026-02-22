// @tier: community
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/life_stage_progression/life_stage_progression_state.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/inventory/physical_form_config.dart';
import 'package:seafoundry_app/models/types/inventory_change_reason.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/repositories/inventory/event_repository.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/physical_form_registry.dart';
import 'package:seafoundry_app/services/physical_form_version_service.dart';

/// Cubit for managing life stage progression dialog state
///
/// Uses EventRepository.createLifeStageTransitionEvent to create canonical
/// LifeStageTransitionEvent objects that integrate with the inventory event system.
class LifeStageProgressionCubit extends Cubit<LifeStageProgressionState> {
  LifeStageProgressionCubit({
    required this.organism,
    required this.organismKind,
    required this.organismRepository,
    required this.eventRepository,
    required this.userId,
    required this.versionService,
  }) : super(const LifeStageProgressionState());

  final OrganismRecord organism;
  final OrganismKind organismKind;
  final OrganismRecordRepository organismRepository;
  final EventRepository eventRepository;
  final String userId;
  final PhysicalFormVersionService versionService;

  final _logger = LoggingService.instance;
  final _registry = PhysicalFormRegistry.instance;

  /// Load available physical forms for a selected life stage
  Future<void> loadFormsForLifeStage(LifeStage lifeStage) async {
    emit(state.copyWith(loadingForms: true, error: null));

    try {
      final forms = await _registry.getAvailableForms(organismKind, lifeStage);
      if (isClosed) return;

      if (forms.isEmpty) {
        emit(
          state.copyWith(
            loadingForms: false,
            error: 'No physical forms configured for ${lifeStage.displayName}',
          ),
        );
        return;
      }

      emit(
        state.resetFormSelection(
          lifeStage: lifeStage,
          forms: forms,
        ).copyWith(loadingForms: false),
      );
    } catch (error, stackTrace) {
      if (isClosed) return;
      _logger.error('Failed to load physical forms', error, stackTrace);
      emit(
        state.copyWith(
          loadingForms: false,
          error: 'Failed to load forms: $error',
        ),
      );
    }
  }

  /// Update selected life stage
  void lifeStageChanged(LifeStage? lifeStage) {
    if (lifeStage == null) {
      emit(state.copyWith(
        selectedLifeStage: null,
        availableForms: [],
        selectedForm: null,
        selectedSizeBand: null,
      ));
      return;
    }

    // Load forms for the new life stage
    loadFormsForLifeStage(lifeStage);
  }

  /// Update selected physical form
  void physicalFormChanged(PhysicalFormConfig? form) {
    if (form == null) {
      emit(state.copyWith(
        selectedForm: null,
        selectedSizeBand: null,
      ));
      return;
    }

    // Auto-select first size band if available
    final defaultSizeBand = form.defaultSizeBand;

    emit(state.copyWith(
      selectedForm: form,
      selectedSizeBand: defaultSizeBand,
    ));
  }

  /// Update selected size band
  void sizeBandChanged(SizeBandConfig? sizeBand) {
    emit(state.copyWith(selectedSizeBand: sizeBand));
  }

  /// Update reason
  void reasonChanged(LifeStageTransitionReason? reason) {
    emit(state.copyWith(reason: reason));
  }

  /// Update notes
  void notesChanged(String notes) {
    emit(state.copyWith(notes: notes));
  }

  /// Submit life stage progression
  Future<bool> submit() async {
    if (!state.isValid) {
      emit(state.copyWith(error: 'Please complete all required fields'));
      return false;
    }

    emit(state.copyWith(loading: true, error: null));

    try {
      final newLifeStage = LifeStageSpec(stage: state.selectedLifeStage!);
      final newPhysicalForm = PhysicalFormInstance(
        formId: state.selectedForm!.id,
        sizeBandId: state.selectedSizeBand!.id,
      );

      // Get current configuration version
      final currentVersion = await _getCurrentConfigVersion();
      if (isClosed) return false;

      // Append to life stage history
      final updatedHistory = organism.appendLifeStageTransition(
        newLifeStage,
        occurredAt: DateTime.now(),
        recordedBy: userId,
        notes: state.notes.isEmpty ? null : state.notes,
        sizeSnapshot: organism.sizeSpec,
      );

      // Update the organism record with new life stage and physical form
      final updatedOrganism = organism.copyWith(
        lifeStage: newLifeStage,
        physicalForm: newPhysicalForm,
        physicalFormConfigVersion: currentVersion,
        lifeStageHistory: updatedHistory,
      );

      // Use WriteBatch for atomic transaction: record update + event creation
      final batch = eventRepository.db.batch();

      await organismRepository.updateRecord(updatedOrganism, batch: batch);
      if (isClosed) return false;

      // Create life stage transition event using canonical event system
      // Note: This creates a LifeStageTransitionEvent which integrates with the
      // inventory event system (permits, metadata, snapshots)
      await eventRepository.createLifeStageTransitionEvent(
        recordId: organism.id,
        recordUrlPath: organism.urlPath,
        recordInternalPath: organism.internalPath,
        snapshot: updatedOrganism,
        oldLifeStage: organism.lifeStage.stage,
        newLifeStage: newLifeStage.stage,
        transitionReason: state.reason?.name,
        batch: batch,
      );
      if (isClosed) return false;

      // Commit atomic transaction
      await batch.commit();
      if (isClosed) return false;

      _logger.info(
        'Life stage progression completed',
        {
          'organismId': organism.id,
          'fromLifeStage': organism.lifeStage.stage.id,
          'toLifeStage': newLifeStage.stage.id,
          'physicalForm': newPhysicalForm.formId,
          'sizeBand': newPhysicalForm.sizeBandId,
        },
      );

      emit(state.copyWith(loading: false));
      return true;
    } catch (error, stackTrace) {
      if (isClosed) return false;
      _logger.error('Failed to progress life stage', error, stackTrace);
      emit(
        state.copyWith(
          loading: false,
          error: 'Failed to save: $error',
        ),
      );
      return false;
    }
  }

  /// Get current physical form configuration version from Firestore
  Future<String> _getCurrentConfigVersion() async {
    try {
      return await versionService.getCurrentVersion();
    } catch (e, stackTrace) {
      _logger.warning(
        'Failed to get config version, using fallback: $e',
        {'stackTrace': stackTrace.toString()},
      );
      return 'v1';
    }
  }

  /// Set loading state
  void setLoading(bool loading) {
    emit(state.copyWith(loading: loading));
  }
}
