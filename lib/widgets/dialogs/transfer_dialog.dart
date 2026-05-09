// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:seafoundry_app/cubits/navigation/navigation_cubit.dart';
import 'package:seafoundry_app/cubits/transfer/batch_transfer_cubit.dart';
import 'package:seafoundry_app/cubits/transfer/batch_transfer_enums.dart';
import 'package:seafoundry_app/cubits/transfer/transfer_initiate_cubit.dart';
import 'package:seafoundry_app/cubits/transfer/transfer_receive_cubit.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/models/transfer_manifest.dart';
import 'package:seafoundry_app/repositories/inventory/genet_repository.dart';
import 'package:seafoundry_app/repositories/inventory/group_repository.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/repositories/inventory/site_repository.dart';
import 'package:seafoundry_app/repositories/organization_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/organism_holding_loader.dart';
import 'package:seafoundry_app/services/manual_transfer_registration_service.dart';
import 'package:seafoundry_app/services/transfer_service.dart';
import 'package:seafoundry_app/services/unique_name_validation_service.dart';
import 'package:seafoundry_app/widgets/dialogs/base/dialog_base.dart';
import 'package:seafoundry_app/widgets/dialogs/transfer/batch_transfer_dialog.dart';
import 'package:seafoundry_app/widgets/dialogs/transfer/transfer_initiate_dialog.dart';
import 'package:seafoundry_app/widgets/dialogs/transfer/transfer_manual_register_dialog.dart';
import 'package:seafoundry_app/widgets/dialogs/transfer/transfer_receive_dialog.dart';
import 'package:seafoundry_app/widgets/spreadsheet/safe_provider_mixin.dart';
import '../notifications/toast_overlay.dart';

/// Mode for the transfer dialog
enum TransferDialogMode {
  /// Initiate a transfer to another organization
  initiate,

  /// Receive a transfer via manifest payload
  receive,

  /// Manually register a received genet
  manualRegister,
}

typedef _TransferDialogCoreDependencies = ({
  TransferService transferService,
  OrganizationRepository organizationRepository,
  Organization organization,
  NavigationCubit navigationCubit,
});

/// Universal dialog for genet transfer operations (initiate, receive, manual register).
///
/// Provider expectations:
/// - [`TransferService`] for API calls
/// - [`OrganizationRepository`] for organization lookup/edit mode
/// - Receive dialog handles manifest payload entry for incoming transfers
class TransferDialog extends StatelessWidget {
  final TransferDialogMode mode;
  final String? genetName;
  final String? genetRecordId;
  final String? speciesId;
  final List<String>? speciesIds; // For manual register
  final OrganismContext organismContext;
  final OrganismHoldingLoader? holdingsLoaderOverride;
  final bool Function(OrganismKind kind)? holdingsSupportOverride;
  final Future<List<Map<String, dynamic>>> Function(OrganismKind kind)?
  holdingsRowsOverride;
  final ProvenanceLifeStageSelection? initialProvenanceSelection;
  final TransferEvent? originalEvent; // For edit mode
  final OrganizationRepository? organizationRepository;
  final bool allowLocalIdSelection;
  final TransferManifest? initialManifest;

  TransferDialog({
    super.key,
    required this.mode,
    this.genetName,
    this.genetRecordId,
    this.speciesId,
    this.speciesIds,
    OrganismContext? organismContext,
    this.holdingsLoaderOverride,
    this.holdingsSupportOverride,
    this.holdingsRowsOverride,
    this.initialProvenanceSelection,
    this.originalEvent,
    this.organizationRepository,
    this.allowLocalIdSelection = false,
    this.initialManifest,
  }) : organismContext =
           organismContext ?? OrganismContext.forKind(OrganismKind.coral);

  /// Show the transfer dialog for initiating a transfer
  static Future<bool?> showInitiate(
    BuildContext context, {
    required String genetName,
    required String genetRecordId,
    required String speciesId,
    String? sourceStructureUrlPath,
    ProvenanceLifeStageSelection? initialSelection,
    bool allowLocalIdSelection = false,
  }) {
    final organismContext = _readOrganismContext(context);
    final dependencies = _readCoreDependencies(context);
    final genetRepository = context.maybeRead<GenetRepository>();
    final repositories = context.safeReadAll(
      () => (
        context.read<OrganismRecordRepository>(),
        context.read<GroupRepository>(),
        context.read<SiteRepository>(),
      ),
    );
    if (repositories == null) {
      _showLoadingSnackBar(
        context,
        message: 'Transfer tools are still loading. Please try again.',
      );
      return Future.value(false);
    }
    final (organismRepository, groupRepository, siteRepository) = repositories;
    return DialogBase.showDialogWithProviders<bool>(
      context: context,
      barrierDismissible: false,
      providers: [
        RepositoryProvider<OrganismRecordRepository>.value(
          value: organismRepository,
        ),
        RepositoryProvider<GroupRepository>.value(value: groupRepository),
        RepositoryProvider<SiteRepository>.value(value: siteRepository),
        ..._coreProviders(dependencies),
        if (genetRepository != null)
          RepositoryProvider<GenetRepository>.value(value: genetRepository),
      ],
      dialog: BlocProvider(
        create: (_) => TransferInitiateCubit(
          transferService: dependencies.transferService,
          organizationRepository: dependencies.organizationRepository,
          sourceStructureUrlPath: sourceStructureUrlPath,
          initialProvenanceSelection: initialSelection,
        ),
        child: TransferDialog(
          mode: TransferDialogMode.initiate,
          genetName: genetName,
          genetRecordId: genetRecordId,
          speciesId: speciesId,
          organismContext: organismContext,
          initialProvenanceSelection: initialSelection,
          allowLocalIdSelection: allowLocalIdSelection,
        ),
      ),
    );
  }

  static OrganismContext _readOrganismContext(BuildContext context) {
    return context.maybeRead<OrganismContext>() ??
        OrganismContext.forKind(OrganismKind.coral);
  }

  static _TransferDialogCoreDependencies _readCoreDependencies(
    BuildContext context,
  ) {
    return (
      transferService: context.read<TransferService>(),
      organizationRepository: context.read<OrganizationRepository>(),
      organization: context.read<Organization>(),
      navigationCubit: context.read<NavigationCubit>(),
    );
  }

  static List<SingleChildWidget> _coreProviders(
    _TransferDialogCoreDependencies dependencies, {
    bool includeTransferService = true,
  }) {
    return [
      RepositoryProvider<OrganizationRepository>.value(
        value: dependencies.organizationRepository,
      ),
      if (includeTransferService)
        Provider<TransferService>.value(value: dependencies.transferService),
      Provider<Organization>.value(value: dependencies.organization),
      BlocProvider<NavigationCubit>.value(value: dependencies.navigationCubit),
    ];
  }

  static void _showLoadingSnackBar(
    BuildContext context, {
    required String message,
  }) {
    ToastOverlay.showSnackBar(context, SnackBar(content: Text(message)));
  }

  static ProvenanceLifeStageSelection selectionForGenet(
    ProvenanceRecord record,
  ) => ProvenanceLifeStageSelection(
    provenanceType: record.provenanceType,
    lifeStage:
        LifeStageX.tryParse(record.metadata['lifeStage']?.toString()) ??
        LifeStage.adult,
  );

  /// Show the transfer dialog for receiving a transfer
  static Future<ProvenanceRecord?> showReceive(
    BuildContext context, {
    TransferManifest? initialManifest,
  }) {
    final organismContext = _readOrganismContext(context);
    final dependencies = _readCoreDependencies(context);
    final repositories = context.safeReadAll(
      () => (
        context.read<OrganismRecordRepository>(),
        context.read<SiteRepository>(),
      ),
    );
    if (repositories == null) {
      _showLoadingSnackBar(
        context,
        message: 'Transfer tools are still loading. Please try again.',
      );
      return Future.value(null);
    }
    final (organismRecordRepository, siteRepository) = repositories;
    final groupRepository = context.maybeRead<GroupRepository>();
    final validationService = UniqueNameValidationService(
      firestore: organismRecordRepository.db,
    );
    return DialogBase.showDialogWithProviders<ProvenanceRecord?>(
      context: context,
      barrierDismissible: false,
      providers: [
        RepositoryProvider<OrganismRecordRepository>.value(
          value: organismRecordRepository,
        ),
        RepositoryProvider<SiteRepository>.value(value: siteRepository),
        ..._coreProviders(dependencies),
        if (groupRepository != null)
          RepositoryProvider<GroupRepository>.value(value: groupRepository),
        Provider<UniqueNameValidationService>.value(value: validationService),
      ],
      dialog: BlocProvider(
        create: (_) =>
            TransferReceiveCubit(transferService: dependencies.transferService),
        child: TransferDialog(
          mode: TransferDialogMode.receive,
          organismContext: organismContext,
          initialManifest: initialManifest,
        ),
      ),
    );
  }

  /// Show the transfer dialog for manually registering a genet
  static Future<ProvenanceRecord?> showManualRegister(
    BuildContext context, {
    required List<String> speciesIds,
  }) {
    final organismContext = _readOrganismContext(context);
    final dependencies = _readCoreDependencies(context);
    final organismRecordRepository = context.read<OrganismRecordRepository>();
    final validationService = UniqueNameValidationService(
      firestore: organismRecordRepository.db,
    );
    return DialogBase.showDialogWithProviders<ProvenanceRecord?>(
      context: context,
      providers: [
        ..._coreProviders(dependencies, includeTransferService: false),
        // Provide interface type; TransferService implements ManualTransferRegistrationService
        Provider<ManualTransferRegistrationService>.value(
          value: dependencies.transferService,
        ),
        Provider<UniqueNameValidationService>.value(value: validationService),
      ],
      dialog: TransferDialog(
        mode: TransferDialogMode.manualRegister,
        speciesIds: speciesIds,
        organismContext: organismContext,
        organizationRepository: dependencies.organizationRepository,
      ),
    );
  }

  /// Show the batch transfer dialog for bulk transfer operations
  static Future<bool?> showBatch(
    BuildContext context, {
    required BatchTransferMode mode,
  }) {
    final dependencies = _readCoreDependencies(context);
    final repositories = context.safeReadAll(
      () => (
        context.read<OrganismRecordRepository>(),
        context.read<GenetRepository>(),
      ),
    );
    if (repositories == null) {
      _showLoadingSnackBar(
        context,
        message: 'Batch transfer tools are still loading. Please try again.',
      );
      return Future.value(null);
    }
    final (organismRecordRepository, genetRepository) = repositories;
    return DialogBase.showDialogWithProviders<bool>(
      context: context,
      barrierDismissible: false,
      providers: [
        RepositoryProvider<OrganismRecordRepository>.value(
          value: organismRecordRepository,
        ),
        RepositoryProvider<GenetRepository>.value(value: genetRepository),
        ..._coreProviders(dependencies),
      ],
      dialog: BlocProvider(
        create: (_) => BatchTransferCubit(
          mode: mode,
          transferService: dependencies.transferService,
          organismRecordRepository: organismRecordRepository,
          currentOrganization: dependencies.organization,
        ),
        child: const BatchTransferDialog(),
      ),
    );
  }

  /// Show the transfer dialog in edit mode for a pending transfer
  static Future<TransferEvent?> showForEdit(
    BuildContext context, {
    required TransferEvent originalEvent,
  }) {
    // Load genet name from repository if needed
    final genetRecordId = originalEvent.genetRecordId ?? '';
    final organismContext = _readOrganismContext(context);
    final dependencies = _readCoreDependencies(context);
    final repositories = context.safeReadAll(
      () => (
        context.read<OrganismRecordRepository>(),
        context.read<GroupRepository>(),
        context.read<SiteRepository>(),
      ),
    );
    if (repositories == null) {
      _showLoadingSnackBar(
        context,
        message: 'Transfer tools are still loading. Please try again.',
      );
      return Future.value(null);
    }
    final (organismRepository, groupRepository, siteRepository) = repositories;
    return DialogBase.showDialogWithProviders<TransferEvent>(
      context: context,
      barrierDismissible: false,
      providers: [
        RepositoryProvider<OrganismRecordRepository>.value(
          value: organismRepository,
        ),
        RepositoryProvider<GroupRepository>.value(value: groupRepository),
        RepositoryProvider<SiteRepository>.value(value: siteRepository),
        ..._coreProviders(dependencies),
      ],
      dialog: BlocProvider(
        create: (_) => TransferInitiateCubit(
          transferService: dependencies.transferService,
          organizationRepository: dependencies.organizationRepository,
          originalEvent: originalEvent,
        ),
        child: TransferDialog(
          mode: TransferDialogMode.initiate,
          genetName: genetRecordId,
          genetRecordId: genetRecordId,
          speciesId: '',
          originalEvent: originalEvent,
          organismContext: organismContext,
          initialProvenanceSelection:
              _selectionFromTransferEvent(originalEvent) ??
              _defaultProvenanceSelection(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (mode) {
      case TransferDialogMode.initiate:
        final requiredGenetName = genetName;
        final requiredGenetId = genetRecordId;
        final requiredSpeciesId = speciesId;
        if (requiredGenetName == null ||
            requiredGenetId == null ||
            requiredSpeciesId == null) {
          LoggingService.instance.warning(
            'TransferDialog: missing genetName/genetRecordId/speciesId for initiate mode.',
          );
          return const SizedBox.shrink();
        }
        return TransferInitiateDialog(
          genetName: requiredGenetName,
          genetRecordId: requiredGenetId,
          speciesId: requiredSpeciesId,
          organismContext: organismContext,
          holdingsLoaderOverride: holdingsLoaderOverride,
          holdingsSupportOverride: holdingsSupportOverride,
          holdingsRowsOverride: holdingsRowsOverride,
          initialProvenanceSelection:
              initialProvenanceSelection ?? _defaultProvenanceSelection(),
          originalEvent: originalEvent,
          allowLocalIdSelection: allowLocalIdSelection,
        );
      case TransferDialogMode.receive:
        return TransferReceiveDialog(
          organismContext: organismContext,
          initialManifest: initialManifest,
          holdingsLoaderOverride: holdingsLoaderOverride,
          holdingsSupportOverride: holdingsSupportOverride,
          holdingsRowsOverride: holdingsRowsOverride,
        );
      case TransferDialogMode.manualRegister:
        final requiredSpeciesIds = speciesIds;
        if (requiredSpeciesIds == null) {
          LoggingService.instance.warning(
            'TransferDialog: missing speciesIds for manual register mode.',
          );
          return const SizedBox.shrink();
        }
        return TransferManualRegisterDialog(
          speciesIds: requiredSpeciesIds,
          organismContext: organismContext,
          holdingsLoaderOverride: holdingsLoaderOverride,
          holdingsSupportOverride: holdingsSupportOverride,
          holdingsRowsOverride: holdingsRowsOverride,
          organizationRepository: organizationRepository,
        );
    }
  }
}

ProvenanceLifeStageSelection _defaultProvenanceSelection() =>
    ProvenanceLifeStageSelection.fallback();

ProvenanceLifeStageSelection? _selectionFromTransferEvent(TransferEvent event) {
  final manifestData = event.manifest;
  if (manifestData == null) return null;
  try {
    final manifest = TransferManifest.fromJson(manifestData);
    final sources = <Map<String, dynamic>>[];
    final genetMetadata = manifest.genet['metadata'];
    if (genetMetadata is Map<String, dynamic>) {
      sources.add(Map<String, dynamic>.from(genetMetadata));
    }
    if (manifest.metadata != null) {
      sources.add(Map<String, dynamic>.from(manifest.metadata!));
    }
    return ProvenanceLifeStageSelection.fromCanonicalSources(
      sources: sources,
      fallbackProvenanceKind: manifest.genet['provenanceKind']?.toString(),
    );
  } catch (_) {
    return null;
  }
}
