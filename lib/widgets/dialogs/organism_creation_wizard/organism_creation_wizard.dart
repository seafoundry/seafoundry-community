import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:seafoundry_app/models/graph/graph_node.dart';
import 'package:seafoundry_app/cubits/current_user/current_user_cubit.dart';
import 'package:seafoundry_app/cubits/current_user/current_user_state.dart';
import 'package:seafoundry_app/cubits/organism_creation/organism_creation_cubit.dart';
import 'package:seafoundry_app/cubits/organism_creation/organism_creation_state.dart';
import 'package:seafoundry_app/errors/domain_errors.dart';
import 'package:seafoundry_app/models/genet.dart';
import 'package:seafoundry_app/models/group.dart';
import 'package:seafoundry_app/models/inventory/organism_creation_result.dart';
import 'package:seafoundry_app/models/inventory/organism_record.dart';
import 'package:seafoundry_app/models/records/graph_node_record.dart';
import 'package:seafoundry_app/models/site.dart';
import 'package:seafoundry_app/models/species.dart';
import 'package:seafoundry_app/models/types/life_stage.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/models/types/organism_kind.dart';
import 'package:seafoundry_app/models/types/provenance_type.dart';
import 'package:seafoundry_app/repositories/inventory/genet_repository.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/repositories/invitation_repository.dart';
import 'package:seafoundry_app/repositories/organization_repository.dart';
import 'package:seafoundry_app/repositories/record_repository.dart';
import 'package:seafoundry_app/services/firebase_service.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/provenance_lookup_service.dart';
import 'package:seafoundry_app/services/species_registry.dart';
import 'package:seafoundry_app/services/structure_capacity_service.dart';
import 'package:seafoundry_app/services/taxonomy_service.dart';
import 'package:seafoundry_app/services/unique_name_validation_service.dart';
import 'package:seafoundry_app/widgets/repositories/registry/registry.dart';
import 'package:seafoundry_app/widgets/spreadsheet/safe_provider_mixin.dart';

import '../../notifications/toast_overlay.dart';
import 'steps/index.dart';

/// Main wizard container for organism creation.
/// Wraps OrganismCreationCubit and provides step-based navigation UI.
class OrganismCreationWizard extends StatelessWidget {
  final String organizationId;
  final String? siteId;
  final String? groupId;
  final String createdById;
  final OrganismKind? initialOrganismKind;
  final LifeStage? initialLifeStage;
  final ProvenanceType? initialProvenanceType;
  final String? initialDamProvenanceId;
  final String? initialSireProvenanceId;
  final String? initialSourceCohortId;
  final Genet? initialGenet;
  final Map<String, dynamic>? additionalMetadata;
  final Future<OrganismRecord?> Function(OrganismCreationResult result)?
  onPersist;
  final ProvenanceLookupService? _provenanceLookupService;

  const OrganismCreationWizard({
    super.key,
    required this.organizationId,
    this.siteId,
    this.groupId,
    required this.createdById,
    this.initialOrganismKind,
    this.initialLifeStage,
    this.initialProvenanceType,
    this.initialDamProvenanceId,
    this.initialSireProvenanceId,
    this.initialSourceCohortId,
    this.initialGenet,
    this.additionalMetadata,
    this.onPersist,
    ProvenanceLookupService? provenanceLookupService,
  }) : _provenanceLookupService = provenanceLookupService;

  /// Private constructor used by [show] which captures the service before
  /// opening the dialog to avoid provider-not-found errors.
  const OrganismCreationWizard._({
    required this.organizationId,
    this.siteId,
    this.groupId,
    required this.createdById,
    required ProvenanceLookupService provenanceLookupService,
    this.initialOrganismKind,
    this.initialLifeStage,
    this.initialProvenanceType,
    this.initialDamProvenanceId,
    this.initialSireProvenanceId,
    this.initialSourceCohortId,
    this.initialGenet,
    this.additionalMetadata,
  }) : onPersist = null,
       _provenanceLookupService = provenanceLookupService;

  /// Shows the wizard and persists the organism record through repositories.
  static Future<OrganismRecord?> showAndCreate(
    BuildContext context, {
    GraphNode? parentGroupNode,
    OrganismKind? organismKind,
    Genet? initialGenet,
    OrganismKind? initialOrganismKind,
    LifeStage? initialLifeStage,
    ProvenanceType? initialProvenanceType,
    String? initialDamProvenanceId,
    String? initialSireProvenanceId,
    String? initialSourceCohortId,
    Map<String, dynamic>? additionalMetadata,
    String? siteId,
    String? groupId,
  }) async {
    final currentUser = context.read<CurrentUser>();
    final currentUserState = currentUser.state;
    if (currentUserState is! CurrentUserLoaded) {
      throw Exception('User not authenticated');
    }

    SpeciesRegistry.ensureGlobalHydrated();

    final recordRepository = context.read<RecordRepository>();
    final repositoryRegistry = context.read<RepositoryRegistry>();
    final speciesRegistry = context.read<SpeciesRegistry>();
    final taxonomyService = context.maybeRead<TaxonomyService?>();

    final genetRepository = context.maybeRead<GenetRepository>();
    final organizationRepository = context.maybeRead<OrganizationRepository>();
    final invitationRepository = context.maybeRead<InvitationRepository>();
    final provenanceLookupService = context
        .maybeRead<ProvenanceLookupService>();
    final capacityService = context.maybeRead<StructureCapacityService>();

    // Coral-only simplified build: always use coral
    const resolvedOrganismKind = OrganismKind.coral;

    final firestore = context.maybeRead<FirebaseService>()?.firestore;

    String? resolvedSiteId = siteId;
    String? resolvedGroupId = groupId;
    if (parentGroupNode != null) {
      final parentRecord = parentGroupNode.currentRecord;
      if (parentRecord is Group) {
        resolvedGroupId = parentRecord.id;
        resolvedSiteId = parentRecord.siteId;
      } else if (parentRecord is Site) {
        resolvedSiteId = parentRecord.id;
      }
    }

    return showDialog<OrganismRecord>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (_) => MultiRepositoryProvider(
        providers: [
          RepositoryProvider<RecordRepository>.value(value: recordRepository),
          RepositoryProvider<RepositoryRegistry>.value(
            value: repositoryRegistry,
          ),
          if (genetRepository != null)
            RepositoryProvider<GenetRepository>.value(value: genetRepository),
          if (organizationRepository != null)
            RepositoryProvider<OrganizationRepository>.value(
              value: organizationRepository,
            ),
          if (invitationRepository != null)
            RepositoryProvider<InvitationRepository>.value(
              value: invitationRepository,
            ),
        ],
        child: Provider<TaxonomyService?>.value(
          value: taxonomyService,
          child: ChangeNotifierProvider<SpeciesRegistry>.value(
            value: speciesRegistry,
            child: BlocProvider<CurrentUser>.value(
              value: currentUser,
              child: OrganismCreationWizard(
                organizationId: currentUserState.organization.id,
                siteId: resolvedSiteId,
                groupId: resolvedGroupId,
                createdById: currentUserState.user.id,
                initialOrganismKind: resolvedOrganismKind,
                initialLifeStage: initialLifeStage,
                initialProvenanceType: initialProvenanceType,
                initialDamProvenanceId: initialDamProvenanceId,
                initialSireProvenanceId: initialSireProvenanceId,
                initialSourceCohortId: initialSourceCohortId,
                initialGenet: initialGenet,
                additionalMetadata: additionalMetadata,
                onPersist: (result) => _persistCreationResult(
                  context: context,
                  creationResult: result,
                  currentUserState: currentUserState,
                  recordRepository: recordRepository,
                  repositoryRegistry: repositoryRegistry,
                  genetRepository: genetRepository,
                  capacityService: capacityService,
                  firestore: firestore,
                  siteId: resolvedSiteId,
                  groupId: resolvedGroupId,
                ),
                provenanceLookupService: provenanceLookupService,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Shows the wizard as a dialog and returns the creation result.
  static Future<OrganismCreationResult?> show(
    BuildContext context, {
    required String organizationId,
    String? siteId,
    String? groupId,
    required String createdById,
    OrganismKind? initialOrganismKind,
    LifeStage? initialLifeStage,
    ProvenanceType? initialProvenanceType,
    String? initialDamProvenanceId,
    String? initialSireProvenanceId,
    String? initialSourceCohortId,
    Genet? initialGenet,
    Map<String, dynamic>? additionalMetadata,
  }) async {
    // Capture service BEFORE showDialog — dialog context is under the root
    // navigator and may not have the provider in its ancestor tree.
    final provenanceLookupService = context.read<ProvenanceLookupService>();

    return showDialog<OrganismCreationResult>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (_) => OrganismCreationWizard._(
        organizationId: organizationId,
        siteId: siteId,
        groupId: groupId,
        createdById: createdById,
        provenanceLookupService: provenanceLookupService,
        initialOrganismKind: initialOrganismKind,
        initialLifeStage: initialLifeStage,
        initialProvenanceType: initialProvenanceType,
        initialDamProvenanceId: initialDamProvenanceId,
        initialSireProvenanceId: initialSireProvenanceId,
        initialSourceCohortId: initialSourceCohortId,
        initialGenet: initialGenet,
        additionalMetadata: additionalMetadata,
      ),
    );
  }

  static Future<OrganismRecord?> _persistCreationResult({
    required BuildContext context,
    required OrganismCreationResult creationResult,
    required CurrentUserLoaded currentUserState,
    required RecordRepository recordRepository,
    required RepositoryRegistry repositoryRegistry,
    required GenetRepository? genetRepository,
    required StructureCapacityService? capacityService,
    required FirebaseFirestore? firestore,
    required String? siteId,
    required String? groupId,
  }) async {
    final organization = currentUserState.organization;
    final record = creationResult.record;
    if (firestore != null) {
      final validationService = UniqueNameValidationService(
        firestore: firestore,
      );

      if (record.genetRecordId == null) {
        final genetLocalId = record.localGenetId?.trim();
        if (genetLocalId != null && genetLocalId.isNotEmpty) {
          final isGenetUnique = await validationService.isGenetNameUnique(
            name: genetLocalId,
            organizationDomain: organization.domain,
            organizationId: organization.id,
          );
          if (!isGenetUnique) {
            throw RepositoryError(
              message:
                  'Local ID "$genetLocalId" already exists. Select the existing genet instead.',
            );
          }
        }
      }
    }

    var recordToSave = record;
    if (record.genetRecordId == null) {
      if (genetRepository == null) {
        throw RepositoryError(
          message: 'Genet repository not available for creation.',
        );
      }
      final genetLocalId = record.localGenetId?.trim();
      if (genetLocalId == null || genetLocalId.isEmpty) {
        throw RepositoryError(
          message: 'Local ID is required to create a genet.',
        );
      }
      final speciesId = record.speciesId?.trim();
      if (speciesId == null || speciesId.isEmpty) {
        throw RepositoryError(
          message: 'Species is required to create a genet.',
        );
      }
      final provenanceType = record.provenanceType ?? ProvenanceType.unknown;
      final provenance = <String, dynamic>{};
      final recordMetadata = record.metadata ?? const <String, dynamic>{};
      final genetMetadata = <String, dynamic>{};
      final wildMethod = record.provenanceAttributes.wildCollectionMethod
          ?.trim();
      if (wildMethod != null && wildMethod.isNotEmpty) {
        provenance['collectionMethod'] = wildMethod;
      }
      final extraProvenance = creationResult.provenanceMetadata;
      if (extraProvenance != null && extraProvenance.isNotEmpty) {
        provenance.addAll(extraProvenance);
      }
      if (provenanceType == ProvenanceType.transfer) {
        final sourceOrganizationId = recordMetadata['sourceOrganizationId']
            ?.toString()
            .trim();
        if (sourceOrganizationId != null && sourceOrganizationId.isNotEmpty) {
          provenance['sending_organization'] = sourceOrganizationId;
        }
        final sourceOrganizationEmail =
            recordMetadata['sourceOrganizationEmail']?.toString().trim();
        if (sourceOrganizationEmail != null &&
            sourceOrganizationEmail.isNotEmpty) {
          genetMetadata['sourceOrganizationEmail'] = sourceOrganizationEmail;
        }
      }

      final clonalValue = creationResult.clonalValue?.trim();
      final accessionValue = creationResult.accessionValue?.trim();

      final genetDraft = Genet.partial(
        name: genetLocalId,
        localGenetId: genetLocalId,
        speciesId: speciesId,
        provenanceTypeId: provenanceType.id,
        organismKind: record.organismKind,
        clonalId: clonalValue != null && clonalValue.isNotEmpty
            ? clonalValue
            : null,
        accessionNumber: accessionValue != null && accessionValue.isNotEmpty
            ? accessionValue
            : null,
        provenance: provenance.isEmpty ? null : provenance,
        metadata: genetMetadata.isNotEmpty ? genetMetadata : null,
      );

      final createdGenet = await genetRepository.createGenet(
        genetDraft,
        inheritedProvenanceId: creationResult.inheritedProvenanceId,
      );
      recordToSave = record.copyWith(genetRecordId: createdGenet.id);
    }

    OrganismRecordRepository? repository;
    try {
      repository = repositoryRegistry.getForKind<OrganismRecordRepository>(
        record.organismKind,
      );
    } catch (_) {}
    if (repository == null) {
      throw RepositoryError(
        message: 'No repository found for ${record.organismKind.name}.',
      );
    }

    GraphNodeRecord? parentRecord;
    if (groupId != null) {
      parentRecord = await recordRepository.getRecord<Group>(
        ModelType.group,
        groupId,
        organizationId: organization.id,
      );
    } else if (siteId != null) {
      parentRecord = await recordRepository.getRecord<Site>(
        ModelType.site,
        siteId,
      );
    } else {
      parentRecord = organization;
    }

    if (parentRecord == null) {
      throw RepositoryError(message: 'Parent record not found.');
    }

    if (parentRecord is Group) {
      if (!context.mounted) {
        throw RepositoryError(message: 'Context unmounted during validation.');
      }
      await _validateCapacity(
        capacityService: capacityService,
        group: parentRecord,
        record: recordToSave,
        repository: repository,
        context: context,
      );
    }

    final createdRecord = await repository.createRecord(
      recordToSave,
      parentRecord,
    );

    if (firestore != null && record.speciesId != null) {
      final validationService = UniqueNameValidationService(
        firestore: firestore,
      );
      validationService.invalidateOrganismSuggestionCache(
        speciesId: record.speciesId!,
        organizationId: organization.id,
      );
    }

    if (!context.mounted) return createdRecord;
    ToastOverlay.showSnackBar(
      context,
      const SnackBar(content: Text('Organism record created')),
    );

    return createdRecord;
  }

  static Future<void> _validateCapacity({
    required StructureCapacityService? capacityService,
    required Group group,
    required OrganismRecord record,
    required OrganismRecordRepository repository,
    required BuildContext context,
  }) async {
    if (capacityService == null) {
      return;
    }

    final currentCount = await repository.countByGroup(group.id);
    final evaluation = capacityService.evaluate(
      StructureCapacityRequest.forOccupants(
        containerType: group.groupType,
        organismKind: record.organismKind,
        lifeStage: record.lifeStage.stage,
        physicalFormId: record.physicalForm?.formId,
        currentUnits: currentCount,
        deltaUnits: 1,
      ),
    );

    if (!evaluation.hasRule) {
      return;
    }

    if (evaluation.isOverCapacity) {
      throw CapabilityConstraintError(
        message: evaluation.blockingMessage,
        capability: 'structureCapacity',
        recoverySuggestion:
            'Choose a different group or remove existing organisms.',
        context: {
          'groupId': group.id,
          'groupName': group.name,
          'organismKind': record.organismKind.name,
          'currentUnits': currentCount,
          'projectedUnits': evaluation.projectedUnits,
          'maxUnits': evaluation.rule?.maxUnits,
        },
      );
    }

    if (evaluation.isWarning && context.mounted) {
      final warnings = evaluation.warnings.join('\n');
      ToastOverlay.showSnackBar(context, SnackBar(content: Text(warnings)));
      LoggingService.instance.warning('Organism creation nearing capacity', {
        'groupId': group.id,
        'groupName': group.name,
        'organismKind': record.organismKind.name,
        'projectedUnits': evaluation.projectedUnits,
        'maxUnits': evaluation.rule?.maxUnits,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provenanceLookupService =
        _provenanceLookupService ??
        context.maybeRead<ProvenanceLookupService>();
    final wizard = BlocProvider(
      create: (context) {
        final genetRepository = context.read<GenetRepository>();
        final cubit = OrganismCreationCubit(
          provenanceLookupService: provenanceLookupService,
          genetRepository: genetRepository,
          initialOrganismKind: initialOrganismKind,
          initialLifeStage: initialLifeStage,
          initialProvenanceType: initialProvenanceType,
          initialDamProvenanceId: initialDamProvenanceId,
          initialSireProvenanceId: initialSireProvenanceId,
          initialSourceCohortId: initialSourceCohortId,
        );
        final genet = initialGenet;
        if (genet != null) {
          // Existing genet selection sets mode to existing inventory.
          cubit.isNewGenetChanged(false);
          cubit.genetSelected(genet);
          final species = Species.lookupById(genet.speciesId);
          if (species != null) {
            cubit.speciesChanged(species);
          }
        }
        return cubit;
      },
      child: _WizardContent(
        organizationId: organizationId,
        siteId: siteId,
        groupId: groupId,
        createdById: createdById,
        additionalMetadata: additionalMetadata,
        onPersist: onPersist,
      ),
    );
    if (provenanceLookupService == null) {
      return wizard;
    }
    return RepositoryProvider<ProvenanceLookupService>.value(
      value: provenanceLookupService,
      child: wizard,
    );
  }
}

/// Internal wizard content using cubit-managed state (no local state).
class _WizardContent extends StatelessWidget {
  final String organizationId;
  final String? siteId;
  final String? groupId;
  final String createdById;
  final Map<String, dynamic>? additionalMetadata;
  final Future<OrganismRecord?> Function(OrganismCreationResult result)?
  onPersist;

  const _WizardContent({
    required this.organizationId,
    this.siteId,
    this.groupId,
    required this.createdById,
    this.additionalMetadata,
    this.onPersist,
  });

  Future<void> _ensureSuggestedRecordName(BuildContext context) async {
    final cubit = context.read<OrganismCreationCubit>();
    final state = cubit.state;
    if (state.tagId?.trim().isNotEmpty == true) return;

    final localGenetId = state.effectiveLocalId?.trim();
    if (localGenetId == null || localGenetId.isEmpty) return;

    // Use localGenetId as the default record name
    final current = cubit.state;
    if (current.tagId?.trim().isNotEmpty == true) return;
    if (current.effectiveLocalId?.trim() != localGenetId) return;

    cubit.recordNameChanged(localGenetId);
  }

  Future<void> _submit(BuildContext context) async {
    final cubit = context.read<OrganismCreationCubit>();

    cubit.setLoading(true);
    await _ensureSuggestedRecordName(context);
    final result = cubit.submit(
      organizationId: organizationId,
      createdById: createdById,
      siteId: siteId,
      groupId: groupId,
      additionalMetadata: additionalMetadata,
    );

    if (result == null) {
      cubit.setLoading(false);
      return;
    }

    final persist = onPersist;
    if (persist == null) {
      if (context.mounted) {
        Navigator.of(context).pop(result);
      } else {
        cubit.setLoading(false);
      }
      return;
    }

    try {
      final record = await persist(result);
      if (record != null && context.mounted) {
        Navigator.of(context).pop(record);
      } else {
        cubit.setLoading(false);
      }
    } on RepositoryError catch (e, stackTrace) {
      LoggingService.instance.error(
        'OrganismCreationWizard persistence failed',
        e,
        stackTrace,
      );
      cubit.setError(e.message);
      cubit.setLoading(false);
    } on DomainError catch (e, stackTrace) {
      LoggingService.instance.error(
        'OrganismCreationWizard persistence failed',
        e,
        stackTrace,
      );
      cubit.setError(e.message);
      cubit.setLoading(false);
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'OrganismCreationWizard persistence failed',
        e,
        stackTrace,
      );
      cubit.setError('Failed to create organism: $e');
      cubit.setLoading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<OrganismCreationCubit, OrganismCreationState>(
      listenWhen: (prev, curr) {
        final wasReview = prev.currentStep == OrganismCreationStep.review;
        final isReview = curr.currentStep == OrganismCreationStep.review;
        if (!isReview) return false;

        final enteredReview = !wasReview && isReview;
        final localIdChanged = prev.effectiveLocalId != curr.effectiveLocalId;
        final recordNameCleared =
            (prev.tagId?.trim().isNotEmpty ?? false) &&
            (curr.tagId?.trim().isEmpty ?? true);

        return enteredReview ||
            (wasReview && (localIdChanged || recordNameCleared));
      },
      listener: (context, state) {
        unawaited(_ensureSuggestedRecordName(context));
      },
      child: BlocBuilder<OrganismCreationCubit, OrganismCreationState>(
        buildWhen: (prev, curr) =>
            prev.isNewGenet != curr.isNewGenet ||
            prev.isLoading != curr.isLoading ||
            prev.error != curr.error ||
            prev.currentStep != curr.currentStep ||
            prev.completedSteps != curr.completedSteps ||
            prev.organismKind != curr.organismKind ||
            prev.species != curr.species ||
            prev.localGenetId != curr.localGenetId ||
            prev.lifeStage != curr.lifeStage ||
            prev.physicalForm != curr.physicalForm ||
            prev.provenanceType != curr.provenanceType ||
            prev.wildCollectionMethod != curr.wildCollectionMethod ||
            prev.collectionReefOrigin != curr.collectionReefOrigin ||
            prev.collectionDate != curr.collectionDate ||
            prev.collectionDepth != curr.collectionDepth ||
            prev.collectionHabitatType != curr.collectionHabitatType ||
            prev.collectionInstitution != curr.collectionInstitution ||
            prev.collectionLatitude != curr.collectionLatitude ||
            prev.collectionLongitude != curr.collectionLongitude ||
            prev.sireProvenanceId != curr.sireProvenanceId ||
            prev.damProvenanceId != curr.damProvenanceId ||
            prev.sourceCohortId != curr.sourceCohortId ||
            prev.transferOrgId != curr.transferOrgId ||
            prev.transferEmail != curr.transferEmail ||
            prev.gainReason != curr.gainReason ||
            prev.measurement != curr.measurement ||
            prev.clonalId != curr.clonalId ||
            prev.accessionNumber != curr.accessionNumber ||
            prev.provenanceSearch != curr.provenanceSearch ||
            prev.selectedGenet != curr.selectedGenet,
        builder: (context, state) {
          final activeSteps = state.activeSteps;
          final currentStepIssues = state.currentStepIssues;
          final canAdvance = state.canAdvanceFromCurrentStep;

          return Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with step indicator
                  _buildHeader(context, state, activeSteps),

                  // Error display
                  if (state.error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      color: Colors.red.shade50,
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              state.error!,
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Step content
                  Expanded(child: _buildStepContent(context, state)),

                  // Navigation buttons
                  _buildNavigationButtons(
                    context,
                    state,
                    activeSteps,
                    currentStepIssues,
                    canAdvance,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    OrganismCreationState state,
    List<OrganismCreationStep> activeSteps,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.add_circle_outline),
              const SizedBox(width: 8),
              const Text(
                'Create Organism',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Step progress indicator
          _buildStepIndicator(context, state, activeSteps),
          const SizedBox(height: 8),
          // Current step name
          Text(
            state.currentStep.displayName,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(
    BuildContext context,
    OrganismCreationState state,
    List<OrganismCreationStep> activeSteps,
  ) {
    final theme = Theme.of(context);
    return Row(
      children: activeSteps.map((step) {
        final isActive = step == state.currentStep;
        final isCompleted = state.completedSteps.contains(step);

        return Expanded(
          child: Container(
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: isActive
                  ? theme.colorScheme.primary
                  : isCompleted
                  ? theme.colorScheme.tertiary
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStepContent(BuildContext context, OrganismCreationState state) {
    return switch (state.currentStep) {
      OrganismCreationStep.identity => IdentityStep(state: state),
      OrganismCreationStep.provenance => ProvenanceStep(state: state),
      OrganismCreationStep.gainReason => GainReasonStep(state: state),
      OrganismCreationStep.biometrics => BiometricsStep(state: state),
      OrganismCreationStep.measurements => MeasurementsStep(state: state),
      OrganismCreationStep.review => ReviewStep(state: state),
    };
  }

  Widget _buildNavigationButtons(
    BuildContext context,
    OrganismCreationState state,
    List<OrganismCreationStep> activeSteps,
    List<String> currentStepIssues,
    bool canAdvance,
  ) {
    final cubit = context.read<OrganismCreationCubit>();
    final currentIndex = activeSteps.indexOf(state.currentStep);
    final isFirstStep = currentIndex == 0;
    final isLastStep = currentIndex == activeSteps.length - 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Cancel on first step, Back on subsequent steps
          if (isFirstStep)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            )
          else
            TextButton.icon(
              onPressed: cubit.previousStep,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back'),
            ),

          // Step validation errors
          if (currentStepIssues.isNotEmpty)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Missing: ${currentStepIssues.join(", ")}',
                  style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            )
          else
            const Spacer(),

          // Next/Submit button
          if (isLastStep)
            FilledButton.icon(
              onPressed: state.canSubmit && !state.isLoading
                  ? () => _submit(context)
                  : null,
              icon: state.isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: const Text('Create'),
            )
          else
            FilledButton.icon(
              onPressed: canAdvance ? cubit.nextStep : null,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Next'),
            ),
        ],
      ),
    );
  }
}
