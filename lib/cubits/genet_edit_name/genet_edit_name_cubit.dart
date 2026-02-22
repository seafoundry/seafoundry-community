// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/genet_edit_name/genet_edit_name_state.dart';
import 'package:seafoundry_app/errors/domain_errors.dart' as domainErrors;
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/repositories/inventory/genet_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';

class GenetEditNameCubit extends Cubit<GenetEditNameState> {
  GenetEditNameCubit({
    required String initialName,
    required GenetRepository genetRepository,
  }) : _genetRepository = genetRepository,
       super(GenetEditNameState(name: initialName));

  final GenetRepository _genetRepository;

  void nameChanged(String name) {
    emit(state.copyWith(name: name, errorMessage: null));
  }

  /// Save by updating the Genet via GenetRepository.updateGenet().
  ///
  /// Name uniqueness is validated inside [GenetRepository.updateGenet],
  /// so no manual uniqueness check is needed here.
  Future<bool> save({
    required Genet original,
  }) async {
    final newName = state.name.trim();

    if (newName.isEmpty) {
      emit(state.copyWith(errorMessage: 'Name cannot be empty'));
      return false;
    }

    if (newName == original.name.trim()) {
      return false; // No change
    }

    emit(state.copyWith(loading: true, errorMessage: null));

    try {
      final updated = original.copyWith(name: newName);
      await _genetRepository.updateGenet(
        original: original,
        updated: updated,
      );
      if (isClosed) return false;

      emit(state.copyWith(name: newName, loading: false));
      return true;
    } on domainErrors.RepositoryError catch (e) {
      if (isClosed) return false;
      LoggingService.instance.error(
        'Repository error updating genet name: ${e.message}',
        e,
      );
      emit(
        state.copyWith(
          errorMessage: e.message,
          loading: false,
        ),
      );
      return false;
    } on FirebaseException catch (e, stackTrace) {
      if (isClosed) return false;
      LoggingService.instance.error(
        'Firebase error updating genet name: ${e.message}',
        e,
        stackTrace,
      );
      emit(
        state.copyWith(
          errorMessage: 'Failed to save changes: ${e.message}',
          loading: false,
        ),
      );
      return false;
    } catch (e, stackTrace) {
      if (isClosed) return false;
      LoggingService.instance.error(
        'Failed to update genet name',
        e,
        stackTrace,
      );
      emit(
        state.copyWith(
          errorMessage: 'Failed to save changes: $e',
          loading: false,
        ),
      );
      return false;
    }
  }
}
