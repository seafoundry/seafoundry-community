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
import 'package:seafoundry_app/services/transfer_service.dart';
import 'package:seafoundry_app/services/unique_name_validation_service.dart';
import 'package:seafoundry_app/widgets/common/empty_state_widget.dart';
import 'package:seafoundry_app/widgets/dialogs/base/dialog_base.dart';
import 'package:seafoundry_app/widgets/dialogs/components/safe_dialog_mixin.dart';
import 'package:seafoundry_app/widgets/dialogs/pending_transfers_dialog_components.dart';
import 'package:seafoundry_app/widgets/dialogs/transfer_dialog.dart';
import 'package:seafoundry_app/widgets/spreadsheet/safe_provider_mixin.dart';

typedef _PendingTransfersDialogDependencies = ({
  TransferService? transferService,
  RecordRepository? recordRepository,
  OrganizationRepository? organizationRepository,
  Organization? organization,
  NavigationCubit? navigationCubit,
  OrganismRecordRepository? organismRepository,
  GroupRepository? groupRepository,
  SiteRepository? siteRepository,
  UniqueNameValidationService validationService,
});

/// Dialog for viewing and managing pending transfers (inbox/outbox). Requires
/// [TransferService] (for accept/reject calls) and an initialized
/// [RecordRepository] (for organization lookups) in the widget tree.
class PendingTransfersDialog extends StatefulWidget {
  PendingTransfersDialog({super.key, OrganismContext? organismContext})
    : organismContext =
          organismContext ?? OrganismContext.forKind(OrganismKind.coral);

  final OrganismContext organismContext;

  static Future<void> show(BuildContext context) async {
    final organismContext = _readOrganismContext(context);
    final dependencies = _readDialogDependencies(context);
    await DialogBase.showDialogWithProviders<void>(
      context: context,
      barrierDismissible: false,
      providers: _dialogProviders(dependencies),
      dialog: PendingTransfersDialog(organismContext: organismContext),
    );
  }

  static OrganismContext _readOrganismContext(BuildContext context) {
    return context.maybeRead<OrganismContext>() ??
        OrganismContext.forKind(OrganismKind.coral);
  }

  static _PendingTransfersDialogDependencies _readDialogDependencies(
    BuildContext context,
  ) {
    final organismRepository = context.maybeRead<OrganismRecordRepository>();
    final existingValidationService = context
        .maybeRead<UniqueNameValidationService>();
    final validationService =
        existingValidationService ??
        UniqueNameValidationService(
          firestore: organismRepository?.db ?? FirebaseFirestore.instance,
        );
    return (
      transferService: context.maybeRead<TransferService>(),
      recordRepository: context.maybeRead<RecordRepository>(),
      organizationRepository: context.maybeRead<OrganizationRepository>(),
      organization: context.maybeRead<Organization>(),
      navigationCubit: context.maybeRead<NavigationCubit>(),
      organismRepository: organismRepository,
      groupRepository: context.maybeRead<GroupRepository>(),
      siteRepository: context.maybeRead<SiteRepository>(),
      validationService: validationService,
    );
  }

  static List<SingleChildWidget> _dialogProviders(
    _PendingTransfersDialogDependencies dependencies,
  ) {
    final providers = <SingleChildWidget>[
      Provider<UniqueNameValidationService>.value(
        value: dependencies.validationService,
      ),
    ];
    if (dependencies.transferService != null) {
      providers.add(
        Provider<TransferService>.value(value: dependencies.transferService!),
      );
    }
    if (dependencies.organization != null) {
      providers.add(
        Provider<Organization>.value(value: dependencies.organization!),
      );
    }
    if (dependencies.navigationCubit != null) {
      providers.add(
        BlocProvider<NavigationCubit>.value(
          value: dependencies.navigationCubit!,
        ),
      );
    }
    if (dependencies.recordRepository != null) {
      providers.add(
        RepositoryProvider<RecordRepository>.value(
          value: dependencies.recordRepository!,
        ),
      );
    }
    if (dependencies.organizationRepository != null) {
      providers.add(
        RepositoryProvider<OrganizationRepository>.value(
          value: dependencies.organizationRepository!,
        ),
      );
    }
    if (dependencies.organismRepository != null) {
      providers.add(
        RepositoryProvider<OrganismRecordRepository>.value(
          value: dependencies.organismRepository!,
        ),
      );
    }
    if (dependencies.groupRepository != null) {
      providers.add(
        RepositoryProvider<GroupRepository>.value(
          value: dependencies.groupRepository!,
        ),
      );
    }
    if (dependencies.siteRepository != null) {
      providers.add(
        RepositoryProvider<SiteRepository>.value(
          value: dependencies.siteRepository!,
        ),
      );
    }
    return providers;
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
      LoggingService.instance.error('Failed to load transfers', e, stackTrace);
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
      builder: (context) => RejectTransferDialog(
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
                  children: [_buildInboxContent(), _buildOutboxContent()],
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

              return PendingTransferCard(
                transfer: transfer,
                genet: genet,
                counterpartyLabel: 'From',
                counterpartyName: organization?.name ?? 'Unknown Organization',
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

              return PendingTransferCard(
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
    final recipientName =
        (transfer.toOrganizationId != null
            ? _organizationCache[transfer.toOrganizationId!]?.name
            : transfer.toOrganizationEmail) ??
        'Unknown Recipient';
    final genet = transfer.genetId != null
        ? _genetCache[transfer.genetId!]
        : null;
    final reason = await showDialog<String?>(
      context: context,
      builder: (context) => CancelTransferDialog(
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
