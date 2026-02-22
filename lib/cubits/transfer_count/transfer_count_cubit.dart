// @tier: community
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rxdart/rxdart.dart';
import 'package:seafoundry_app/cubits/base/cubit_stream_subscription_mixin.dart';
import 'package:seafoundry_app/cubits/transfer_count/transfer_count_state.dart';
import 'package:seafoundry_app/models/events/transfer_event.dart';
import 'package:seafoundry_app/repositories/inventory/event_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';

/// Cubit for managing pending transfer count
class TransferCountCubit extends Cubit<TransferCountState>
    with CubitStreamSubscriptionMixin {
  final EventRepository _eventRepository;

  TransferCountCubit({required EventRepository eventRepository})
    : _eventRepository = eventRepository,
      super(const TransferCountInitial()) {
    _loadPendingTransfersCount();
  }

  /// Load the count of pending/shipped transfers (inbound + outbound).
  void _loadPendingTransfersCount() {
    // Prevent emitting to a closed cubit
    if (isClosed) return;
    try {
      emit(const TransferCountLoading());

      // Use repository method instead of direct collectionRef access
      listenWithKey<int>(
        'pendingTransfers',
        Rx.combineLatest2<List<TransferEvent>, List<TransferEvent>, int>(
          _eventRepository.streamPendingTransfers(),
          _eventRepository.streamOutboundPendingTransfers(),
          _mergeTransferCount,
        ),
        onData: (totalCount) {
          // Prevent emitting to a closed cubit
          if (isClosed) return;
          LoggingService.instance.info(
            'Loaded $totalCount pending transfers',
          );
          emit(TransferCountLoaded(totalCount));
        },
        onError: (error, stackTrace) {
          // Prevent emitting to a closed cubit
          if (isClosed) return;

          // Handle permission-denied errors specifically
          // Check both lowercase and uppercase codes for cross-platform compatibility
          if (error is FirebaseException &&
              (error.code == 'permission-denied' ||
                  error.code == 'PERMISSION_DENIED')) {
            LoggingService.instance.warning(
              'Permission denied loading pending transfers: ${error.message}',
            );
            emit(const TransferCountError(
              'You do not have permission to view pending transfers.',
            ));
            return;
          }

          LoggingService.instance.error(
            'Error loading pending transfers count',
            error,
            stackTrace,
          );
          emit(TransferCountError('Failed to load transfer count: $error'));
        },
      );
    } on FirebaseException catch (e, stackTrace) {
      if (e.code == 'permission-denied' || e.code == 'PERMISSION_DENIED') {
        LoggingService.instance.warning(
          'Permission denied setting up transfers stream: ${e.message}',
        );
        emit(const TransferCountError(
          'You do not have permission to view pending transfers.',
        ));
        return;
      }
      LoggingService.instance.error(
        'Firebase error setting up pending transfers stream',
        e,
        stackTrace,
      );
      emit(TransferCountError('Failed to load transfer count: ${e.message}'));
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Error setting up pending transfers stream',
        e,
        stackTrace,
      );
      emit(TransferCountError('Failed to load transfer count: $e'));
    }
  }

  static int _mergeTransferCount(
    List<TransferEvent> inbound,
    List<TransferEvent> outbound,
  ) {
    if (outbound.isEmpty) return inbound.length;
    if (inbound.isEmpty) return outbound.length;

    final ids = <String>{};
    for (final transfer in inbound) {
      ids.add(transfer.id);
    }
    for (final transfer in outbound) {
      ids.add(transfer.id);
    }
    return ids.length;
  }

  /// Refresh the transfer count
  void refresh() {
    // Guard against rapid refresh calls while already loading
    if (state is TransferCountLoading) return;
    // listenWithKey automatically cancels previous subscription with same key
    _loadPendingTransfersCount();
  }

  /// Get incoming pending/shipped transfers (for use in dialogs).
  Stream<List<TransferEvent>> get pendingTransfersStream {
    return _eventRepository.streamPendingTransfers();
  }

  // Subscriptions are automatically cancelled by CubitStreamSubscriptionMixin
}
