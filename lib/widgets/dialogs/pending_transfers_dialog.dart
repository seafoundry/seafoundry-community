// @tier: community
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:seafoundry_app/cubits/navigation/navigation_cubit.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/models/transfer_manifest.dart';
import 'package:seafoundry_app/models/transfer_status.dart';
import 'package:seafoundry_app/repositories/inventory/group_repository.dart';
import 'package:seafoundry_app/repositories/inventory/organism_record_repository.dart';
import 'package:seafoundry_app/repositories/inventory/site_repository.dart';
import 'package:seafoundry_app/repositories/organization_repository.dart';
import 'package:seafoundry_app/repositories/record_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/organism_holding_loader.dart';
import 'package:seafoundry_app/services/species_registry.dart';
import 'package:seafoundry_app/services/transfer_service.dart';
import 'package:seafoundry_app/services/unique_name_validation_service.dart';
import 'package:seafoundry_app/utils/date_formatter.dart';
import 'package:seafoundry_app/utils/provenance_selection_utils.dart';
import 'package:seafoundry_app/widgets/common/alias_badges.dart';
import 'package:seafoundry_app/widgets/common/empty_state_widget.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';
import 'package:seafoundry_app/widgets/dialogs/pending_transfers/non_coral_pending_transfer_placeholder.dart';
import 'package:seafoundry_app/widgets/dialogs/transfer_dialog.dart';
import 'package:seafoundry_app/widgets/spreadsheet/safe_provider_mixin.dart';

/// Dialog for viewing and managing pending transfers (inbox/outbox). Requires
/// [TransferService] (for accept/reject calls) and an initialized
/// [RecordRepository] (for organization lookups) in the widget tree.
class PendingTransfersDialog extends StatefulWidget {
  PendingTransfersDialog({
    super.key,
    OrganismContext? organismContext,
    this.holdingsLoaderOverride,
    this.holdingsSupportOverride,
    this.holdingsRowsOverride,
  }) : organismContext =
           organismContext ?? OrganismContext.forKind(OrganismKind.coral);

  final OrganismContext organismContext;
  final OrganismHoldingLoader? holdingsLoaderOverride;
  final bool Function(OrganismKind kind)? holdingsSupportOverride;
  final Future<List<Map<String, dynamic>>> Function(OrganismKind kind)?
  holdingsRowsOverride;

  static Future<void> show(BuildContext context) async {
    final organismContext = _readOrganismContext(context);
    final loader = OrganismHoldingLoader.maybeFromContext(context);

    // Read required providers from parent context before showDialog
    // (showDialog creates a new overlay context that doesn't inherit providers)
    final transferService = context.maybeRead<TransferService>();
    final recordRepository = context.maybeRead<RecordRepository>();
    final organizationRepository = context.maybeRead<OrganizationRepository>();
    final organization = context.maybeRead<Organization>();
    final navigationCubit = context.maybeRead<NavigationCubit>();
    final organismRepository = context.maybeRead<OrganismRecordRepository>();
    final groupRepository = context.maybeRead<GroupRepository>();
    final siteRepository = context.maybeRead<SiteRepository>();
    final existingValidationService =
        context.maybeRead<UniqueNameValidationService>();
    final validationService = existingValidationService ??
        UniqueNameValidationService(
          firestore: organismRepository?.db ?? FirebaseFirestore.instance,
        );

    await showDialog(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (dialogContext) {
        Widget dialog = PendingTransfersDialog(
          organismContext: organismContext,
          holdingsLoaderOverride: loader,
          holdingsSupportOverride: loader == null
              ? null
              : (kind) => loader.supports(kind),
          holdingsRowsOverride: loader == null
              ? null
              : (kind) => loader.loadRows(kind),
        );

        final providers = <SingleChildWidget>[];
        if (transferService != null) {
          providers.add(
            Provider<TransferService>.value(value: transferService),
          );
        }
        if (organization != null) {
          providers.add(Provider<Organization>.value(value: organization));
        }
        if (navigationCubit != null) {
          providers.add(BlocProvider<NavigationCubit>.value(
            value: navigationCubit,
          ));
        }
        if (recordRepository != null) {
          providers.add(
            RepositoryProvider<RecordRepository>.value(value: recordRepository),
          );
        }
        if (organizationRepository != null) {
          providers.add(
            RepositoryProvider<OrganizationRepository>.value(
              value: organizationRepository,
            ),
          );
        }
        if (organismRepository != null) {
          providers.add(
            RepositoryProvider<OrganismRecordRepository>.value(
              value: organismRepository,
            ),
          );
        }
        providers.add(
          Provider<UniqueNameValidationService>.value(
            value: validationService,
          ),
        );
        if (groupRepository != null) {
          providers.add(
            RepositoryProvider<GroupRepository>.value(value: groupRepository),
          );
        }
        if (siteRepository != null) {
          providers.add(
            RepositoryProvider<SiteRepository>.value(value: siteRepository),
          );
        }
        if (providers.isNotEmpty) {
          dialog = MultiProvider(providers: providers, child: dialog);
        }

        return dialog;
      },
    );
  }

  static OrganismContext _readOrganismContext(BuildContext context) {
    return context.maybeRead<OrganismContext>() ??
        OrganismContext.forKind(OrganismKind.coral);
  }

  @override
  State<PendingTransfersDialog> createState() => _PendingTransfersDialogState();
}

class _PendingTransfersDialogState extends State<PendingTransfersDialog>
    with SafeDialogMixin<PendingTransfersDialog> {
  TransferService? _transferService;
  RecordRepository? _recordRepository;

  List<TransferEvent> _inboundTransfers = [];
  List<TransferEvent> _outboundTransfers = [];
  bool _isLoading = true;
  String? _error;
  String? _inboundError;
  String? _outboundError;
  bool _isProcessing = false;
  bool _hasInitialized = false;

  // Cache for organizations and genets
  final Map<String, Organization?> _organizationCache = {};
  final Map<String, ProvenanceRecord?> _genetCache = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasInitialized) {
      _hasInitialized = true;
      _initializeProviders();
    }
  }

  void _initializeProviders() {
    try {
      _transferService = context.read<TransferService>();
      _recordRepository = context.read<RecordRepository>();
      _loadTransfers();
    } on ProviderNotFoundException {
      setState(() {
        _isLoading = false;
        _error = 'Transfer service is not available in this view';
      });
    }
  }

  Future<void> _loadTransfers() async {
    if (!mounted || _transferService == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _inboundError = null;
      _outboundError = null;
    });

    try {
      final inboundTransfers = <TransferEvent>[];
      final outboundTransfers = <TransferEvent>[];
      String? inboundError;
      String? outboundError;

      try {
        inboundTransfers.addAll(await _transferService!.getPendingTransfers());
      } catch (e, stackTrace) {
        LoggingService.instance.error(
          'Failed to load inbound transfers',
          e,
          stackTrace,
        );
        inboundError = 'Failed to load inbound transfers: $e';
      }

      try {
        outboundTransfers.addAll(
          await _transferService!.getOutboundPendingTransfers(),
        );
      } catch (e, stackTrace) {
        LoggingService.instance.error(
          'Failed to load outbound transfers',
          e,
          stackTrace,
        );
        outboundError = 'Failed to load outbound transfers: $e';
      }

      if (!mounted) return;

      final cacheTasks = <Future<void>>[];
      for (final transfer in inboundTransfers) {
        cacheTasks.add(_ensureOrganizationCached(transfer.fromOrganizationId));
        cacheTasks.add(_ensureGenetCached(transfer));
      }
      for (final transfer in outboundTransfers) {
        cacheTasks.add(_ensureOrganizationCached(transfer.toOrganizationId));
        cacheTasks.add(_ensureGenetCached(transfer));
      }

      await Future.wait(cacheTasks);
      if (!mounted) return;

      setState(() {
        _inboundTransfers = inboundTransfers;
        _outboundTransfers = outboundTransfers;
        _inboundError = inboundError;
        _outboundError = outboundError;
        _isLoading = false;
      });

      LoggingService.instance.info(
        'Loaded ${inboundTransfers.length} inbound transfers and ${outboundTransfers.length} outbound transfers',
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to load transfers',
        e,
        stackTrace,
      );
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load transfers: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _acceptTransfer(TransferEvent transfer) async {
    final manifestData = transfer.manifest;
    if (manifestData == null) {
      _showSnackbar(
        'Transfer manifest is missing. Please ask the sender to reissue.',
        Colors.red,
      );
      return;
    }
    TransferManifest manifest;
    try {
      manifest = TransferManifest.fromJson(manifestData);
    } catch (e) {
      _showSnackbar(
        'Failed to parse transfer manifest. Please try again later.',
        Colors.red,
      );
      return;
    }

    final record = await TransferDialog.showReceive(
      context,
      initialManifest: manifest,
    );
    if (record == null || !mounted) {
      return;
    }
    await _loadTransfers();
    _showSnackbar('Transfer accepted successfully', Colors.green);
  }

  Future<void> _rejectTransfer(TransferEvent transfer) async {
    // Show confirmation dialog
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _RejectTransferDialog(
        transfer: transfer,
        genet: transfer.genetId != null ? _genetCache[transfer.genetId!] : null,
        fromOrganization: transfer.fromOrganizationId != null
            ? _organizationCache[transfer.fromOrganizationId!]
            : null,
      ),
    );

    if (reason == null) return;

    await _runWithProcessing(() async {
      await _transferService!.rejectTransfer(
        transferEventId: transfer.id,
        reason: reason.trim().isEmpty ? null : reason.trim(),
      );
      _showSnackbar('Transfer rejected', Colors.orange);
      await _loadTransfers();
    }, errorMessage: 'Failed to reject transfer');
  }

  @override
  Widget build(BuildContext context) {
    // Show non-coral placeholder for organisms other than coral
    if (widget.organismContext.kind != OrganismKind.coral) {
      return NonCoralPendingTransferPlaceholder(
        icon: Icons.swap_horiz,
        title: '${widget.organismContext.kind.metadata.displayName} Holdings',
        organismKind: widget.organismContext.kind,
        message:
            '${widget.organismContext.kind.metadata.displayName} transfer workflows are coming soon.',
        loaderOverride: widget.holdingsLoaderOverride,
        supportsOverride: widget.holdingsSupportOverride,
        loadRowsOverride: widget.holdingsRowsOverride,
      );
    }

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.swap_horiz, color: Colors.blue),
          const SizedBox(width: 8),
          const Text('Pending Transfers'),
          const Spacer(),
          if (_isLoading || _isProcessing)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
      content: SizedBox(
        width: 600,
        height: 500,
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              const TabBar(
                tabs: [
                  Tab(text: 'Inbox'),
                  Tab(text: 'Outbox'),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildInboxContent(),
                    _buildOutboxContent(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : popDialog,
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildInboxContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorState(_error!);
    }

    if (_inboundError != null) {
      return _buildErrorState(_inboundError!);
    }

    if (_inboundTransfers.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.check_circle_outline,
        title: 'No Pending Transfers',
        message:
            'You have no incoming genetic material transfers\nwaiting for approval.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_inboundTransfers.length} transfer${_inboundTransfers.length == 1 ? '' : 's'} awaiting approval',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: _inboundTransfers.length,
            itemBuilder: (context, index) {
              final transfer = _inboundTransfers[index];
              final organization = transfer.fromOrganizationId != null
                  ? _organizationCache[transfer.fromOrganizationId!]
                  : null;
              final genet = transfer.genetId != null
                  ? _genetCache[transfer.genetId!]
                  : null;

              return _TransferCard(
                transfer: transfer,
                genet: genet,
                counterpartyLabel: 'From',
                counterpartyName:
                    organization?.name ?? 'Unknown Organization',
                statusLabel: null,
                showActions: true,
                onAccept: _isProcessing
                    ? null
                    : () => _acceptTransfer(transfer),
                onReject: _isProcessing
                    ? null
                    : () => _rejectTransfer(transfer),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOutboxContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorState(_error!);
    }

    if (_outboundError != null) {
      return _buildErrorState(_outboundError!);
    }

    if (_outboundTransfers.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.outbox_outlined,
        title: 'No Pending Outbound Transfers',
        message:
            'You have no outgoing genetic material transfers\nwaiting for acceptance.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_outboundTransfers.length} outbound transfer${_outboundTransfers.length == 1 ? '' : 's'} awaiting acceptance',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: _outboundTransfers.length,
            itemBuilder: (context, index) {
              final transfer = _outboundTransfers[index];
              final organization = transfer.toOrganizationId != null
                  ? _organizationCache[transfer.toOrganizationId!]
                  : null;
              final genet = transfer.genetId != null
                  ? _genetCache[transfer.genetId!]
                  : null;
              final recipientName =
                  organization?.name ??
                  transfer.toOrganizationEmail ??
                  'Unknown Recipient';

              return _TransferCard(
                transfer: transfer,
                genet: genet,
                counterpartyLabel: 'To',
                counterpartyName: recipientName,
                statusLabel: _formatTransferStatus(transfer.status),
                showActions: false,
                actions: _buildOutboundActions(transfer),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Error Loading Transfers',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadTransfers,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  String _formatTransferStatus(String? status) {
    final trimmed = status?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return 'Unknown';
    }
    final normalized = trimmed.toLowerCase();
    return normalized.substring(0, 1).toUpperCase() + normalized.substring(1);
  }

  Future<void> _ensureOrganizationCached(String? organizationId) async {
    if (organizationId == null ||
        _organizationCache.containsKey(organizationId)) {
      return;
    }
    try {
      final org = await _recordRepository!.getRecord<Organization>(
        ModelType.organization,
        organizationId,
      );
      _organizationCache[organizationId] = org;
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to load organization $organizationId',
        e,
        stackTrace,
      );
      _organizationCache[organizationId] = null;
    }
  }

  Future<void> _ensureGenetCached(TransferEvent transfer) async {
    final genetId = transfer.genetId;
    if (genetId == null || _genetCache.containsKey(genetId)) {
      return;
    }
    try {
      // TransferService.getSourceGenet returns ProvenanceRecord?
      final genet = await _transferService!.getSourceGenet(transfer);
      if (mounted) {
        _genetCache[genetId] = genet;
      }
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to load genet $genetId for transfer ${transfer.id}',
        e,
        stackTrace,
      );
      _genetCache[genetId] = null;
    }
  }

  Future<void> _runWithProcessing(
    Future<void> Function() action, {
    required String errorMessage,
  }) async {
    if (!mounted) return;
    setState(() => _isProcessing = true);
    try {
      await action();
    } catch (e, stackTrace) {
      LoggingService.instance.error(errorMessage, e, stackTrace);
      _showSnackbar('$errorMessage: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showSnackbar(String message, Color color) {
    showDialogSnackBar(
      message,
      backgroundColor: color,
      isError: color == Colors.red,
      isSuccess: color == Colors.green,
    );
  }

  Widget? _buildOutboundActions(TransferEvent transfer) {
    final status = tryParseTransferStatus(transfer.status);
    final canEdit = status == TransferStatus.pending;
    final canCancel =
        status == TransferStatus.pending || status == TransferStatus.shipped;

    if (!canEdit && !canCancel) return null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (canEdit)
          TextButton.icon(
            onPressed: _isProcessing ? null : () => _editTransfer(transfer),
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('Edit'),
          ),
        if (canEdit && canCancel) const SizedBox(width: 8),
        if (canCancel)
          TextButton.icon(
            onPressed: _isProcessing ? null : () => _cancelTransfer(transfer),
            icon: const Icon(Icons.cancel, size: 18),
            label: const Text('Cancel'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
      ],
    );
  }

  Future<void> _editTransfer(TransferEvent transfer) async {
    final status = tryParseTransferStatus(transfer.status);
    if (status != TransferStatus.pending) {
      _showSnackbar('Only pending transfers can be edited.', Colors.orange);
      return;
    }

    final updatedTransfer = await TransferDialog.showForEdit(
      context,
      originalEvent: transfer,
    );

    if (updatedTransfer == null || !mounted) return;
    _showSnackbar('Transfer updated.', Colors.green);
    await _loadTransfers();
  }

  Future<void> _cancelTransfer(TransferEvent transfer) async {
    final recipientName = (transfer.toOrganizationId != null
        ? _organizationCache[transfer.toOrganizationId!]?.name
        : transfer.toOrganizationEmail) ??
        'Unknown Recipient';
    final genet = transfer.genetId != null
        ? _genetCache[transfer.genetId!]
        : null;
    final reason = await showDialog<String?>(
      context: context,
      builder: (context) => _CancelTransferDialog(
        transfer: transfer,
        genet: genet,
        recipientName: recipientName,
      ),
    );
    if (reason == null) return;

    await _runWithProcessing(() async {
      await _transferService!.cancelTransfer(
        transferEventId: transfer.id,
        reason: reason.trim().isEmpty ? null : reason.trim(),
      );
      _showSnackbar('Transfer cancelled.', Colors.orange);
      await _loadTransfers();
    }, errorMessage: 'Failed to cancel transfer');
  }
}

/// Card widget for displaying a transfer summary with action buttons.
class _TransferCard extends StatelessWidget {
  final TransferEvent transfer;
  final ProvenanceRecord? genet;
  final String counterpartyLabel;
  final String counterpartyName;
  final bool showActions;
  final String? statusLabel;
  final Widget? actions;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  const _TransferCard({
    required this.transfer,
    this.genet,
    required this.counterpartyLabel,
    required this.counterpartyName,
    this.showActions = true,
    this.statusLabel,
    this.actions,
    this.onAccept,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final species = genet != null
        ? SpeciesRegistry.globalById(genet!.speciesId)
        : null;
    final provenanceSelection = buildTransferProvenanceSelection(
      transfer: transfer,
      provenance: genet,
    );

    final actionWidget = actions ??
        (showActions
            ? Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: onAccept,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Accept'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              )
            : null);
    final hasActions = actionWidget != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.science, color: Colors.blue, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        genet?.displayName ?? 'Unknown Genet',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      _metadataWrap(
                        context: context,
                        species: species,
                        selection: provenanceSelection,
                        provenanceId: genet?.provenanceId,
                      ),
                      if ((genet?.aliasEntries ?? const []).isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: AliasBadges(
                            aliases: genet!.aliasEntries,
                            showPlaceholderWhenEmpty: false,
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Quantity: ${transfer.quantity}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      DateFormatter.formatChatTime(
                        DateTime.parse(transfer.createdAt),
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.business, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  '$counterpartyLabel: $counterpartyName',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            if (transfer.comment != null && transfer.comment!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.comment, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      transfer.comment!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
            if (statusLabel != null || hasActions) ...[
              const SizedBox(height: 16),
            ],
            if (statusLabel != null) ...[
              Row(
                children: [
                  const Icon(Icons.timelapse, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Status: $statusLabel',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ],
            if (hasActions) actionWidget,
          ],
        ),
      ),
    );
  }
}

Widget _metadataWrap({
  required BuildContext context,
  Species? species,
  required ProvenanceLifeStageSelection selection,
  String? provenanceId,
}) {
  final widgets = <Widget>[];
  void addBullet() {
    if (widgets.isNotEmpty) {
      widgets.add(const Text('•'));
    }
  }

  final textStyle = Theme.of(context).textTheme.bodySmall;

  if (species != null) {
    widgets.add(Text(species.name, style: textStyle));
  }
  addBullet();
  widgets.add(
    Text(selection.provenanceType.metadata.displayName, style: textStyle),
  );
  addBullet();
  widgets.add(Text(selection.lifeStage.displayName, style: textStyle));
  if (provenanceId != null) {
    addBullet();
    widgets.add(
      Text(
        provenanceId,
        style: textStyle?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  if (widgets.isEmpty) {
    return const SizedBox.shrink();
  }

  return Wrap(
    spacing: 8,
    runSpacing: 4,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: widgets,
  );
}

/// Dialog for rejecting a transfer
class _RejectTransferDialog extends StatefulWidget {
  final TransferEvent transfer;
  final ProvenanceRecord? genet;
  final Organization? fromOrganization;

  const _RejectTransferDialog({
    required this.transfer,
    required this.genet,
    required this.fromOrganization,
  });

  @override
  State<_RejectTransferDialog> createState() => _RejectTransferDialogState();
}

class _RejectTransferDialogState extends State<_RejectTransferDialog>
    with SafeDialogMixin<_RejectTransferDialog> {
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reject Transfer'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to reject this transfer?',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.transfer.quantity} × ${widget.genet?.displayName ?? 'Unknown Genet'}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'From: ${widget.fromOrganization?.name ?? 'Unknown'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if ((widget.genet?.aliasEntries ?? const []).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: AliasBadges(
                          aliases: widget.genet!.aliasEntries,
                          showPlaceholderWhenEmpty: false,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                helperText: 'Provide a reason for rejecting this transfer',
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => popDialog(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            popDialog(_reasonController.text.trim());
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Reject Transfer'),
        ),
      ],
    );
  }
}

class _CancelTransferDialog extends StatefulWidget {
  const _CancelTransferDialog({
    required this.transfer,
    required this.recipientName,
    this.genet,
  });

  final TransferEvent transfer;
  final ProvenanceRecord? genet;
  final String recipientName;

  @override
  State<_CancelTransferDialog> createState() => _CancelTransferDialogState();
}

class _CancelTransferDialogState extends State<_CancelTransferDialog>
    with SafeDialogMixin<_CancelTransferDialog> {
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cancel Transfer'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to cancel this transfer?',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.transfer.quantity} × ${widget.genet?.displayName ?? 'Unknown Genet'}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'To: ${widget.recipientName}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if ((widget.genet?.aliasEntries ?? const []).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: AliasBadges(
                          aliases: widget.genet!.aliasEntries,
                          showPlaceholderWhenEmpty: false,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                helperText: 'Add a note about why this transfer was cancelled',
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => popDialog(),
          child: const Text('Keep Transfer'),
        ),
        ElevatedButton(
          onPressed: () {
            popDialog(_reasonController.text.trim());
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Cancel Transfer'),
        ),
      ],
    );
  }
}
