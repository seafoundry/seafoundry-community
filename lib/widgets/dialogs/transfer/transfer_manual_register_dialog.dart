// @tier: community
import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../cubits/current_user/current_user.dart';
import '../../../cubits/transfer/transfer_manual_register_cubit.dart';
import '../../../cubits/transfer/transfer_manual_register_state.dart';
import '../../../forms/inputs/genet_form_inputs.dart';
import '../../../models/models.dart';
import '../../../models/provenance_search_state.dart';
import '../../../repositories/organization_repository.dart';
import '../../../services/clonal_id_display_service.dart';
import '../../../services/logging_service.dart';
import '../../../services/manual_transfer_registration_service.dart';
import '../../../services/organism_holding_loader.dart';
import '../../../services/provenance_lookup_service.dart';
import '../../../services/species_registry.dart';
import '../../../services/unique_name_validation_service.dart';
import '../../common/alias_editor.dart';
import '../../common/five_axis_editor.dart';
import '../../common/pid_status_chip.dart';
import '../../spreadsheet/safe_provider_mixin.dart';
import '../base_search_dialog.dart';
import '../components/five_axis_dialog_section.dart';
import '../components/safe_dialog_mixin.dart';
import '../../inputs/provenance_autocomplete_field.dart';
import '../../notifications/toast_overlay.dart';
import 'transfer_shared.dart';
import '../components/dialog_scroll_view.dart';

/// Dialog for manually registering a received genet
class TransferManualRegisterDialog extends StatefulWidget {
  final List<String> speciesIds;
  final OrganismContext organismContext;
  final OrganismHoldingLoader? holdingsLoaderOverride;
  final bool Function(OrganismKind kind)? holdingsSupportOverride;
  final Future<List<Map<String, dynamic>>> Function(OrganismKind kind)?
  holdingsRowsOverride;
  final OrganizationRepository? organizationRepository;
  const TransferManualRegisterDialog({
    super.key,
    required this.speciesIds,
    required this.organismContext,
    this.holdingsLoaderOverride,
    this.holdingsSupportOverride,
    this.holdingsRowsOverride,
    this.organizationRepository,
  });

  @override
  State<TransferManualRegisterDialog> createState() =>
      _TransferManualRegisterDialogState();
}

class _TransferManualRegisterDialogState
    extends State<TransferManualRegisterDialog>
    with SafeDialogMixin<TransferManualRegisterDialog> {
  /// New genet metadata captured from the manual workflow.
  final TextEditingController _name = TextEditingController();
  final TextEditingController _sourceOrg = TextEditingController();
  final TextEditingController _sourceEmail = TextEditingController();
  final TextEditingController _note = TextEditingController();
  final TextEditingController _ownerOrgId = TextEditingController();
  final TextEditingController _managingOrgId = TextEditingController();
  List<GenetAliasEntry> _aliases = const <GenetAliasEntry>[];
  Map<int, String?> _aliasErrors = const <int, String?>{};
  bool _aliasValidationTouched = false;
  bool _submitting = false;
  String? _speciesId;
  late final List<String> _availableSpeciesIds;
  String? _suggestedLocalId;
  int _localIdRequestId = 0;
  late ProvenanceLifeStageSelection _provenanceSelection;
  late String _selectedPhysicalFormId;
  SizeSpec _sizeSpec = const SizeSpec();
  late final TransferManualRegisterCubit _provenanceCubit;

  /// Internal form state to validate required fields before submission.
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    _availableSpeciesIds = _normalizeSpeciesIds(widget.speciesIds);
    if (_availableSpeciesIds.isNotEmpty) {
      _speciesId = _availableSpeciesIds.first;
    }
    _provenanceSelection = ProvenanceLifeStageSelection(
      provenanceType: ProvenanceType.wild,
      lifeStage: ProvenanceType.wild.defaultLifeStage,
    );
    _selectedPhysicalFormId = 'fragment';
    _provenanceCubit = TransferManualRegisterCubit(
      provenanceLookupService: context.maybeRead<ProvenanceLookupService>(),
      speciesId: _speciesId,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final speciesId = _speciesId;
      if (speciesId != null) {
        _suggestNextLocalId(speciesId);
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _sourceOrg.dispose();
    _sourceEmail.dispose();
    _note.dispose();
    _ownerOrgId.dispose();
    _managingOrgId.dispose();
    _provenanceCubit.close();
    super.dispose();
  }

  Future<void> _selectOrganizationFor(TextEditingController controller) async {
    final repository = widget.organizationRepository;
    if (repository == null) {
      LoggingService.instance.warning(
        'OrganizationRepository not available for organization search',
      );
      return;
    }
    final selected = await BaseSearchDialog.showSingle<Organization>(
      context,
      dialog: OrganizationSearchDialog(repository: repository),
    );
    if (selected == null) return;
    if (!mounted) return;
    setState(() {
      controller.text = selected.id;
    });
  }

  void _setAliases(List<GenetAliasEntry> updated) {
    setState(() {
      _aliases = updated;
      if (_aliasValidationTouched) {
        _aliasErrors = buildAliasErrorMap(updated);
      }
    });
  }

  void _onAliasAdded() {
    final updated = List<GenetAliasEntry>.from(_aliases)
      ..add(const GenetAliasEntry());
    _setAliases(updated);
  }

  void _onAliasValueChanged(int index, String value) {
    if (index < 0 || index >= _aliases.length) return;
    final updated = List<GenetAliasEntry>.from(_aliases);
    updated[index] = updated[index].copyWith(value: value);
    _setAliases(updated);
  }

  void _onAliasSourceChanged(int index, String source) {
    if (index < 0 || index >= _aliases.length) return;
    final updated = List<GenetAliasEntry>.from(_aliases);
    updated[index] = updated[index].copyWith(sourceSystem: source);
    _setAliases(updated);
  }

  void _onAliasRemoved(int index) {
    if (index < 0 || index >= _aliases.length) return;
    final updated = List<GenetAliasEntry>.from(_aliases)..removeAt(index);
    _setAliases(updated);
  }

  void _onAliasLabelChanged(int index, String label) {
    if (index < 0 || index >= _aliases.length) return;
    final updated = List<GenetAliasEntry>.from(_aliases);
    updated[index] = updated[index].copyWith(label: label);
    _setAliases(updated);
  }

  void _handleSpeciesChanged(String? speciesId) {
    setState(() {
      _speciesId = speciesId;
      _suggestedLocalId = null;
    });
    _provenanceCubit.setSpeciesId(speciesId);
    if (speciesId != null) {
      _suggestNextLocalId(speciesId);
    }
  }

  List<String> _normalizeSpeciesIds(Iterable<String> speciesIds) {
    final seen = <String>{};
    final normalized = <String>[];
    for (final rawId in speciesIds) {
      final resolved = SpeciesRegistry.normalizeId(rawId);
      if (resolved == null || resolved.isEmpty || !seen.add(resolved)) {
        continue;
      }
      normalized.add(resolved);
    }
    return normalized;
  }

  Future<void> _suggestNextLocalId(String speciesId) async {
    final currentUser = context.maybeRead<CurrentUser>();
    final currentState = currentUser?.state;
    if (currentState is! CurrentUserLoaded) return;

    final requestId = ++_localIdRequestId;
    try {
      final service = context.maybeRead<UniqueNameValidationService>();
      if (service == null) return;
      final suggestion = await service.suggestNextOrganismLocalId(
        speciesId: speciesId,
        organizationId: currentState.organization.id,
      );
      if (!mounted || requestId != _localIdRequestId) return;
      setState(() {
        _suggestedLocalId = suggestion;
      });
    } catch (e) {
      LoggingService.instance.debug('Failed to suggest local ID: $e');
    }
  }

  PopulationMeasurement get _measurement =>
      const PopulationMeasurement(value: 1, unit: MeasurementUnit.count);

  void _handleFiveAxisChanged(FiveAxisSelection selection) {
    setState(() {
      _provenanceSelection = selection.provenanceSelection;
      _selectedPhysicalFormId = selection.physicalFormSelection.physicalFormId;
      _sizeSpec = selection.physicalFormSelection.sizeSpec;
    });
  }

  Future<void> _registerGenet() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() {
        _autoValidateMode = AutovalidateMode.onUserInteraction;
      });
      return;
    }
    final aliasErrorsComputed = buildAliasErrorMap(_aliases);
    final hasAliasErrors = aliasErrorsComputed.values.any(
      (error) => error != null,
    );
    if (hasAliasErrors) {
      setState(() {
        _aliasValidationTouched = true;
        _aliasErrors = aliasErrorsComputed;
      });
      return;
    }
    if (!_aliasValidationTouched) {
      setState(() {
        _aliasValidationTouched = true;
        _aliasErrors = aliasErrorsComputed;
      });
    }

    FocusScope.of(context).unfocus();
    final service = context.read<ManualTransferRegistrationService>();
    final provenanceState = _provenanceCubit.state;
    final ownerId = _ownerOrgId.text.trim();
    final managerId = _managingOrgId.text.trim();
    final fromOrgId = _sourceOrg.text.trim();
    final sourceEmail = _sourceEmail.text.trim();
    final resolvedPid = provenanceState.provenanceSearch.resolvedProvenanceId;
    final manualPid = provenanceState.provenanceId?.trim();
    final sourceProvenanceId =
        (resolvedPid != null && resolvedPid.trim().isNotEmpty)
        ? resolvedPid.trim()
        : (manualPid != null && manualPid.isNotEmpty ? manualPid : null);
    final comment = _note.text.trim();
    final aliasPayload = _aliases
        .map((entry) => entry.toOrganismAlias())
        .where((alias) => alias.value.trim().isNotEmpty)
        .toList(growable: false);

    setState(() {
      _submitting = true;
    });

    try {
      final genet = await service.registerManualGenet(
        name: _name.text.trim(),
        speciesId: _speciesId!,
        provenanceType: _provenanceSelection.provenanceType,
        lifeStage: _provenanceSelection.lifeStage,
        organismKind: widget.organismContext.kind,
        physicalFormId: _selectedPhysicalFormId,
        sizeSpec: _sizeSpec,
        comment: comment.isEmpty ? null : comment,
        fromOrganizationId: fromOrgId.isEmpty ? null : fromOrgId,
        sourceContactEmail: sourceEmail.isEmpty ? null : sourceEmail,
        sourceProvenanceId: sourceProvenanceId,
        ownerOrganizationId: ownerId.isEmpty ? null : ownerId,
        managingOrganizationId: managerId.isEmpty ? null : managerId,
        aliases: aliasPayload,
      );
      if (!mounted) return;
      popDialog(genet);
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to register genet manually',
        e,
        stackTrace,
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
      });
      ToastOverlay.showSnackBar(
        context,
        SnackBar(content: Text('Failed to register genet: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final views = WidgetsBinding.instance.platformDispatcher.views;
    final viewInsets = views.isNotEmpty
        ? MediaQueryData.fromView(views.first).viewInsets
        : MediaQuery.of(context).viewInsets;
    final aliasErrors = _aliasValidationTouched
        ? _aliasErrors
        : const <int, String?>{};

    return BlocProvider.value(
      value: _provenanceCubit,
      child: BlocBuilder<TransferManualRegisterCubit, TransferManualRegisterState>(
        builder: (context, provenanceState) {
          final search = provenanceState.provenanceSearch;
          final activeField = search.activeField;
          final pidLocked = (provenanceState.provenanceId ?? '')
              .trim()
              .isNotEmpty;
          final hasResolvedPid = search.resolvedProvenanceId != null;
          final searchEnabled = _speciesId != null;

          return AlertDialog(
            title: const Text('Register Received Genet'),
            content: Form(
              key: _formKey,
              autovalidateMode: _autoValidateMode,
              child: DialogScrollView(
                padding: EdgeInsets.only(bottom: viewInsets.bottom),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      key: ValueKey('species-${_speciesId ?? 'none'}'),
                      initialValue: _speciesId,
                      items: _availableSpeciesIds.map((id) {
                        final sp =
                            SpeciesRegistry.globalById(id) ??
                            Species(id: id, genus: 'Unknown', species: '');
                        return DropdownMenuItem<String>(
                          value: id,
                          child: Text(sp.name.isEmpty ? id : sp.name),
                        );
                      }).toList(),
                      onChanged: _handleSpeciesChanged,
                      validator: (value) => (value == null || value.isEmpty)
                          ? 'Select a species'
                          : null,
                      decoration: const InputDecoration(labelText: 'Species *'),
                    ),
                    const SizedBox(height: 12),
                    FiveAxisDialogSection(
                      fieldKeyPrefix: 'manual-register',
                      organismKind: widget.organismContext.kind,
                      measurement: _measurement,
                      initialSelection: _provenanceSelection,
                      initialPhysicalFormId: _selectedPhysicalFormId,
                      initialSizeSpec: _sizeSpec,
                      allowedProvenanceTypes: const [
                        ProvenanceType.wild,
                        ProvenanceType.sexualCohort,
                        ProvenanceType.graduatedIndividual,
                        ProvenanceType.unknown,
                      ],
                      sizeClassOptions: const [
                        'Unknown',
                        'XS',
                        'S',
                        'M',
                        'L',
                        'XL',
                      ],
                      helpText:
                          'Capture provenance, life stage, physical form, and size so manifests and receiving orgs share canonical data.',
                      onChanged: _handleFiveAxisChanged,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _name,
                      decoration: InputDecoration(
                        labelText: 'New genet name *',
                        hintText: _suggestedLocalId ?? 'Required',
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'Enter a genet name'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _sourceOrg,
                      decoration: const InputDecoration(
                        labelText: 'Source organization id (optional)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _sourceEmail,
                      decoration: const InputDecoration(
                        labelText: 'Source contact email (optional)',
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        final trimmed = value?.trim() ?? '';
                        if (trimmed.isEmpty) {
                          return null;
                        }
                        final emailRegex = RegExp(
                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                        );
                        return emailRegex.hasMatch(trimmed)
                            ? null
                            : 'Enter a valid email';
                      },
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Source provenance search',
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (!searchEnabled)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Select a species to enable provenance search.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ExpansionTile(
                        key: const PageStorageKey('transfer_external_ids'),
                        initiallyExpanded: false,
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(top: 12),
                        title: Text(
                          'Select External Aliases & IDs',
                          style: theme.textTheme.titleSmall,
                        ),
                        children: [
                          ProvenanceAutocompleteField(
                            label: 'Provenance ID (PID)',
                            hintText: 'e.g., PID-APAL-0007',
                            icon: Icons.fingerprint,
                            value: provenanceState.provenanceId ?? '',
                            suggestions: search.provenanceIdSuggestions,
                            isSearching: search.isSearchingProvenanceId,
                            displayValueBuilder: (suggestion) =>
                                suggestion.provenanceId,
                            showOtherAliases: false,
                            enabled:
                                searchEnabled &&
                                !hasResolvedPid &&
                                (activeField == null ||
                                    activeField ==
                                        ProvenanceMatchField.provenanceId),
                            onTextChanged: context
                                .read<TransferManualRegisterCubit>()
                                .provenanceIdChanged,
                            onSuggestionSelected: (suggestion) {
                              context
                                  .read<TransferManualRegisterCubit>()
                                  .selectProvenanceSuggestion(
                                    suggestion,
                                    ProvenanceMatchField.provenanceId,
                                  );
                            },
                            onEditingComplete: () {
                              if ((provenanceState.provenanceId ?? '')
                                  .trim()
                                  .isNotEmpty) {
                                context
                                    .read<TransferManualRegisterCubit>()
                                    .setActiveProvenanceField(
                                      ProvenanceMatchField.provenanceId,
                                    );
                              }
                            },
                            onDisabledTap:
                                (hasResolvedPid ||
                                    (activeField != null &&
                                        activeField !=
                                            ProvenanceMatchField.provenanceId))
                                ? context
                                      .read<TransferManualRegisterCubit>()
                                      .clearProvenanceSelection
                                : null,
                          ),
                          const SizedBox(height: 12),
                          ProvenanceAutocompleteField(
                            label: 'Alias',
                            hintText: 'e.g., APAL-001',
                            icon: Icons.label_outline,
                            value: provenanceState.aliasId ?? '',
                            suggestions: search.aliasSuggestions,
                            isSearching: search.isSearchingAlias,
                            displayValueBuilder: (suggestion) =>
                                ClonalIdDisplayService.resolveAliasDisplay(
                                  suggestion,
                                ),
                            showOtherAliases: false,
                            enabled:
                                searchEnabled &&
                                !pidLocked &&
                                (activeField == null ||
                                    activeField == ProvenanceMatchField.alias),
                            onTextChanged: context
                                .read<TransferManualRegisterCubit>()
                                .aliasIdChanged,
                            onSuggestionSelected: (suggestion) {
                              context
                                  .read<TransferManualRegisterCubit>()
                                  .selectProvenanceSuggestion(
                                    suggestion,
                                    ProvenanceMatchField.alias,
                                  );
                            },
                            onEditingComplete: () {
                              if ((provenanceState.aliasId ?? '')
                                  .trim()
                                  .isNotEmpty) {
                                context
                                    .read<TransferManualRegisterCubit>()
                                    .setActiveProvenanceField(
                                      ProvenanceMatchField.alias,
                                    );
                              }
                            },
                            onDisabledTap:
                                (pidLocked ||
                                    (activeField != null &&
                                        activeField !=
                                            ProvenanceMatchField.alias))
                                ? context
                                      .read<TransferManualRegisterCubit>()
                                      .clearProvenanceSelection
                                : null,
                          ),
                          const SizedBox(height: 12),
                          ProvenanceAutocompleteField(
                            label: 'Clonal ID',
                            hintText: 'e.g., Apal-025',
                            icon: Icons.content_copy,
                            value: provenanceState.clonalId ?? '',
                            suggestions: search.clonalIdSuggestions,
                            isSearching: search.isSearchingClonalId,
                            enabled:
                                searchEnabled &&
                                !pidLocked &&
                                (activeField == null ||
                                    activeField ==
                                        ProvenanceMatchField.clonalId),
                            onTextChanged: context
                                .read<TransferManualRegisterCubit>()
                                .clonalIdChanged,
                            onSuggestionSelected: (suggestion) {
                              context
                                  .read<TransferManualRegisterCubit>()
                                  .selectProvenanceSuggestion(
                                    suggestion,
                                    ProvenanceMatchField.clonalId,
                                  );
                            },
                            onEditingComplete: () {
                              if ((provenanceState.clonalId ?? '')
                                  .trim()
                                  .isNotEmpty) {
                                context
                                    .read<TransferManualRegisterCubit>()
                                    .setActiveProvenanceField(
                                      ProvenanceMatchField.clonalId,
                                    );
                              }
                            },
                            onDisabledTap:
                                (pidLocked ||
                                    (activeField != null &&
                                        activeField !=
                                            ProvenanceMatchField.clonalId))
                                ? context
                                      .read<TransferManualRegisterCubit>()
                                      .clearProvenanceSelection
                                : null,
                          ),
                          const SizedBox(height: 12),
                          ProvenanceAutocompleteField(
                            label: 'Accession Number',
                            hintText: 'e.g., ACC-2024-001',
                            icon: Icons.confirmation_number,
                            value: provenanceState.accessionNumber ?? '',
                            suggestions: search.accessionSuggestions,
                            isSearching: search.isSearchingAccession,
                            displayValueBuilder: (suggestion) =>
                                ClonalIdDisplayService.resolveAliasDisplay(
                                  suggestion,
                                ),
                            showOtherAliases: false,
                            enabled:
                                searchEnabled &&
                                !pidLocked &&
                                (activeField == null ||
                                    activeField ==
                                        ProvenanceMatchField.accessionNumber),
                            onTextChanged: context
                                .read<TransferManualRegisterCubit>()
                                .accessionNumberChanged,
                            onSuggestionSelected: (suggestion) {
                              context
                                  .read<TransferManualRegisterCubit>()
                                  .selectProvenanceSuggestion(
                                    suggestion,
                                    ProvenanceMatchField.accessionNumber,
                                  );
                            },
                            onEditingComplete: () {
                              if ((provenanceState.accessionNumber ?? '')
                                  .trim()
                                  .isNotEmpty) {
                                context
                                    .read<TransferManualRegisterCubit>()
                                    .setActiveProvenanceField(
                                      ProvenanceMatchField.accessionNumber,
                                    );
                              }
                            },
                            onDisabledTap:
                                (pidLocked ||
                                    (activeField != null &&
                                        activeField !=
                                            ProvenanceMatchField
                                                .accessionNumber))
                                ? context
                                      .read<TransferManualRegisterCubit>()
                                      .clearProvenanceSelection
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    PidStatusChip(searchState: search),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _note,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Note (optional)',
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
                    TextFormField(
                      controller: _ownerOrgId,
                      decoration: InputDecoration(
                        labelText: 'Owner organization id (optional)',
                        suffixIcon: IconButton(
                          tooltip: 'Search organizations',
                          icon: const Icon(Icons.search),
                          onPressed: () => _selectOrganizationFor(_ownerOrgId),
                        ),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _managingOrgId,
                      decoration: InputDecoration(
                        labelText: 'Managing organization id (optional)',
                        suffixIcon: IconButton(
                          tooltip: 'Search organizations',
                          icon: const Icon(Icons.search),
                          onPressed: () =>
                              _selectOrganizationFor(_managingOrgId),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Aliases', style: theme.textTheme.titleSmall),
                    ),
                    const SizedBox(height: 8),
                    AliasEditorList(
                      aliases: _aliases,
                      errorMap: aliasErrors,
                      onAddAlias: _onAliasAdded,
                      onRemoveAlias: _onAliasRemoved,
                      onValueChanged: (index, value) =>
                          _onAliasValueChanged(index, value),
                      onSourceChanged: (index, source) =>
                          _onAliasSourceChanged(index, source),
                      onLabelChanged: (index, label) =>
                          _onAliasLabelChanged(index, label),
                      excludedSystems: kReservedAliasSystems,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => popDialog(null),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: _submitting ? null : _registerGenet,
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Register'),
              ),
            ],
          );
        },
      ),
    );
  }
}
