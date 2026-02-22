// @tier: community
import 'dart:collection';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/structure_capacity_config/structure_capacity_config_state.dart';
import 'package:seafoundry_app/cubits/structure_capacity_config/structure_capacity_rule_form.dart';
import 'package:seafoundry_app/services/firestore_collection_resolver.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/structure_capacity_service.dart';

/// Cubit for managing structure capacity configuration rules.
///
/// Loads/saves capacity rules from the organization config subcollection
/// and optionally refreshes the [StructureCapacityService] after save.
class StructureCapacityConfigCubit
    extends Cubit<StructureCapacityConfigState> {
  StructureCapacityConfigCubit({
    required FirebaseFirestore firestore,
    required this.organizationId,
    StructureCapacityService? structureCapacityService,
  })  : _firestore = firestore,
        _structureCapacityService = structureCapacityService,
        super(const StructureCapacityConfigState());

  final FirebaseFirestore _firestore;
  final String organizationId;
  final StructureCapacityService? _structureCapacityService;

  DocumentReference<Map<String, dynamic>> get _configDoc =>
      FirestoreCollectionResolver.instance
          .subcollection(
            _firestore,
            'organizations',
            organizationId,
            'config',
          )
          .doc('structure_capacity');

  Future<void> load() async {
    if (isClosed) return;
    emit(state.copyWith(isLoading: true, errorMessage: () => null));
    try {
      final snapshot = await _configDoc.get();
      final rules = <StructureCapacityRuleForm>[];
      if (snapshot.exists) {
        final data = snapshot.data();
        final rawRules = data?['rules'];
        if (rawRules is List) {
          for (final entry in rawRules.cast<Map<String, dynamic>>()) {
            final parsed = StructureCapacityRuleForm.fromMap(entry);
            if (parsed != null) {
              rules.add(parsed);
            }
          }
        }
      }
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoading: false,
          rules: () => UnmodifiableListView(rules),
          saveSuccess: false,
        ),
      );
    } on FirebaseException catch (e, stackTrace) {
      _handleFirebaseError(e, stackTrace, action: 'load');
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'Failed to load structure capacity rules',
        error,
        stackTrace,
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: () => 'Failed to load structure capacity rules.',
          saveSuccess: false,
        ),
      );
    }
  }

  void upsertRule(StructureCapacityRuleForm rule) {
    final updatedRules = List<StructureCapacityRuleForm>.from(state.rules);
    final existingIndex =
        updatedRules.indexWhere((existing) => existing.id == rule.id);
    if (existingIndex >= 0) {
      updatedRules[existingIndex] = rule;
    } else {
      updatedRules.add(rule);
    }
    emit(
      state.copyWith(
        rules: () => UnmodifiableListView(updatedRules),
        saveSuccess: false,
      ),
    );
  }

  void removeRule(String ruleId) {
    final updatedRules =
        state.rules.where((rule) => rule.id != ruleId).toList();
    emit(
      state.copyWith(
        rules: () => UnmodifiableListView(updatedRules),
        saveSuccess: false,
      ),
    );
  }

  Future<void> save() async {
    if (isClosed) return;
    emit(
      state.copyWith(
        isSaving: true,
        errorMessage: () => null,
        saveSuccess: false,
      ),
    );
    try {
      final payload = state.rules.map((rule) => rule.toMap()).toList();
      await _configDoc.set(
        {
          'rules': payload,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (isClosed) return;
      emit(state.copyWith(isSaving: false, saveSuccess: true));

      // Refresh overrides in background - failures here don't affect save
      try {
        await _structureCapacityService?.refreshOverrides(
          organizationId: organizationId,
        );
      } catch (refreshError) {
        LoggingService.instance.warning(
          'Failed to refresh capacity overrides after save '
          '(save was successful)',
          {'error': refreshError.toString()},
        );
      }
    } on FirebaseException catch (e, stackTrace) {
      _handleFirebaseError(e, stackTrace, action: 'save');
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'Failed to save structure capacity rules',
        error,
        stackTrace,
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          isSaving: false,
          errorMessage: () => 'Unable to save structure capacity rules.',
        ),
      );
    }
  }

  void _handleFirebaseError(
    FirebaseException e,
    StackTrace stackTrace, {
    required String action,
  }) {
    if (e.code == 'permission-denied' || e.code == 'PERMISSION_DENIED') {
      LoggingService.instance.warning(
        'Permission denied ${action}ing structure capacity rules: '
        '${e.message}',
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoading: false,
          isSaving: false,
          errorMessage: () =>
              'You do not have permission to $action '
              'structure capacity rules.',
          saveSuccess: false,
        ),
      );
      return;
    }
    LoggingService.instance.error(
      'Failed to $action structure capacity rules',
      e,
      stackTrace,
    );
    if (isClosed) return;
    emit(
      state.copyWith(
        isLoading: false,
        isSaving: false,
        errorMessage: () =>
            action == 'load'
                ? 'Failed to load structure capacity rules.'
                : 'Unable to save structure capacity rules.',
        saveSuccess: false,
      ),
    );
  }
}
