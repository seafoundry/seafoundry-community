// @tier: community
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_events.dart';
import 'package:seafoundry_app/models/events/gene_bank_audit_event.dart';
import 'package:seafoundry_app/models/records/graph_node_record.dart';
import 'package:seafoundry_app/models/types/gene_bank_event_type.dart';
import 'package:seafoundry_app/repositories/inventory/event_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';

class GeneBankAuditState extends Equatable {
  const GeneBankAuditState({
    this.auditType = 'routine',
    this.itemsVerified,
    this.hasDiscrepancies = false,
    this.discrepancyNotes,
    this.comment = '',
    this.isLoading = false,
    this.isEditing = false,
    this.errorMessage,
    this.createdEvent,
  });

  final String auditType;
  final int? itemsVerified;
  final bool hasDiscrepancies;
  final String? discrepancyNotes;
  final String comment;
  final bool isLoading;
  final bool isEditing;
  final String? errorMessage;
  final GeneBankAuditEvent? createdEvent;

  bool get canSubmit => !isLoading && auditType.isNotEmpty;

  GeneBankAuditState copyWith({
    String? auditType,
    int? itemsVerified,
    bool? hasDiscrepancies,
    String? discrepancyNotes,
    String? comment,
    bool? isLoading,
    bool? isEditing,
    String? errorMessage,
    GeneBankAuditEvent? createdEvent,
    bool clearErrorMessage = false,
    bool clearCreatedEvent = false,
  }) {
    return GeneBankAuditState(
      auditType: auditType ?? this.auditType,
      itemsVerified: itemsVerified ?? this.itemsVerified,
      hasDiscrepancies: hasDiscrepancies ?? this.hasDiscrepancies,
      discrepancyNotes: discrepancyNotes ?? this.discrepancyNotes,
      comment: comment ?? this.comment,
      isLoading: isLoading ?? this.isLoading,
      isEditing: isEditing ?? this.isEditing,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      createdEvent: clearCreatedEvent
          ? null
          : (createdEvent ?? this.createdEvent),
    );
  }

  @override
  List<Object?> get props => [
    auditType,
    itemsVerified,
    hasDiscrepancies,
    discrepancyNotes,
    comment,
    isLoading,
    isEditing,
    errorMessage,
    createdEvent,
  ];
}

class GeneBankAuditCubit extends Cubit<GeneBankAuditState> {
  GeneBankAuditCubit({
    required this.eventRepository,
    required this.targetNode,
    this.existingEvent,
  }) : super(
         GeneBankAuditState(
           isEditing: existingEvent != null,
           auditType: existingEvent?.auditType ?? 'routine',
           itemsVerified: existingEvent?.itemsVerified,
           hasDiscrepancies: existingEvent?.hasDiscrepancies ?? false,
           discrepancyNotes: existingEvent?.discrepancyNotes,
           comment: existingEvent?.comment ?? '',
         ),
       );

  final EventRepository eventRepository;
  final GraphNode targetNode;
  final GeneBankAuditEvent? existingEvent;

  Future<GraphNodeRecord> _resolveTargetRecord() async {
    try {
      // Avoid hanging tests when a stub node never transitions to loaded
      await targetNode.awaitLoaded().timeout(const Duration(seconds: 5));
    } catch (_) {
      // Fallback to whatever record the node currently holds
    }
    return targetNode.state.record;
  }

  void auditTypeChanged(String value) {
    emit(state.copyWith(auditType: value, clearErrorMessage: true));
  }

  void itemsVerifiedChanged(int? value) {
    emit(state.copyWith(itemsVerified: value, clearErrorMessage: true));
  }

  void hasDiscrepanciesChanged(bool value) {
    emit(state.copyWith(hasDiscrepancies: value, clearErrorMessage: true));
  }

  void discrepancyNotesChanged(String? value) {
    emit(state.copyWith(discrepancyNotes: value, clearErrorMessage: true));
  }

  void commentChanged(String value) {
    emit(state.copyWith(comment: value, clearErrorMessage: true));
  }

  Future<void> submit() async {
    if (!state.canSubmit) {
      emit(state.copyWith(errorMessage: 'Please select an audit type'));
      return;
    }

    emit(state.copyWith(isLoading: true, clearErrorMessage: true));

    try {
      final record = await _resolveTargetRecord();

      if (state.isEditing && existingEvent != null) {
        final updatedEvent = existingEvent!.copyWith(
          auditType: state.auditType,
          itemsVerified: state.itemsVerified,
          hasDiscrepancies: state.hasDiscrepancies,
          discrepancyNotes: state.discrepancyNotes,
          comment: state.comment.isEmpty ? null : state.comment,
          updatedAt: DateTime.now().toIso8601String(),
          updatedById: eventRepository.user.id,
        );

        final enrichedEvent =
            eventRepository.withOrganismMetadata(updatedEvent);

        await eventRepository.collectionRef
            .doc(enrichedEvent.id)
            .update(enrichedEvent.toJson());

        if (!targetNode.isClosed) {
          targetNode.add(const GraphNodeReloadRequested());
        }

        emit(
          state.copyWith(
            isLoading: false,
            createdEvent: enrichedEvent,
          ),
        );
        return;
      }

      final event = GeneBankAuditEvent.partial(
        eventTypeId: GeneBankEventType.auditId,
        auditType: state.auditType,
        itemsVerified: state.itemsVerified,
        hasDiscrepancies: state.hasDiscrepancies,
        discrepancyNotes: state.discrepancyNotes,
        comment: state.comment.isEmpty ? null : state.comment,
        recordId: record.id,
        recordModelType: record.modelType,
        urlPath: record.urlPath,
        internalPath: record.internalPath,
      );

      final createdEvent = await eventRepository.createEvent(event);

      emit(
        state.copyWith(
          isLoading: false,
          createdEvent: createdEvent as GeneBankAuditEvent?,
        ),
      );

      if (!targetNode.isClosed) {
        targetNode.add(const GraphNodeReloadRequested());
      }
    } on FirebaseException catch (e, stackTrace) {
      LoggingService.instance.error('Firebase error creating audit event: ${e.message}', e, stackTrace);
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to create audit event: ${e.message}',
        ),
      );
    } catch (e, stackTrace) {
      LoggingService.instance.error('Error creating audit event', e, stackTrace);
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to create audit event: ${e.toString()}',
        ),
      );
    }
  }
}
