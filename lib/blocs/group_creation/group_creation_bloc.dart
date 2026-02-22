// @tier: community
import 'package:formz/formz.dart';
import 'package:seafoundry_app/blocs/group_creation/group_form_inputs.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_bloc.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_event.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_inputs.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_state.dart';
import 'package:seafoundry_app/blocs/record_form/record_form_step.dart';
import 'package:seafoundry_app/models/group.dart';
import 'package:seafoundry_app/models/model_interfaces.dart';
import 'package:seafoundry_app/models/site.dart';
import 'package:seafoundry_app/models/types/group_type.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/repositories/inventory/group_repository.dart';
import 'package:seafoundry_app/repositories/record_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/unique_name_validation_service.dart';

class GroupCreationBloc extends RecordFormBloc<Group, GroupFormState> {
  final GroupRepository groupRepository;
  final GroupParent groupParent;
  final RecordRepository recordRepository;

  GroupCreationBloc({
    required this.groupRepository,
    required this.groupParent,
    required this.recordRepository,
  }) : super(GroupFormState());

  @override
  GroupFormState get initialState => GroupFormState();

  /// Initialize the bloc for editing an existing group
  void initializeForEdit(Group group) {
    add(RecordNameChanged(group.name));
    final groupType = GroupType.builtins[group.groupTypeId];
    if (groupType == null) {
      LoggingService.instance.warning('Unknown groupTypeId ${group.groupTypeId}, falling back to GroupType.group');
    }
    add(GroupTypeSelected(groupType ?? GroupType.group));
    if (group.description != null) {
      add(GroupDescriptionChanged(group.description!));
    }
    if (group.capacity != null) {
      add(GroupCapacityChanged(group.capacity!));
    }
    
    add(RecordFormInitializeForEdit(group));
  }

  @override
  Future<Group?> createRecord() async {
    // Validate required fields before creating the group
    if (state.name.value == null || state.name.value!.trim().isEmpty) {
      throw Exception('Group name is required');
    }
    if (state.groupType.value == null) {
      throw Exception('Group type is required');
    }
    if (groupParent.siteId.isEmpty) {
      throw Exception('Parent site ID is required');
    }
    if (groupParent.id.isEmpty) {
      throw Exception('Parent ID is required');
    }

    // Validate parent-child hierarchy relationship
    final childGroupType = state.groupType.value!;
    if (!_isValidParentChildRelationship(childGroupType)) {
      final childCategoryName = childGroupType.category.name;
      final parentTypeName = groupParent is Group
          ? (groupParent as Group).groupType.name
          : 'Site';
      throw Exception(
        'Cannot add a $childCategoryName (${childGroupType.name}) '
        'inside a $parentTypeName. Please select a valid structure type.',
      );
    }

    final trimmedName = state.name.value!.trim();
    final site = await _resolveSiteForValidation();
    if (site == null) {
      throw Exception('Unable to load parent site for validation.');
    }

    final validationService = UniqueNameValidationService(firestore: groupRepository.db);
    final isUnique = await validationService.isStructureNameUnique(
      name: trimmedName,
      modelType: ModelType.group,
      site: site,
    );
    if (!isUnique) {
      throw Exception(
        'A structure named "$trimmedName" already exists in ${site.name}. Please choose a different name.',
      );
    }

    // Convert empty description to null to avoid validation failure
    // (empty strings are treated as "missing" by Record.validate())
    final description = state.description.value;
    final normalizedDescription =
        (description != null && description.isNotEmpty) ? description : null;

    Group newGroup = Group.partial(
      name: trimmedName,
      groupTypeId: state.groupType.value!.id,
      description: normalizedDescription,
      capacity: state.capacity.value,
      siteId: groupParent.siteId,
      parentId: groupParent.id,
    );
    
    // If editing, update existing record with correction event; otherwise create new
    if (state.isEditing && state.originalRecord != null) {
      final updatedGroup = newGroup.copyWith(
        id: state.originalRecord!.id,
        createdAt: state.originalRecord!.createdAt,
        createdById: state.originalRecord!.createdById,
        urlPath: state.originalRecord!.urlPath,
        internalPath: state.originalRecord!.internalPath,
        slug: state.originalRecord!.slug,
      );
      // Use updateWithCorrection to create correction event
      return await groupRepository.updateGroupWithCorrection(
        originalGroup: state.originalRecord!,
        updatedGroup: updatedGroup,
      );
    }
    
    return await groupRepository.createRecord(newGroup, groupParent);
  }

  Future<Site?> _resolveSiteForValidation() async {
    if (groupParent is Site) {
      return groupParent as Site;
    }

    final siteId = groupParent.siteId;
    if (siteId.isEmpty) return null;

    try {
      final site = await recordRepository.getRecord<Site>(
        ModelType.site,
        siteId,
      );
      if (site != null) return site;
    } catch (error, stackTrace) {
      LoggingService.instance.warning(
        'Failed to load parent site for group validation',
        {
          'siteId': siteId,
          'parentId': groupParent.id,
          'error': error.toString(),
        },
      );
      LoggingService.instance.debug(stackTrace.toString());
    }

    final fallbackUrlPath = _deriveSiteUrlPath(groupParent.urlPath);
    if (fallbackUrlPath == null) return null;

    return Site.partial(
      id: siteId,
      organizationId: groupParent.organizationId,
      name: 'Site',
      urlPath: fallbackUrlPath,
    );
  }

  String? _deriveSiteUrlPath(String urlPath) {
    final segments =
        urlPath.split('/').where((segment) => segment.isNotEmpty).toList();
    if (segments.length < 2) return null;
    return '${segments[0]}/${segments[1]}';
  }

  /// Validates that the child group type can be placed under the current parent.
  ///
  /// Hierarchy rules:
  /// - Site can contain superstructures or structures (not substructures directly)
  /// - Superstructure can contain structures or substructures directly
  /// - Structure can contain substructures only
  /// - Substructure cannot contain other groups
  ///
  /// The flexible superstructure rules allow workflows like Zone → Tag
  /// without requiring an intermediate structure (e.g., Grid).
  ///
  /// Note: This validation applies to new group creation only. Existing groups
  /// with invalid hierarchy relationships (from before this validation was added)
  /// can still be edited without changing their parent relationship.
  ///
  /// Returns `true` if the [childType] can be placed under [groupParent],
  /// `false` otherwise. Unknown parent types are allowed by default to avoid
  /// blocking edge cases.
  bool _isValidParentChildRelationship(GroupType childType) {
    if (groupParent is Site) {
      // Site can contain superstructures or structures (not substructures directly)
      return childType.isSuperstructure || childType.isStructure;
    }

    if (groupParent is Group) {
      final parentGroup = groupParent as Group;
      final validChildCategories = parentGroup.groupType.validChildCategories;

      // Check if child category is allowed by parent
      return validChildCategories.contains(childType.category);
    }

    // Unknown parent type - allow by default
    return true;
  }
}

/// Complete group form state
class GroupFormState extends RecordFormState<Group> {
  GroupFormState({
    List<RecordFormStep>? steps,
    super.currentStepIndex,
    FormzSubmissionStatus? submissionStatus,
    super.submissionError,
    super.createdRecord,
    super.originalRecord,
  }) : super(
         steps:
             steps ??
             [
               GroupTypeSelectionStep(),
               GroupDetailsStep(),
               RecordFormReviewStep(),
             ],
         submissionStatus: submissionStatus ?? FormzSubmissionStatus.initial,
       );

  @override
  GroupFormState copyWith({
    int? currentStepIndex,
    List<RecordFormStep>? steps,
    FormzSubmissionStatus? submissionStatus,
    String? submissionError,
    Group? createdRecord,
    Group? originalRecord,
    bool overrideSubmissionError = false,
  }) {
    return GroupFormState(
      steps: steps ?? this.steps,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      submissionStatus: submissionStatus ?? this.submissionStatus,
      submissionError: overrideSubmissionError
          ? submissionError
          : submissionError ?? this.submissionError,
      createdRecord: createdRecord ?? this.createdRecord,
      originalRecord: originalRecord ?? this.originalRecord,
    );
  }

  GroupTypeSelection get groupType =>
      inputs.firstWhere((input) => input is GroupTypeSelection)
          as GroupTypeSelection;
  RecordNameInput get name =>
      inputs.firstWhere((input) => input is RecordNameInput) as RecordNameInput;
  GroupDescription get description =>
      inputs.firstWhere((input) => input is GroupDescription)
          as GroupDescription;
  GroupCapacity get capacity =>
      inputs.firstWhere((input) => input is GroupCapacity) as GroupCapacity;
}

class GroupTypeSelectionStep extends RecordFormStep {
  GroupTypeSelectionStep({List<RecordFormInput>? inputs})
    : super(inputs: inputs ?? [GroupTypeSelection.pure()], title: 'Group Type');

  @override
  GroupTypeSelectionStep copyWith({required RecordFormInput copiedInput}) {
    return GroupTypeSelectionStep(inputs: updateInputs(copiedInput));
  }
}

class GroupDetailsStep extends RecordFormStep {
  GroupDetailsStep({List<RecordFormInput>? inputs})
    : super(
        inputs:
            inputs ??
            [
              RecordNameInput.pure(),
              GroupDescription.pure(),
              GroupCapacity.pure(),
            ],
        title: 'Group Details',
      );

  @override
  GroupDetailsStep copyWith({required RecordFormInput copiedInput}) {
    return GroupDetailsStep(inputs: updateInputs(copiedInput));
  }
}

class GroupTypeSelected extends RecordFormInputEvent<GroupType> {
  const GroupTypeSelected(super.value);
}

class GroupDescriptionChanged extends RecordFormInputEvent<String> {
  const GroupDescriptionChanged(super.value);
}

class GroupCapacityChanged extends RecordFormInputEvent<int> {
  const GroupCapacityChanged(super.value);
}
