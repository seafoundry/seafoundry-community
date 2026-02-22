// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/structure_edit_name/structure_edit_name_state.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/repositories/inventory/group_repository.dart';
import 'package:seafoundry_app/repositories/inventory/site_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/unique_name_validation_service.dart';

/// Cubit for managing structure name editing dialog state
class StructureEditNameCubit extends Cubit<StructureEditNameState> {
  StructureEditNameCubit({
    required String initialName,
    required FirebaseFirestore firestore,
  }) : _validationService = UniqueNameValidationService(firestore: firestore),
       super(StructureEditNameState(name: initialName));

  final UniqueNameValidationService _validationService;

  /// Update the name field
  void nameChanged(String name) {
    emit(state.copyWith(name: name, errorMessage: null));
  }

  /// Validate and save the structure name
  Future<bool> save({
    required GraphNodeRecord record,
    required Site? site,
    required SiteRepository? siteRepository,
    required GroupRepository? groupRepository,
    required ModelType modelType,
  }) async {
    final newName = state.name.trim();

    // Validate name is not empty
    if (newName.isEmpty) {
      emit(state.copyWith(errorMessage: 'Name cannot be empty'));
      return false;
    }

    // Check if name hasn't changed
    if (newName == record.name) {
      return false; // No change, consider as cancelled
    }

    emit(state.copyWith(loading: true, errorMessage: null));

    try {
      bool isUnique;

      if (modelType == ModelType.site) {
        // Site uniqueness check
        final domain = record.urlPath.split('/').first;
        isUnique = await _validationService.isSiteNameUnique(
          name: newName,
          organizationDomain: domain,
          organizationId: record.organizationId,
          excludeRecordId: record.id,
        );
      } else {
        // Group/structure uniqueness check
        if (site == null) {
          throw Exception('Could not find parent site');
        }
        isUnique = await _validationService.isStructureNameUnique(
          name: newName,
          modelType: modelType,
          site: site,
          excludeRecordId: record.id,
        );
      }
      if (isClosed) return false;

      if (!isUnique) {
        final typeName = modelType == ModelType.site ? 'site' : 'structure';
        emit(
          state.copyWith(
            errorMessage:
                'A $typeName with the name "$newName" already exists. Please choose a different name.',
            loading: false,
          ),
        );
        return false;
      }

      // Update the record
      if (modelType == ModelType.site && siteRepository != null) {
        final site = record as Site;
        final updatedSite = site.copyWith(name: newName);
        await siteRepository.updateSiteWithCorrection(
          originalSite: site,
          updatedSite: updatedSite,
          notes: 'Renamed from "${site.name}" to "$newName"',
        );
      } else if (groupRepository != null) {
        final group = record as Group;
        final updatedGroup = group.copyWith(name: newName);
        await groupRepository.updateRecord(updatedGroup);
      } else {
        throw Exception('Missing repository for model type: $modelType');
      }
      if (isClosed) return false;

      emit(state.copyWith(name: newName, loading: false));
      return true;
    } on FirebaseException catch (e, stackTrace) {
      if (isClosed) return false;
      LoggingService.instance.error('Firebase error updating structure name: ${e.message}', e, stackTrace);
      emit(
        state.copyWith(
          errorMessage: 'Failed to save changes: ${e.message}',
          loading: false,
        ),
      );
      return false;
    } catch (e, stackTrace) {
      if (isClosed) return false;
      LoggingService.instance.error('Failed to update structure name', e, stackTrace);
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
