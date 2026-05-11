import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/transfer/batch_transfer_enums.dart';
import 'package:seafoundry_app/cubits/transfer_count/transfer_count_cubit.dart';
import 'package:seafoundry_app/cubits/transfer_count/transfer_count_state.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/repositories/inventory/event_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/species_registry.dart';
import 'package:seafoundry_app/widgets/dialogs/pending_transfers_dialog.dart';
import 'package:seafoundry_app/widgets/dialogs/transfer_dialog.dart';
import 'package:seafoundry_app/widgets/spreadsheet/safe_provider_mixin.dart';

class GeneticsTransferCoordinator {
  const GeneticsTransferCoordinator._();

  static Future<GeneticsTransferOutcome> receiveTransfer({
    required BuildContext context,
    OrganismKind? organismKind,
    List<String>? speciesIds,
  }) async {
    try {
      final resolvedKind =
          organismKind ?? context.maybeRead<OrganismContext>()?.kind ??
          OrganismKind.coral;
      final resolvedSpeciesIds = _resolveSpeciesIds(
        context,
        speciesIds,
      );
      final manualEnabled =
          resolvedKind == OrganismKind.coral && resolvedSpeciesIds.isNotEmpty;

      if (manualEnabled) {
        final mode = await _promptTransferReceiveMode(context);
        if (mode == null) {
          return const GeneticsTransferOutcome.cancelled();
        }
        if (!context.mounted) {
          return const GeneticsTransferOutcome.cancelled();
        }
        if (mode == _TransferReceiveMode.pending) {
          await PendingTransfersDialog.show(context);
          return const GeneticsTransferOutcome.cancelled();
        }
        if (mode == _TransferReceiveMode.manual) {
          final record = await TransferDialog.showManualRegister(
            context,
            speciesIds: resolvedSpeciesIds,
          );
          if (record == null || !context.mounted) {
            return const GeneticsTransferOutcome.cancelled();
          }
          return GeneticsTransferOutcome.success(
            message: 'Registered ${record.displayName}',
            record: record,
          );
        }
      }

      final record = await TransferDialog.showReceive(context);
      if (record == null) {
        return const GeneticsTransferOutcome.cancelled();
      }
      if (!context.mounted) {
        return const GeneticsTransferOutcome.cancelled();
      }

      return GeneticsTransferOutcome.success(
        message: 'Received transfer: ${record.displayName}',
        record: record,
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error receiving transfer', e, stackTrace);
      return GeneticsTransferOutcome.failure('Error receiving transfer: $e');
    }
  }

  static Future<GeneticsTransferOutcome> sendTransfer({
    required BuildContext context,
  }) async {
    try {
      final mode = await _promptTransferSendMode(context);
      if (mode == null) {
        return const GeneticsTransferOutcome.cancelled();
      }
      if (!context.mounted) {
        return const GeneticsTransferOutcome.cancelled();
      }

      if (mode == _TransferSendMode.pendingOutgoing) {
        await PendingTransfersDialog.show(context);
        return const GeneticsTransferOutcome.cancelled();
      }

      if (mode == _TransferSendMode.batchMultiGenet) {
        return _initiateBatchTransfer(
          context,
          BatchTransferMode.multiGenetToOneOrg,
        );
      }
      if (mode == _TransferSendMode.batchOneGenet) {
        return _initiateBatchTransfer(
          context,
          BatchTransferMode.oneGenetToMultiOrg,
        );
      }

      // mode == _TransferSendMode.newTransfer
      return _initiateNewTransfer(context);
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error sending transfer', e, stackTrace);
      return GeneticsTransferOutcome.failure('Error sending transfer: $e');
    }
  }

  /// Internal method to initiate a new transfer via the transfer dialog.
  static Future<GeneticsTransferOutcome> _initiateNewTransfer(
    BuildContext context,
  ) async {
    final confirmed = await TransferDialog.showInitiate(
      context,
      genetName: '',
      genetRecordId: '',
      speciesId: '',
      allowLocalIdSelection: true,
    );

    if (!context.mounted) {
      return const GeneticsTransferOutcome.cancelled();
    }
    if (confirmed == true) {
      return const GeneticsTransferOutcome.success(
        message: 'Transfer initiated',
      );
    }
    return const GeneticsTransferOutcome.cancelled();
  }

  static Future<GeneticsTransferOutcome> _initiateBatchTransfer(
    BuildContext context,
    BatchTransferMode mode,
  ) async {
    final result = await TransferDialog.showBatch(context, mode: mode);
    if (!context.mounted) {
      return const GeneticsTransferOutcome.cancelled();
    }
    if (result == true) {
      return const GeneticsTransferOutcome.success(
        message: 'Batch transfer completed',
      );
    }
    return const GeneticsTransferOutcome.cancelled();
  }
}

enum GeneticsTransferStatus { success, cancelled, failure }

class GeneticsTransferOutcome {
  const GeneticsTransferOutcome._(this.status, this.message, [this.record]);

  const GeneticsTransferOutcome.success({
    required String message,
    ProvenanceRecord? record,
  }) : this._(GeneticsTransferStatus.success, message, record);

  const GeneticsTransferOutcome.cancelled()
      : this._(GeneticsTransferStatus.cancelled, '', null);

  const GeneticsTransferOutcome.failure(String message)
      : this._(GeneticsTransferStatus.failure, message, null);

  final GeneticsTransferStatus status;
  final String message;
  final ProvenanceRecord? record;

  bool get isSuccess => status == GeneticsTransferStatus.success;
  bool get isFailure => status == GeneticsTransferStatus.failure;
}

List<String> _resolveSpeciesIds(
  BuildContext context,
  List<String>? speciesIds,
) {
  if (speciesIds != null) {
    return _normalizeSpeciesIds(speciesIds);
  }
  final organization = context.maybeRead<Organization>();
  if (organization == null) return const [];
  return _normalizeSpeciesIds(organization.speciesIds);
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

Future<_TransferReceiveMode?> _promptTransferReceiveMode(
  BuildContext context,
) {
  final eventRepository = context.maybeRead<EventRepository>();
  return showDialog<_TransferReceiveMode>(
    context: context,
    useRootNavigator: false,
    builder: (dialogContext) {
      Widget dialog = SimpleDialog(
        title: const Text('Receive Transfer'),
        children: [
          Builder(
            builder: (builderContext) => _buildPendingTransfersOption(
              builderContext,
              onPressed: () => Navigator.of(dialogContext)
                  .pop(_TransferReceiveMode.pending),
            ),
          ),
          SimpleDialogOption(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_TransferReceiveMode.scan),
            child: const ListTile(
              leading: Icon(Icons.content_paste),
              title: Text('Enter Manifest Payload'),
              subtitle: Text('Paste the manifest shared by the sender'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_TransferReceiveMode.manual),
            child: const ListTile(
              leading: Icon(Icons.note_add),
              title: Text('Manual Register'),
              subtitle: Text('Enter provenance details without a manifest'),
            ),
          ),
        ],
      );

      if (eventRepository != null) {
        dialog = BlocProvider(
          create: (_) => TransferCountCubit(eventRepository: eventRepository),
          child: dialog,
        );
      }

      return dialog;
    },
  );
}

Widget _buildPendingTransfersOption(
  BuildContext context, {
  required VoidCallback onPressed,
}) {
  final hasCubit = context.maybeRead<TransferCountCubit>() != null;
  if (!hasCubit) {
    return SimpleDialogOption(
      onPressed: onPressed,
      child: const ListTile(
        leading: Icon(Icons.pending_actions, color: Colors.orange),
        title: Text('Pending Transfers'),
        subtitle: Text('Review incoming and outgoing transfers'),
      ),
    );
  }

  return SimpleDialogOption(
    onPressed: onPressed,
    child: BlocBuilder<TransferCountCubit, TransferCountState>(
      builder: (context, state) {
        final count = state is TransferCountLoaded ? state.count : 0;
        final leading = count > 0
            ? Badge(
                label: Text(count.toString()),
                child: const Icon(
                  Icons.pending_actions,
                  color: Colors.orange,
                ),
              )
            : const Icon(Icons.pending_actions, color: Colors.orange);
        return ListTile(
          leading: leading,
          title: const Text('Pending Transfers'),
          subtitle: const Text('Review incoming and outgoing transfers'),
        );
      },
    ),
  );
}

enum _TransferReceiveMode { scan, manual, pending }

enum _TransferSendMode { newTransfer, pendingOutgoing, batchMultiGenet, batchOneGenet }

Future<_TransferSendMode?> _promptTransferSendMode(
  BuildContext context,
) {
  final eventRepository = context.maybeRead<EventRepository>();
  return showDialog<_TransferSendMode>(
    context: context,
    useRootNavigator: false,
    builder: (dialogContext) {
      Widget dialog = SimpleDialog(
        title: const Text('Send Transfer'),
        children: [
          SimpleDialogOption(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_TransferSendMode.newTransfer),
            child: const ListTile(
              leading: Icon(Icons.outbox, color: Colors.blue),
              title: Text('New Transfer'),
              subtitle: Text('Send genetics to another organization'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext)
                .pop(_TransferSendMode.batchMultiGenet),
            child: const ListTile(
              leading: Icon(Icons.dynamic_feed, color: Colors.teal),
              title: Text('Multiple Genets → One Org'),
              subtitle: Text('Send multiple genets to one organization'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext)
                .pop(_TransferSendMode.batchOneGenet),
            child: const ListTile(
              leading: Icon(Icons.call_split, color: Colors.indigo),
              title: Text('One Genet → Multiple Orgs'),
              subtitle: Text('Distribute one genet to multiple organizations'),
            ),
          ),
          Builder(
            builder: (builderContext) => _buildPendingOutgoingOption(
              builderContext,
              onPressed: () => Navigator.of(dialogContext)
                  .pop(_TransferSendMode.pendingOutgoing),
            ),
          ),
        ],
      );

      if (eventRepository != null) {
        dialog = BlocProvider(
          create: (_) => TransferCountCubit(eventRepository: eventRepository),
          child: dialog,
        );
      }

      return dialog;
    },
  );
}

Widget _buildPendingOutgoingOption(
  BuildContext context, {
  required VoidCallback onPressed,
}) {
  final hasCubit = context.maybeRead<TransferCountCubit>() != null;
  if (!hasCubit) {
    return SimpleDialogOption(
      onPressed: onPressed,
      child: const ListTile(
        leading: Icon(Icons.pending_actions, color: Colors.orange),
        title: Text('Pending Outgoing Transfers'),
        subtitle: Text('View and manage transfers you have sent'),
      ),
    );
  }

  return SimpleDialogOption(
    onPressed: onPressed,
    child: BlocBuilder<TransferCountCubit, TransferCountState>(
      builder: (context, state) {
        final count = state is TransferCountLoaded ? state.count : 0;
        final leading = count > 0
            ? Badge(
                label: Text(count.toString()),
                child: const Icon(
                  Icons.pending_actions,
                  color: Colors.orange,
                ),
              )
            : const Icon(Icons.pending_actions, color: Colors.orange);
        return ListTile(
          leading: leading,
          title: const Text('Pending Outgoing Transfers'),
          subtitle: const Text('View and manage transfers you have sent'),
        );
      },
    ),
  );
}
