// @tier: community
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/constants/constants.dart';
import 'package:seafoundry_app/cubits/transfer/transfer_receive_cubit.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/models/transfer_manifest.dart';
import 'package:seafoundry_app/repositories/inventory/group_repository.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/repositories/inventory/site_repository.dart';
import 'package:seafoundry_app/repositories/organization_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/organism_holding_loader.dart';
import 'package:seafoundry_app/services/species_registry.dart';
import 'package:seafoundry_app/services/unique_name_validation_service.dart';
import 'package:seafoundry_app/widgets/dialogs/components/provenance_life_stage_selector.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';
import 'package:seafoundry_app/widgets/dialogs/components/transfer_manifest_summary.dart';
import 'package:seafoundry_app/widgets/inputs/organization_selector_field.dart';
import 'package:seafoundry_app/widgets/spreadsheet/safe_provider_mixin.dart';

import '../components/dialog_scroll_view.dart';

/// Dialog for receiving a transfer via QR/manifest
class TransferReceiveDialog extends StatefulWidget {
  const TransferReceiveDialog({
    super.key,
    required this.organismContext,
    this.initialManifest,
    this.holdingsLoaderOverride,
    this.holdingsSupportOverride,
    this.holdingsRowsOverride,
  });

  final OrganismContext organismContext;
  final TransferManifest? initialManifest;
  final OrganismHoldingLoader? holdingsLoaderOverride;
  final bool Function(OrganismKind kind)? holdingsSupportOverride;
  final Future<List<Map<String, dynamic>>> Function(OrganismKind kind)?
  holdingsRowsOverride;

  @override
  State<TransferReceiveDialog> createState() => _TransferReceiveDialogState();
}

/// Handles QR scanning, manual payload validation, and accept flows for the
/// receive dialog while delegating network work to [TransferReceiveCubit]. This
/// keeps the widget focused on UX wiring (scanner + text fields) and makes the
/// state machine observable for widget tests.
class _TransferReceiveDialogState extends State<TransferReceiveDialog>
    with SafeDialogMixin<TransferReceiveDialog> {
  /// Manual payload input (QR string).
  final TextEditingController _payloadController = TextEditingController();

  /// Suggested genet name for accepted transfers.
  final TextEditingController _genetNameController = TextEditingController();

  /// Optional local ID provided during acceptance.
  final TextEditingController _localIdController = TextEditingController();

  /// Optional ownership metadata for the received record.
  final TextEditingController _ownerOrgController = TextEditingController();
  final TextEditingController _managingOrgController = TextEditingController();

  late ProvenanceLifeStageSelection _provenanceSelection;
  String? _suggestedLocalId;
  String? _suggestedRecordName;
  String? _manifestDefaultName;
  String? _recordNameError;
  String? _localIdError;
  bool _checkingUnique = false;
  int _localIdRequestId = 0;
  int _recordNameRequestId = 0;
  UniqueNameValidationService? _validationService;

  List<Site> _availableSites = const [];
  List<Group> _availableGroups = const [];
  Site? _selectedSite;
  Group? _selectedGroup;
  bool _destinationLoading = false;
  String? _destinationError;

  bool get _hasDestinationSupport =>
      context.maybeRead<SiteRepository>() != null;

  bool get _allowScanner => widget.initialManifest == null;

  bool get _hasDestinationSelection =>
      _selectedSite != null &&
      (_availableGroups.isEmpty || _selectedGroup != null);

  bool get _canEnterScanningFlow =>
      _hasDestinationSupport &&
      !_destinationLoading &&
      _hasDestinationSelection;

  bool _isActiveNurserySite(Site site) {
    final metadata = site.metadata;
    if (metadata?['archived'] == true || metadata?['isDeleted'] == true) {
      return false;
    }
    return _nurserySiteTypeIds.contains(site.siteTypeId);
  }

  static final Set<String> _nurserySiteTypeIds = {
    SiteType.nursery.id,
  };

  @override
  void initState() {
    super.initState();
    _provenanceSelection = ProvenanceLifeStageSelection(
      provenanceType: ProvenanceType.wild,
      lifeStage: ProvenanceType.wild.defaultLifeStage,
    );
    _validationService = context.maybeRead<UniqueNameValidationService>();
    final organismRepository = context.maybeRead<OrganismRecordRepository>();
    if (_validationService == null && organismRepository != null) {
      _validationService = UniqueNameValidationService(
        firestore: organismRepository.db,
      );
    }
    final initialManifest = widget.initialManifest;
    if (initialManifest != null) {
      _seedManifestDefaults(initialManifest);
      context.read<TransferReceiveCubit>().setManifest(initialManifest);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDestinationSites();
      if (initialManifest != null) {
        _applyManifest(initialManifest, emitToCubit: false);
      }
    });
  }

  @override
  void dispose() {
    _payloadController.dispose();
    _genetNameController.dispose();
    _localIdController.dispose();
    _ownerOrgController.dispose();
    _managingOrgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TransferReceiveCubit, TransferReceiveState>(
      builder: (context, state) {
        final theme = Theme.of(context);
        final hasResult = state.createdGenet != null;
        final manifestReady = state.manifest != null && !hasResult;

        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.swap_horiz, color: Colors.blue),
              const SizedBox(width: 8),
              Text(hasResult ? 'Transfer Received' : 'Receive Transfer'),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: hasResult
                ? _buildSuccessBody(theme, state, state.createdGenet!)
                : _buildForm(theme, state),
          ),
          actions: _buildActions(state, manifestReady, hasResult),
        );
      },
    );
  }

  /// Builds context-sensitive actions for validation vs acceptance states.
  List<Widget> _buildActions(
    TransferReceiveState state,
    bool manifestReady,
    bool hasResult,
  ) {
    if (hasResult) {
      return [
        TextButton(
          onPressed: () => popDialog(state.createdGenet),
          child: const Text('Done'),
        ),
      ];
    }

    if (manifestReady) {
      final isBusy = state.validating || state.accepting || _checkingUnique;
      final canAccept =
          _hasDestinationSelection && !_destinationLoading && !isBusy;
      return [
        TextButton(
          onPressed: isBusy ? null : () => popDialog(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('transfer-receive-accept-button'),
          onPressed: canAccept ? _acceptTransfer : null,
          child: (state.accepting || _checkingUnique)
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Accept Transfer'),
        ),
      ];
    }

    final canValidate =
        _allowScanner &&
        _canEnterScanningFlow &&
        !state.validating &&
        _payloadController.text.trim().isNotEmpty;
    return [
      TextButton(
        onPressed: state.validating ? null : () => popDialog(),
        child: const Text('Close'),
      ),
      TextButton(
        onPressed: canValidate
            ? () => _handlePayload(_payloadController.text.trim())
            : null,
        child: const Text('Validate Manifest'),
      ),
    ];
  }

  /// Displays the scanner, manual payload input, manifest summary, and rename
  /// fields while guiding the user from validation to acceptance.
  Widget _buildForm(ThemeData theme, TransferReceiveState state) {
    final manifest = state.manifest;
    final errorMessage = state.errorMessage;
    final allowScanner = _allowScanner;
    final canScan = allowScanner && _canEnterScanningFlow;
    return DialogScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_hasDestinationSupport) ...[
            _buildDestinationSection(state),
          ] else ...[
            Text(
              'Destination selection is required before receiving this transfer. '
              'Please reopen this dialog after inventory finishes loading.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          if (_hasDestinationSupport &&
              (!_hasDestinationSelection || _destinationLoading)) ...[
            const SizedBox(height: 12),
            Text(
              _destinationLoading
                  ? 'Loading destination options...'
                  : 'Select a destination site'
                        '${_availableGroups.isNotEmpty ? ' and group' : ''} '
                        '${allowScanner ? 'to begin scanning.' : 'to continue.'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (canScan) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _payloadController,
              onChanged: (_) => setState(() {}),
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Manifest Payload',
                hintText: 'Paste QR payload contents',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: 'Paste from clipboard',
                  icon: const Icon(Icons.paste),
                  onPressed: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    final text = data?.text ?? '';
                    if (text.isNotEmpty) {
                      setState(() {
                        _payloadController.text = text.trim();
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('transfer-receive-validate-button'),
              onPressed:
                  state.validating || _payloadController.text.trim().isEmpty
                  ? null
                  : () => _handlePayload(_payloadController.text.trim()),
              icon: state.validating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle),
              label: const Text('Validate manifest'),
            ),
          ],
          if (errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              errorMessage,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          if (manifest != null) ...[
            const SizedBox(height: 20),
            TransferManifestSummary(manifest: manifest, showFullMetadata: true),
            const SizedBox(height: 16),
            ProvenanceLifeStageSelector(
              fieldKeyPrefix: 'transfer-receive',
              allowedProvenanceTypes: ProvenanceType.values,
              initialSelection: _provenanceSelection,
              provenanceLabel: 'Resulting Provenance Type',
              lifeStageLabel: 'Resulting Life Stage',
              helperText: 'Inherited from transfer manifest.',
              lifeStageHelperText: 'Inherited from transfer manifest.',
              enabled: false,
              onChanged: (selection) =>
                  setState(() => _provenanceSelection = selection),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _genetNameController,
              onChanged: (_) => _clearRecordNameError(),
              decoration: InputDecoration(
                labelText: 'Name in your system',
                helperText:
                    _suggestedRecordName == null ||
                        _suggestedRecordName!.isEmpty
                    ? null
                    : 'Suggested record name: $_suggestedRecordName',
                errorText: _recordNameError,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _localIdController,
              onChanged: (_) => _clearLocalIdError(),
              decoration: InputDecoration(
                labelText: 'Local ID (defaults to genet name)',
                helperText:
                    _suggestedLocalId == null || _suggestedLocalId!.isEmpty
                    ? null
                    : 'Suggested: $_suggestedLocalId',
                errorText: _localIdError,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Ownership & custody',
                style: theme.textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: 8),
            _OwnershipFields(
              ownerController: _ownerOrgController,
              managingController: _managingOrgController,
            ),
          ],
        ],
      ),
    );
  }

  /// Confirmation panel after `acceptTransfer` succeeds.
  Widget _buildSuccessBody(
    ThemeData theme,
    TransferReceiveState state,
    ProvenanceRecord record,
  ) {
    final aliases = record.aliasLabels;
    return DialogScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, size: 64, color: Colors.green),
          const SizedBox(height: 16),
          Text(
            'Transfer received successfully!',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          // Show crosswalk warning if provenance linking failed
          if (state.hasCrosswalkWarning) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange.shade800,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.crosswalkWarning!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(record.displayName, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Species: ${record.speciesId}',
            style: theme.textTheme.bodyMedium,
          ),
          if (record.id.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('ID: ${record.id}', style: theme.textTheme.bodySmall),
          ],
          if (aliases.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Aliases',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: aliases
                  .map((alias) => Chip(label: Text(alias)))
                  .toList(),
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            'You can now assign the genet to a structure or add additional metadata.',
          ),
        ],
      ),
    );
  }

  void _seedManifestDefaults(TransferManifest manifest) {
    final baseName =
        (manifest.genet['name'] as String?)?.trim() ?? 'Transferred genet';
    _manifestDefaultName = baseName;
    if (_genetNameController.text.trim().isEmpty) {
      _genetNameController.text = baseName;
    }
    _provenanceSelection = _deriveProvenanceSelection(manifest);
  }

  Future<void> _applyManifest(
    TransferManifest manifest, {
    bool emitToCubit = true,
  }) async {
    if (!mounted) return;
    if (emitToCubit) {
      context.read<TransferReceiveCubit>().setManifest(manifest);
    }
    final baseName =
        (manifest.genet['name'] as String?)?.trim() ?? 'Transferred genet';
    setState(() {
      _suggestedLocalId = null;
      _suggestedRecordName = null;
      _manifestDefaultName = baseName;
      _recordNameError = null;
      _localIdError = null;
      _provenanceSelection = _deriveProvenanceSelection(manifest);
    });
    if (_genetNameController.text.trim().isEmpty) {
      _genetNameController.text = baseName;
    }
    final suggestedLocalId = await _suggestNextLocalId(manifest);
    await _suggestRecordName(localId: suggestedLocalId);
  }

  /// Validates a QR/manifest payload via the cubit and hydrates the controllers.
  Future<void> _handlePayload(String payload) async {
    final trimmed = payload.trim();
    if (trimmed.isEmpty) return;
    if (!_canEnterScanningFlow) {
      if (_hasDestinationSupport) {
        setState(() {
          _destinationError = _destinationLoading
              ? 'Destination options are still loading.'
              : 'Please select a destination site'
                    '${_availableGroups.isNotEmpty ? ' and group' : ''}.';
        });
      } else {
        context.read<TransferReceiveCubit>().surfaceError(
          'Destination selection is required but unavailable. '
          'Please reopen this dialog after inventory finishes loading.',
        );
      }
      return;
    }

    final cubit = context.read<TransferReceiveCubit>();
    _payloadController.text = trimmed;
    if (!mounted) return;
    setState(() {
      _suggestedLocalId = null;
      _suggestedRecordName = null;
      _manifestDefaultName = null;
      _recordNameError = null;
      _localIdError = null;
    });
    await cubit.validatePayload(trimmed);
    final manifest = cubit.state.manifest;
    if (manifest != null) {
      await _applyManifest(manifest, emitToCubit: false);
    }
  }

  /// Calls the transfer service via the cubit to accept the manifest.
  Future<void> _acceptTransfer() async {
    final name = _genetNameController.text.trim();
    if (name.isEmpty) {
      context.read<TransferReceiveCubit>().surfaceError(
        'Genet name is required',
      );
      return;
    }
    final hasSiteRepo = context.maybeRead<SiteRepository>() != null;
    if (!hasSiteRepo) {
      context.read<TransferReceiveCubit>().surfaceError(
        'Destination selection is required but unavailable. '
        'Please try again after inventory finishes loading.',
      );
      return;
    }
    if (_selectedSite == null) {
      setState(() {
        _destinationError = 'Please select a destination site.';
      });
      return;
    }
    if (_availableGroups.isNotEmpty && _selectedGroup == null) {
      setState(() {
        _destinationError = 'Please select a destination group.';
      });
      return;
    }

    final localId = _localIdController.text.trim();
    final ownerOrgId = _ownerOrgController.text.trim();
    final managingOrgId = _managingOrgController.text.trim();
    final uniqueOk = await _validateUniqueFields(
      recordName: name,
      localId: localId,
    );
    if (!uniqueOk || !mounted) return;

    FocusScope.of(context).unfocus();
    await context.read<TransferReceiveCubit>().acceptTransfer(
      genetName: name,
      localId: localId.isEmpty ? name : localId,
      provenanceType: _provenanceSelection.provenanceType,
      lifeStage: _provenanceSelection.lifeStage,
      targetUrlPath: _selectedGroup?.urlPath ?? _selectedSite?.urlPath,
      destinationSiteId: _selectedGroup?.siteId ?? _selectedSite?.id,
      destinationGroupId: _selectedGroup?.id,
      ownerOrganizationId: ownerOrgId.isEmpty ? null : ownerOrgId,
      managingOrganizationId: managingOrgId.isEmpty ? null : managingOrgId,
    );
  }

  void _clearRecordNameError() {
    if (_recordNameError == null) return;
    setState(() => _recordNameError = null);
  }

  void _clearLocalIdError() {
    if (_localIdError == null) return;
    setState(() => _localIdError = null);
  }

  Future<bool> _validateUniqueFields({
    required String recordName,
    required String localId,
  }) async {
    final service = _validationService;
    final organization = context.maybeRead<Organization>();
    if (service == null || organization == null) {
      if (_recordNameError != null || _localIdError != null) {
        setState(() {
          _recordNameError = null;
          _localIdError = null;
        });
      }
      return true;
    }

    setState(() => _checkingUnique = true);

    String? localIdError;

    final resolvedLocalId = localId.isEmpty ? recordName : localId;
    try {
      final unique = await service.isGenetLocalIdUnique(
        localId: resolvedLocalId,
        organizationId: organization.id,
      );
      if (!unique) {
        localIdError =
            'Local ID "$resolvedLocalId" already exists. Choose a new ID.';
      }
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to validate local ID uniqueness',
        e,
        stackTrace,
      );
      localIdError =
          'Unable to validate local ID uniqueness. Please try again.';
    }

    if (!mounted) return false;
    setState(() {
      _checkingUnique = false;
      _recordNameError = null;
      _localIdError = localIdError;
    });
    return localIdError == null;
  }

  Future<String?> _suggestNextLocalId(TransferManifest manifest) async {
    final service = _validationService;
    final organization = context.maybeRead<Organization>();
    if (service == null || organization == null) return null;
    final manifestSpeciesId = manifest.genet['speciesId']?.toString().trim();
    final manifestSpeciesCode = manifest.genet['speciesCode']
        ?.toString()
        .trim();
    final resolvedSpecies = SpeciesRegistry.globalById(
      manifestSpeciesId ?? manifestSpeciesCode,
      allowFallback: false,
    );
    final speciesId = resolvedSpecies?.id ?? manifestSpeciesId;
    if (speciesId == null || speciesId.isEmpty) return null;
    final requestId = ++_localIdRequestId;
    try {
      final suggestion = await service.suggestNextOrganismLocalId(
        speciesId: speciesId,
        organizationId: organization.id,
      );
      if (!mounted || requestId != _localIdRequestId) {
        return null;
      }
      setState(() {
        _suggestedLocalId = suggestion;
        if (_localIdController.text.trim().isEmpty) {
          _localIdController.text = suggestion;
        }
      });
      return suggestion;
    } catch (e) {
      LoggingService.instance.debug('Failed to suggest local ID: $e');
    }
    return null;
  }

  Future<void> _suggestRecordName({String? localId}) async {
    final requestId = ++_recordNameRequestId;
    // Use localId as the simple fallback for record name suggestion
    final resolved = localId?.trim().isNotEmpty == true
        ? localId!.trim()
        : _localIdController.text.trim();
    if (!mounted || requestId != _recordNameRequestId) {
      return;
    }
    if (resolved.isEmpty) {
      return;
    }
    final currentName = _genetNameController.text.trim();
    final defaultName = _manifestDefaultName?.trim() ?? '';
    setState(() {
      _suggestedRecordName = resolved;
      if (currentName.isEmpty ||
          (defaultName.isNotEmpty && currentName == defaultName)) {
        _genetNameController.text = resolved;
      }
    });
  }

  Widget _buildDestinationSection(TransferReceiveState state) {
    final hasSiteRepo = context.maybeRead<SiteRepository>() != null;
    final hasGroupRepo = context.maybeRead<GroupRepository>() != null;
    if (!hasSiteRepo) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Destination',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (_destinationLoading) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(minHeight: 2),
        ],
        const SizedBox(height: 8),
        DropdownButtonFormField<Site>(
          initialValue: _selectedSite,
          items: _availableSites
              .map(
                (site) => DropdownMenuItem(value: site, child: Text(site.name)),
              )
              .toList(),
          onChanged: state.accepting
              ? null
              : (site) {
                  setState(() {
                    _selectedSite = site;
                    _selectedGroup = null;
                    _destinationError = null;
                  });
                  _loadDestinationGroups(site);
                },
          decoration: const InputDecoration(
            labelText: 'Site',
            border: OutlineInputBorder(),
          ),
        ),
        if (hasGroupRepo) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<Group>(
            initialValue: _selectedGroup,
            items: _availableGroups
                .map(
                  (group) =>
                      DropdownMenuItem(value: group, child: Text(group.name)),
                )
                .toList(),
            onChanged: state.accepting || _selectedSite == null
                ? null
                : (group) {
                    setState(() {
                      _selectedGroup = group;
                      _destinationError = null;
                    });
                  },
            decoration: const InputDecoration(
              labelText: 'Group',
              border: OutlineInputBorder(),
            ),
          ),
        ],
        if (_destinationError != null) ...[
          const SizedBox(height: 8),
          Text(
            _destinationError!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _loadDestinationSites() async {
    if (_destinationLoading) return;
    final siteRepository = context.maybeRead<SiteRepository>();
    if (siteRepository == null) return;
    setState(() {
      _destinationLoading = true;
      _destinationError = null;
    });
    try {
      final sites = await siteRepository.getAll().timeout(
        TransferTimeouts.siteLoad,
      );
      final filtered = sites.where(_isActiveNurserySite).toList();
      filtered.sort((a, b) => a.name.compareTo(b.name));
      if (!mounted) return;
      setState(() {
        _availableSites = filtered;
        if (_selectedSite != null &&
            !_availableSites.any((site) => site.id == _selectedSite!.id)) {
          _selectedSite = null;
          _selectedGroup = null;
          _availableGroups = const [];
        }
        _destinationLoading = false;
        if (_availableSites.isEmpty) {
          _destinationError = 'No nursery sites available for transfers.';
        }
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _destinationLoading = false;
        _destinationError = 'Loading sites timed out.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _destinationLoading = false;
        _destinationError = 'Failed to load destination sites.';
      });
    }
  }

  Future<void> _loadDestinationGroups(Site? site) async {
    if (_destinationLoading) return;
    final groupRepository = context.maybeRead<GroupRepository>();
    if (groupRepository == null) return;
    if (site == null) {
      setState(() {
        _availableGroups = const [];
      });
      return;
    }
    setState(() {
      _destinationLoading = true;
      _destinationError = null;
    });
    try {
      final groups = await groupRepository.getAll().timeout(
        TransferTimeouts.groupLoad,
      );
      final filtered = groups
          .where((group) => group.siteId == site.id)
          .toList();
      filtered.sort((a, b) => a.name.compareTo(b.name));
      if (!mounted) return;
      setState(() {
        _availableGroups = filtered;
        _destinationLoading = false;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _destinationLoading = false;
        _destinationError = 'Loading groups timed out.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _destinationLoading = false;
        _destinationError = 'Failed to load destination groups.';
      });
    }
  }

  ProvenanceLifeStageSelection _deriveProvenanceSelection(
    TransferManifest manifest,
  ) => ProvenanceLifeStageSelection.fromManifest(manifest);
}

class _OwnershipFields extends StatelessWidget {
  const _OwnershipFields({
    required this.ownerController,
    required this.managingController,
  });

  final TextEditingController ownerController;
  final TextEditingController managingController;

  @override
  Widget build(BuildContext context) {
    final organizationRepository = context.safeRead<OrganizationRepository>();

    if (organizationRepository == null) {
      return Column(
        children: [
          TextField(
            controller: ownerController,
            decoration: const InputDecoration(
              labelText: 'Owner organization id (optional)',
              hintText: 'e.g., AZA-Partner-001',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: managingController,
            decoration: const InputDecoration(
              labelText: 'Managing organization id (optional)',
              hintText: 'Custodial org for day-to-day care',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        OrganizationSelectorField(
          label: 'Owner organization (optional)',
          value: ownerController.text,
          onChanged: (value) => ownerController.text = value ?? '',
          organizationRepository: organizationRepository,
          hintText: 'e.g., AZA-Partner-001',
          helperText: 'Organization that owns this genet/record',
        ),
        const SizedBox(height: 12),
        OrganizationSelectorField(
          label: 'Managing organization (optional)',
          value: managingController.text,
          onChanged: (value) => managingController.text = value ?? '',
          organizationRepository: organizationRepository,
          hintText: 'Custodial org for day-to-day care',
          helperText: 'Organization responsible for daily care',
        ),
      ],
    );
  }
}
