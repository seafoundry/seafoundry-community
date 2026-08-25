import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_community/constants/constants.dart';
import 'package:seafoundry_community/cubits/outplant/organism_selection_cubit.dart';
import 'package:seafoundry_community/cubits/outplant/organism_selection_state.dart';
import 'package:seafoundry_community/cubits/transfer/transfer_initiate_cubit.dart';
import 'package:seafoundry_community/models/models.dart';
import 'package:seafoundry_community/repositories/inventory/group_repository.dart';
import 'package:seafoundry_community/repositories/inventory/genet_repository.dart';
import 'package:seafoundry_community/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_community/repositories/inventory/site_repository.dart';
import 'package:seafoundry_community/services/genet_id_resolver.dart';
import 'package:seafoundry_community/services/logging_service.dart';
import 'package:seafoundry_community/services/organism_holding_loader.dart';
import 'package:seafoundry_community/services/outplant/site_loading_service.dart';
import 'package:seafoundry_community/utils/human_sort.dart';
import 'package:seafoundry_community/widgets/common/five_axis_editor.dart';
import 'package:seafoundry_community/widgets/common/step_progress_indicator.dart';
import 'package:seafoundry_community/widgets/dialogs/base_async_dialog.dart';
import 'package:seafoundry_community/widgets/dialogs/base_search_dialog.dart';
import 'package:seafoundry_community/widgets/dialogs/components/transfer_initiate_form.dart';
import 'package:seafoundry_community/widgets/dialogs/components/transfer_manifest_summary.dart';
import 'package:seafoundry_community/widgets/dialogs/outplant_batch/outplant_coral_selection.dart';
import 'package:seafoundry_community/widgets/dialogs/transfer/transfer_shared.dart';
import 'package:seafoundry_community/widgets/spreadsheet/safe_provider_mixin.dart';

import '../../common/organism_reference_links.dart';
import '../components/dialog_scroll_view.dart';

/// Dialog for initiating a genet transfer to another organization
class TransferInitiateDialog extends BaseAsyncDialog {
  final String genetName;
  final String genetRecordId;
  final String speciesId;
  final TransferEvent? originalEvent; // For edit mode
  final OrganismContext organismContext;
  final OrganismHoldingLoader? holdingsLoaderOverride;
  final bool Function(OrganismKind kind)? holdingsSupportOverride;
  final Future<List<Map<String, dynamic>>> Function(OrganismKind kind)?
  holdingsRowsOverride;
  final ProvenanceLifeStageSelection initialProvenanceSelection;
  final bool allowLocalIdSelection;

  const TransferInitiateDialog({
    super.key,
    required this.genetName,
    required this.genetRecordId,
    required this.speciesId,
    this.originalEvent,
    required this.organismContext,
    this.holdingsLoaderOverride,
    this.holdingsSupportOverride,
    this.holdingsRowsOverride,
    required this.initialProvenanceSelection,
    this.allowLocalIdSelection = false,
  });

  @override
  State<TransferInitiateDialog> createState() => _TransferInitiateDialogState();
}

/// Hosts the initiate/edit workflow while deferring most business logic to
/// [TransferInitiateCubit]. Site loading is performed directly via
/// [SiteLoadingService] for responsive lazy-load UX.
class _TransferInitiateDialogState
    extends BaseAsyncDialogState<TransferInitiateDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _quantityController;
  late final TextEditingController _commentController;
  late final TextEditingController _recipientEmailController;
  late final TextEditingController _selectionSearchController;
  late final OrganismSelectionCubit _selectionCubit;
  final Map<String, TextEditingController> _selectionQuantityControllers = {};
  late String _selectedGenetId;
  late String _selectedGenetName;
  StreamSubscription<List<Genet>>? _genetSubscription;
  List<Genet> _availableGenets = const [];
  bool _genetLoading = false;
  String? _genetError;
  bool _selectionLoading = false;
  String? _selectionError;
  int _excludedPendingOutplant = 0;
  int _excludedPendingTransfer = 0;
  Map<String, String> _siteNameById = {};
  Map<String, String> _groupNameById = {};
  List<Site> _availableSites = const [];
  Site? _selectedSite;
  bool _siteLoading = false;
  String? _siteError;
  /// True when editing an existing pending transfer.
  late final bool _isEditMode;

  bool get _allowsLocalIdSelection =>
      widget.allowLocalIdSelection && !_isEditMode;

  bool get _hasSelectedLocalId =>
      !_allowsLocalIdSelection || _selectedGenetId.isNotEmpty;

  String get _genetDisplayName {
    if (_selectedGenetName.isNotEmpty) {
      return _selectedGenetName;
    }
    if (_selectedGenetId.isNotEmpty) {
      return _selectedGenetId;
    }
    return _allowsLocalIdSelection ? 'Select Local ID' : 'Unknown Genet';
  }

  /// Step labels for the multi-step transfer workflow
  static const List<String> _stepLabels = ['Selection'];

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.originalEvent != null;
    _selectedGenetId = widget.genetRecordId.trim();
    _selectedGenetName = widget.genetName.trim();
    _selectionCubit = OrganismSelectionCubit();
    _quantityController = TextEditingController(
      text: _isEditMode ? widget.originalEvent!.quantity.toString() : '',
    );
    _commentController = TextEditingController(
      text: _isEditMode ? widget.originalEvent!.comment ?? '' : '',
    );
    _recipientEmailController = TextEditingController(
      text: widget.originalEvent?.toOrganizationEmail ?? '',
    )..addListener(_onRecipientEmailChanged);
    _selectionSearchController = TextEditingController()
      ..addListener(_onSelectionSearchChanged);
    if (_allowsLocalIdSelection) {
      _startLocalIdStream();
    }
    if (!_isEditMode && widget.organismContext.kind == OrganismKind.coral) {
      _loadAvailableSites();
      if (!_allowsLocalIdSelection || _selectedGenetId.isNotEmpty) {
        _loadOrganismSelection();
      }
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _commentController.dispose();
    _recipientEmailController
      ..removeListener(_onRecipientEmailChanged)
      ..dispose();
    _selectionSearchController
      ..removeListener(_onSelectionSearchChanged)
      ..dispose();
    for (final controller in _selectionQuantityControllers.values) {
      controller.dispose();
    }
    _genetSubscription?.cancel();
    _selectionCubit.close();
    super.dispose();
  }

  PopulationMeasurement get _measurement =>
      const PopulationMeasurement(value: 1, unit: MeasurementUnit.count);

  @override
  String get title {
    // In edit mode, genet name may not be loaded yet, use genet ID as fallback
    final displayName = _genetDisplayName;
    final baseTitle = _isEditMode ? 'Edit Transfer' : 'Transfer';
    if (_allowsLocalIdSelection && !_hasSelectedLocalId) {
      return baseTitle;
    }
    return '$baseTitle $displayName';
  }

  @override
  Widget? get titleIcon => const Icon(Icons.swap_horiz, color: Colors.blue);

  @override
  double? get dialogWidth => 600;

  @override
  double? get dialogMaxHeight => 520;

  @override
  Widget buildContent(BuildContext context) {
    return BlocBuilder<TransferInitiateCubit, TransferInitiateState>(
      builder: (context, state) {
        if (state.hasTransfer) {
          return _buildSuccessContent(state);
        }
        return _buildTransferForm(state);
      },
    );
  }

  /// Renders the info banner plus the `TransferInitiateForm`.
  Widget _buildTransferForm(TransferInitiateState state) {
    return BlocBuilder<OrganismSelectionCubit, OrganismSelectionState>(
      bloc: _selectionCubit,
      builder: (context, selectionState) {
        final useSelection = !_isEditMode;
        return Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Transfer genetic material to another organization for collaborative research.',
                        style: TextStyle(color: Colors.blue[900], fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              StepProgressIndicator(
                steps: _stepLabels,
                currentStep: _getCurrentStep(state, selectionState),
              ),
              const SizedBox(height: 8),
              TransferInitiateForm(
                genetName: _genetDisplayName,
                localIdSelector:
                    _allowsLocalIdSelection ? _buildLocalIdSelector() : null,
                selectedOrganization: state.selectedOrganization,
                quantityController: _quantityController,
                commentController: _commentController,
                isSelectingOrganization: state.selectingOrganization,
                isBusy: isLoading,
                isEditMode: _isEditMode,
                onSelectOrganization: _selectOrganization,
                provenanceSelection: state.provenanceSelection,
                selectedPhysicalFormId: state.selectedPhysicalFormId,
                sizeSpec: state.sizeSpec,
                measurement: _measurement,
                isFiveAxisReadOnly: true,
                quantitySection: useSelection
                    ? _buildSelectionSection(selectionState)
                    : null,
                onFiveAxisChanged: (FiveAxisSelection selection) {
                  final cubit = context.read<TransferInitiateCubit>();
                  cubit.updateProvenanceSelection(selection.provenanceSelection);
                  cubit.updatePhysicalForm(
                    selection.physicalFormSelection.physicalFormId,
                  );
                  cubit.updateSizeSpec(selection.physicalFormSelection.sizeSpec);
                },
                recipientMode: state.recipientMode,
                onRecipientModeChanged: (mode) {
                  context.read<TransferInitiateCubit>().setRecipientMode(mode);
                },
                recipientEmailController: _recipientEmailController,
                recipientEmail: state.recipientEmail,
              ),
            ],
          ),
        );
      },
    );
  }

  void _startLocalIdStream() {
    if (_genetSubscription != null) return;
    final genetRepository = context.maybeRead<GenetRepository>();
    if (genetRepository == null) {
      _genetError = 'Local IDs unavailable';
      _genetLoading = false;
      return;
    }

    _genetLoading = true;
    _genetError = null;

    _genetSubscription = genetRepository.streamAll.listen(
      (genets) {
        if (!mounted) return;
        setState(() {
          _availableGenets = List<Genet>.from(genets);
          _genetLoading = false;
          _genetError = null;
        });
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _genetLoading = false;
          _genetError = 'Error loading Local IDs';
        });
      },
    );
  }

  Widget _buildLocalIdSelector() {
    if (_genetLoading) {
      return const SizedBox(
        height: 48,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_genetError != null) {
      return _buildLocalIdUnavailable(_genetError!);
    }

    final genets = List<Genet>.from(_availableGenets);
    if (genets.isEmpty) {
      return _buildLocalIdUnavailable('No Local IDs available');
    }

    genets.sort(
      (a, b) => compareHumanReadable(_genetLabel(a), _genetLabel(b)),
    );

    Genet? selected;
    for (final genet in genets) {
      if (genet.id == _selectedGenetId) {
        selected = genet;
        break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<Genet>(
          initialValue: selected,
          isExpanded: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Local ID',
            hintText: 'Select local ID',
            isDense: true,
          ),
          items: genets
              .map(
                (genet) => DropdownMenuItem(
                  value: genet,
                  child: Text(_genetLabel(genet)),
                ),
              )
              .toList(),
          onChanged: isLoading
              ? null
              : (genet) {
                  if (genet == null) return;
                  _onGenetSelected(genet);
                },
        ),
        if (_allowsLocalIdSelection && _selectedGenetId.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 6, left: 12),
            child: Text(
              'Required',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildLocalIdUnavailable(String message) {
    return InputDecorator(
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        labelText: 'Local ID',
        isDense: true,
      ),
      child: Text(
        message,
        style: const TextStyle(color: Colors.grey),
      ),
    );
  }

  String _genetLabel(Genet genet) {
    final localGenetId = genet.localGenetId?.trim();
    if (localGenetId != null && localGenetId.isNotEmpty) {
      return localGenetId;
    }
    final name = genet.name.trim();
    return name.isNotEmpty ? name : genet.id;
  }

  void _onGenetSelected(Genet genet) {
    if (genet.id == _selectedGenetId) return;
    setState(() {
      _selectedGenetId = genet.id;
      _selectedGenetName = _genetLabel(genet);
      _selectionError = null;
      _excludedPendingOutplant = 0;
      _excludedPendingTransfer = 0;
    });
    _resetSelectionControllers();
    _selectionCubit.clearSelection();
    _loadOrganismSelection();
    context
        .read<TransferInitiateCubit>()
        .updateProvenanceSelection(
          ProvenanceLifeStageSelection.fromGenet(genet),
        );
  }

  void _resetSelectionControllers() {
    for (final controller in _selectionQuantityControllers.values) {
      controller.dispose();
    }
    _selectionQuantityControllers.clear();
  }

  Widget _buildSelectionSection(OrganismSelectionState selectionState) {
    if (_allowsLocalIdSelection && _selectedGenetId.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quantity', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            'Select a Local ID above to load available organisms.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    }
    final filteredOrganisms = _filterOrganismsForSite(selectionState);
    final selectedQuantity = _selectedQuantity(selectionState);
    final selectedCount = selectionState.selectedOrganismIds.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quantity', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(
          'Select organism records and quantities to transfer.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        if (_selectionLoading)
          const LinearProgressIndicator()
        else if (_selectionError != null)
          Text(
            _selectionError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          )
        else if (selectionState.availableOrganisms.isEmpty)
          const Text('No organisms available for transfer.')
        else if (filteredOrganisms.isEmpty)
          const Text('No organisms match the current filters.'),
        if (!_selectionLoading &&
            _selectionError == null &&
            filteredOrganisms.isNotEmpty)
          _buildSelectionBody(selectionState, filteredOrganisms),
        const SizedBox(height: 8),
        if (selectedCount > 0)
          Text(
            'Selected: $selectedCount record${selectedCount == 1 ? '' : 's'}, '
            '$selectedQuantity total',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        if (!_selectionLoading &&
            _selectionError == null &&
            filteredOrganisms.isNotEmpty &&
            selectionState.selectedOrganismIds.isEmpty)
          Text(
            'Select at least one organism to continue.',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (selectionState.hasInvalidQuantities)
          Text(
            'One or more quantities are invalid.',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (_excludedPendingOutplant > 0 || _excludedPendingTransfer > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _buildExcludedSummary(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  Widget _buildSelectionBody(
    OrganismSelectionState selectionState,
    List<OrganismRecord> organisms,
  ) {
    if (organisms.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSiteFilter(),
        const SizedBox(height: 12),
        TextField(
          controller: _selectionSearchController,
          enabled: !isLoading,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Search organisms...',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 12),
        ..._buildOrganismRows(selectionState, organisms),
      ],
    );
  }

  List<Widget> _buildOrganismRows(
    OrganismSelectionState selectionState,
    List<OrganismRecord> organisms,
  ) {
    final sortedOrganisms = List<OrganismRecord>.from(organisms);
    sortedOrganisms.sort((a, b) {
      final locationCompare = _locationLabel(a).compareTo(_locationLabel(b));
      if (locationCompare != 0) return locationCompare;
      final aLabel = formatOrganismReferenceLabel(
        localGenetId: a.localGenetId,
        tagId: a.tagId,
        fallback: a.id,
      );
      final bLabel = formatOrganismReferenceLabel(
        localGenetId: b.localGenetId,
        tagId: b.tagId,
        fallback: b.id,
      );
      return aLabel.compareTo(bLabel);
    });

    final rows = <Widget>[];
    String? lastLocation;
    for (final organism in sortedOrganisms) {
      final location = _locationLabel(organism);
      if (location != lastLocation) {
        rows.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6, top: 8),
            child: Text(
              location,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        );
        lastLocation = location;
      }
      rows.add(_buildOrganismRow(selectionState, organism));
    }
    return rows;
  }

  Widget _buildOrganismRow(
    OrganismSelectionState selectionState,
    OrganismRecord organism,
  ) {
    final isSelected = selectionState.selectedOrganismIds.contains(organism.id);
    final available =
        organism.inventoryMetrics.count ?? organism.measurement.value.toInt();
    final controller = _selectionQuantityControllers.putIfAbsent(
      organism.id,
      () => TextEditingController(
        text: (selectionState.quantityByOrganism[organism.id] ?? 1).toString(),
      ),
    );
    final currentQuantity = selectionState.quantityByOrganism[organism.id] ?? 1;
    if (controller.text != currentQuantity.toString()) {
      controller.value = controller.value.copyWith(
        text: currentQuantity.toString(),
        selection: TextSelection.collapsed(
          offset: currentQuantity.toString().length,
        ),
      );
    }

    return OutplantOrganismSelectionRow(
      organism: organism,
      isSelected: isSelected,
      quantityController: controller,
      available: available,
      isSubmitting: isLoading,
      onSelectionChanged: (val) {
        _selectionCubit.toggleSelection(organism.id, selected: val);
      },
      onQuantityChanged: (value) {
        final parsed = int.tryParse(value) ?? 0;
        _selectionCubit.setQuantity(organism.id, parsed);
      },
    );
  }

  Widget _buildSiteFilter() {
    final sites = _availableSites;
    final items = <DropdownMenuItem<Site?>>[
      const DropdownMenuItem<Site?>(value: null, child: Text('All sites')),
      ...sites.map(
        (site) => DropdownMenuItem<Site?>(
          value: site,
          child: Text(site.name, overflow: TextOverflow.ellipsis),
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Source Site',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<Site?>(
          initialValue: _selectedSite,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Filter by site (optional)',
          ),
          items: items,
          onChanged: (isLoading || _siteLoading) ? null : _onSiteSelected,
        ),
        if (_siteLoading) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
        ],
        if (_siteError != null) ...[
          const SizedBox(height: 8),
          Text(
            _siteError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          TextButton.icon(
            onPressed: isLoading ? null : _loadAvailableSites,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ],
    );
  }

  List<OrganismRecord> _filterOrganismsForSite(
    OrganismSelectionState selectionState,
  ) {
    if (_selectedSite == null) {
      return selectionState.filteredOrganisms;
    }
    final selectedSiteId = _selectedSite!.id;
    return selectionState.filteredOrganisms
        .where((organism) {
          final siteId = organism.siteId;
          if (siteId == null || siteId.isEmpty || siteId == Missing.string) {
            return false;
          }
          return siteId == selectedSiteId;
        })
        .toList(growable: false);
  }

  int _selectedQuantity(OrganismSelectionState selectionState) {
    var total = 0;
    for (final id in selectionState.selectedOrganismIds) {
      total += selectionState.quantityByOrganism[id] ?? 0;
    }
    return total;
  }

  String _locationLabel(OrganismRecord organism) {
    final siteId = organism.siteId;
    final siteName = _siteNameById[siteId];
    final groupId = organism.groupId;
    final groupName = _groupNameById[groupId];
    String normalize(String? value) {
      if (value == null) return '';
      final trimmed = value.trim();
      if (trimmed.isEmpty || trimmed == Missing.string) return '';
      return trimmed;
    }

    final resolvedSite = normalize(siteName ?? siteId);
    final resolvedGroup = normalize(groupName ?? groupId);
    if (resolvedSite.isEmpty && resolvedGroup.isEmpty) {
      return 'Unknown Location';
    }
    if (resolvedGroup.isEmpty || resolvedGroup == resolvedSite) {
      return resolvedSite.isEmpty ? 'Unknown Location' : resolvedSite;
    }
    return resolvedSite.isEmpty
        ? resolvedGroup
        : '$resolvedSite / $resolvedGroup';
  }

  String _buildExcludedSummary() {
    final parts = <String>[];
    if (_excludedPendingOutplant > 0) {
      parts.add('$_excludedPendingOutplant pending outplant');
    }
    if (_excludedPendingTransfer > 0) {
      parts.add('$_excludedPendingTransfer pending transfer');
    }
    final joined = parts.join(', ');
    return 'Unavailable: $joined.';
  }

  /// Success view shown after initiating/updating a transfer.
  Widget _buildSuccessContent(TransferInitiateState state) {
    final transfer = state.transferEvent!;
    final manifest = state.manifest;
    final destinationName =
        state.selectedOrganization?.name ??
        manifest?.toOrganization['name'] as String? ??
        transfer.toOrganizationId ??
        'destination organization';

    return DialogScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 64, color: Colors.green),
          const SizedBox(height: 16),
          Text(
            'Transfer Initiated!',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Transfer request sent to $destinationName',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Transfer ID',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: Colors.green[900]),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  transfer.id,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Share this manifest with the receiving organization.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          if (manifest != null) ...[
            const SizedBox(height: 20),
            TransferManifestSummary(manifest: manifest),
          ],
        ],
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      BlocBuilder<TransferInitiateCubit, TransferInitiateState>(
        builder: (context, state) {
          if (state.hasTransfer) {
            String? manifestPayload;
            if (state.manifest != null) {
              try {
                manifestPayload = state.manifest!.encodePayload();
              } catch (_) {
                manifestPayload = null;
              }
            }
            if (manifestPayload == null || manifestPayload.isEmpty) {
              return const SizedBox.shrink();
            }
            return TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: manifestPayload!));
                if (!mounted) return;
                showSnackbar('Manifest payload copied to clipboard');
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy Payload'),
            );
          }
          return TextButton(
            onPressed: isLoading ? null : () => popDialog(false),
            child: const Text('Cancel'),
          );
        },
      ),
      BlocBuilder<OrganismSelectionCubit, OrganismSelectionState>(
        bloc: _selectionCubit,
        builder: (context, selectionState) {
          return BlocBuilder<TransferInitiateCubit, TransferInitiateState>(
            builder: (context, state) {
              if (state.hasTransfer) {
                return ElevatedButton(
                  onPressed: () => popDialog(true),
                  child: const Text('Done'),
                );
              }
              final selectionReady = _isEditMode
                  ? true
                  : selectionState.isValid;
              final hasSelectedLocalId = _hasSelectedLocalId;
              return ElevatedButton.icon(
                onPressed:
                    isLoading ||
                        !state.hasValidRecipient ||
                        _isSelfRecipient(state) ||
                        !selectionReady ||
                        !hasSelectedLocalId
                    ? null
                    : _performTransfer,
                icon: Icon(_isEditMode ? Icons.save : Icons.send),
                label: Text(
                  _isEditMode ? 'Update Transfer' : 'Initiate Transfer',
                ),
              );
            },
          );
        },
      ),
    ];
  }

  /// Opens the organization search dialog and persists the selection.
  Future<void> _selectOrganization() async {
    final cubit = context.read<TransferInitiateCubit>();
    final isSelecting = cubit.state.selectingOrganization;
    if (isLoading || isSelecting) {
      return;
    }
    cubit.setSelectingOrganization(true);

    try {
      // Get current organization to exclude from search results
      final currentOrgId = context.read<Organization>().id;

      final selected = await BaseSearchDialog.showSingle<Organization>(
        context,
        dialog: OrganizationSearchDialog(
          repository: cubit.organizationRepository,
          excludeOrganizationId: currentOrgId,
        ),
      );

      if (selected != null) {
        if (selected.id == currentOrgId) {
          showSnackbar('Select a different organization for this transfer.');
          return;
        }
        cubit.setSelectedOrganization(selected);
      }
    } finally {
      cubit.setSelectingOrganization(false);
    }
  }

  /// Validates the form before invoking [performAsyncOperation].
  Future<void> _performTransfer() async {
    final formState = _formKey.currentState;
    if (formState == null) {
      showSnackbar('Form not ready. Please try again.');
      return;
    }
    if (!formState.validate()) return;
    if (!_hasSelectedLocalId) {
      showSnackbar('Select a Local ID to transfer');
      return;
    }
    final cubit = context.read<TransferInitiateCubit>();
    final currentState = cubit.state;
    if (!currentState.hasValidRecipient) {
      final message = currentState.recipientMode == RecipientMode.organization
          ? 'Select a destination organization'
          : 'Enter a valid recipient email address';
      showSnackbar(message);
      return;
    }
    if (currentState.recipientMode == RecipientMode.organization) {
      final currentOrgId = context.read<Organization>().id;
      final selectedOrgId = currentState.selectedOrganization?.id;
      if (selectedOrgId != null && selectedOrgId == currentOrgId) {
        showSnackbar('Select a different organization for this transfer.');
        return;
      }
    }

    final selectionState = _selectionCubit.state;
    final quantity = _resolveTransferQuantity(selectionState);
    if (quantity == null) return;
    final inventorySelection = _buildInventorySelection(selectionState);

    setLoading(true);
    try {
      final transfer = await cubit.submitTransfer(
        genetRecordId: _selectedGenetId,
        quantity: quantity,
        comment: _commentController.text.trim(),
        provenanceSelection: currentState.provenanceSelection,
        physicalFormId: currentState.selectedPhysicalFormId,
        sizeSpec: currentState.sizeSpec,
        geometryInput: currentState.geometryInput,
        inventorySelection: inventorySelection,
      );
      if (_isEditMode) {
        if (!mounted) return;
        popDialog(transfer);
        showSnackbar('Transfer updated successfully');
      } else {
        showSnackbar('Transfer initiated successfully');
      }
    } catch (e) {
      onError(e);
    } finally {
      setLoading(false);
    }
  }

  bool _isSelfRecipient(TransferInitiateState state) {
    if (state.recipientMode != RecipientMode.organization) {
      return false;
    }
    final currentOrgId = context.read<Organization>().id;
    return state.selectedOrganization?.id == currentOrgId;
  }

  /// Parses the quantity field (edit mode) and surfaces validation feedback.
  int? _parseQuantity() {
    final trimmed = _quantityController.text.trim();
    final parsed = int.tryParse(trimmed);
    if (parsed == null || parsed <= 0) {
      showSnackbar('Enter a valid quantity greater than zero');
      return null;
    }
    return parsed;
  }

  int? _resolveTransferQuantity(OrganismSelectionState selectionState) {
    if (_isEditMode) {
      return _parseQuantity();
    }
    if (selectionState.selectedOrganismIds.isEmpty) {
      showSnackbar('Select at least one organism to transfer');
      return null;
    }
    if (selectionState.hasInvalidQuantities) {
      showSnackbar('One or more quantities are invalid');
      return null;
    }
    final total = _selectedQuantity(selectionState);
    if (total <= 0) {
      showSnackbar('Enter a valid quantity greater than zero');
      return null;
    }
    return total;
  }

  Map<String, int>? _buildInventorySelection(
    OrganismSelectionState selectionState,
  ) {
    if (_isEditMode) return null;
    if (selectionState.selectedOrganismIds.isEmpty) {
      return null;
    }
    final selection = <String, int>{};
    for (final id in selectionState.selectedOrganismIds) {
      final quantity = selectionState.quantityByOrganism[id] ?? 0;
      if (quantity > 0) {
        selection[id] = quantity;
      }
    }
    return selection.isEmpty ? null : selection;
  }

  void _onRecipientEmailChanged() {
    context.read<TransferInitiateCubit>().setRecipientEmail(
      _recipientEmailController.text,
    );
  }

  void _onSelectionSearchChanged() {
    _selectionCubit.setSearchQuery(_selectionSearchController.text);
  }

  void _onSiteSelected(Site? site) {
    setState(() {
      _selectedSite = site;
    });
    _selectionCubit.clearSelection();
  }

  Future<void> _loadAvailableSites() async {
    if (_siteLoading) return;
    setState(() {
      _siteLoading = true;
      _siteError = null;
    });

    try {
      final siteRepository = context.read<SiteRepository>();
      final loader = SiteLoadingService(
        siteRepository: siteRepository,
        logger: LoggingService.instance,
      );
      final sites = List<Site>.from(await loader.loadSites())
          .where(_isActiveNurserySite)
          .toList(growable: false);
      sites.sort((a, b) => a.name.compareTo(b.name));
      if (!mounted) return;

      final currentSelectionId = _selectedSite?.id;
      Site? resolvedSelection;
      if (currentSelectionId != null) {
        for (final site in sites) {
          if (site.id == currentSelectionId) {
            resolvedSelection = site;
            break;
          }
        }
      }

      resolvedSelection ??= _resolveSiteFromSourcePath(sites);

      setState(() {
        _availableSites = sites;
        _selectedSite = resolvedSelection;
        _siteLoading = false;
        _siteNameById = {for (final site in sites) site.id: site.name};
      });
    } catch (error, stackTrace) {
      LoggingService.instance.warning(
        'Failed to load sites for transfer selection',
        {'error': error.toString(), 'stackTrace': stackTrace.toString()},
      );
      if (!mounted) return;
      setState(() {
        _siteLoading = false;
        _siteError = 'Failed to load sites. Please try again.';
      });
    }
  }

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

  Future<void> _loadOrganismSelection() async {
    if (_selectionLoading) return;
    if (_allowsLocalIdSelection && _selectedGenetId.isEmpty) {
      _selectionCubit.loadOrganisms(const []);
      if (!mounted) return;
      setState(() {
        _selectionLoading = false;
        _selectionError = null;
        _excludedPendingOutplant = 0;
        _excludedPendingTransfer = 0;
      });
      return;
    }
    setState(() {
      _selectionLoading = true;
      _selectionError = null;
    });

    try {
      final sourceStructureUrlPath = context
          .read<TransferInitiateCubit>()
          .sourceStructureUrlPath;
      final organisms = await _loadOrganismsForSelection();
      final filtered = <OrganismRecord>[];
      var pendingOutplantExcluded = 0;
      var pendingTransferExcluded = 0;

      for (final organism in organisms) {
        if (!_matchesGenet(organism)) {
          continue;
        }
        if (sourceStructureUrlPath != null &&
            sourceStructureUrlPath.isNotEmpty &&
            !organism.urlPath.startsWith(sourceStructureUrlPath)) {
          continue;
        }
        final metadata = organism.metadata;
        if (metadata != null) {
          if (metadata['pendingOutplant'] == true) {
            pendingOutplantExcluded += 1;
            continue;
          }
          final pendingTransferId = metadata['pendingTransferId'];
          if (pendingTransferId is String && pendingTransferId.isNotEmpty) {
            pendingTransferExcluded += 1;
            continue;
          }
        }
        final available =
            organism.inventoryMetrics.count ??
            organism.measurement.value.toInt();
        if (available <= 0) {
          continue;
        }
        filtered.add(organism);
      }

      if (!mounted) return;

      setState(() {
        _selectionLoading = false;
        _excludedPendingOutplant = pendingOutplantExcluded;
        _excludedPendingTransfer = pendingTransferExcluded;
      });
      _selectionCubit.loadOrganisms(filtered);

      unawaited(_loadGroupNames());
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _selectionLoading = false;
        _selectionError = 'Loading organisms timed out. Please try again.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _selectionLoading = false;
        _selectionError = 'Failed to load organisms: $error';
      });
    }
  }

  Future<void> _loadGroupNames() async {
    final groupRepository = context.read<GroupRepository>();
    try {
      final groups = await groupRepository.getAll().timeout(
        TransferTimeouts.groupLoad,
      );
      if (!mounted) return;
      setState(() {
        _groupNameById = {for (final group in groups) group.id: group.name};
      });
    } catch (error, stackTrace) {
      LoggingService.instance.warning(
        'Failed to load group names for transfer selection',
        {'error': error.toString(), 'stackTrace': stackTrace.toString()},
      );
    }
  }

  Future<List<OrganismRecord>> _loadOrganismsForSelection() async {
    final organismRepository = context.read<OrganismRecordRepository>();
    var sawTimeout = false;
    var sawError = false;
    try {
      final organisms = await organismRepository.getAll().timeout(
        TransferTimeouts.selectionLoad,
      );
      return organisms
          .where(
            (organism) => organism.organismKind == widget.organismContext.kind,
          )
          .toList(growable: false);
    } on TimeoutException catch (error, stackTrace) {
      sawTimeout = true;
      LoggingService.instance.warning(
        'Organism selection load timed out via getAll',
        {'error': error.toString(), 'stackTrace': stackTrace.toString()},
      );
    } catch (error, stackTrace) {
      sawError = true;
      LoggingService.instance.warning(
        'Failed to load organisms via getAll; falling back to stream',
        {'error': error.toString(), 'stackTrace': stackTrace.toString()},
      );
    }

    try {
      // Use firstWhere with orElse to avoid indefinite waiting if stream
      // only emits empty lists. The timeout provides an additional safeguard.
      return await organismRepository
          .streamByOrganism(widget.organismContext.kind)
          .timeout(TransferTimeouts.streamFallback)
          .firstWhere(
            (records) => records.isNotEmpty,
            orElse: () => <OrganismRecord>[],
          );
    } on TimeoutException catch (error, stackTrace) {
      sawTimeout = true;
      LoggingService.instance.warning(
        'Organism selection stream fallback timed out',
        {'error': error.toString(), 'stackTrace': stackTrace.toString()},
      );
    } catch (error, stackTrace) {
      sawError = true;
      LoggingService.instance.warning(
        'Failed to load organisms from stream fallback',
        {'error': error.toString(), 'stackTrace': stackTrace.toString()},
      );
    }

    if (sawTimeout) {
      throw TimeoutException('Organism selection load timed out');
    }
    if (sawError) {
      throw StateError('Organism selection load failed');
    }
    return const <OrganismRecord>[];
  }

  Site? _resolveSiteFromSourcePath(List<Site> sites) {
    final sourcePath = context
        .read<TransferInitiateCubit>()
        .sourceStructureUrlPath;
    if (sourcePath == null || sourcePath.isEmpty) {
      return null;
    }
    for (final site in sites) {
      if (sourcePath.startsWith(site.urlPath)) {
        return site;
      }
    }
    return null;
  }

  bool _matchesGenet(OrganismRecord organism) {
    final genetRecordId = _selectedGenetId;
    if (genetRecordId.isEmpty) {
      return !_allowsLocalIdSelection;
    }

    final resolved = GenetIdResolver.resolve(organism);
    return resolved == genetRecordId;
  }

  /// Determines the current step based on form completion state.
  /// Step 0: Selection (recipient + quantity)
  int _getCurrentStep(
    TransferInitiateState state,
    OrganismSelectionState selectionState,
  ) {
    if (_allowsLocalIdSelection && _selectedGenetId.isEmpty) {
      return 0;
    }
    if (!state.hasValidRecipient) {
      return 0;
    }
    if (_isEditMode) {
      final quantity = double.tryParse(_quantityController.text.trim());
      if (quantity == null || quantity <= 0) {
        return 0;
      }
    } else if (!selectionState.isValid) {
      return 0;
    }
    return 0;
  }

  @override
  Future<void> performAsyncOperation(BuildContext context) async {
    // Custom actions call [_performTransfer] directly; the base dialog buttons
    // are not used in this implementation.
  }
}