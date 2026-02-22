// @tier: community
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/models/events/outplant_geometry.dart';
import 'package:seafoundry_app/models/events/transfer_event.dart';
import 'package:seafoundry_app/models/taxonomy/provenance_record.dart';
import 'package:seafoundry_app/models/organization.dart';
import 'package:seafoundry_app/models/provenance_life_stage_selection.dart';
import 'package:seafoundry_app/repositories/organization_repository.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/transfer_service.dart';
import 'package:seafoundry_app/utils/provenance_selection_utils.dart';

part 'pending_transfers_state.dart';

class PendingTransfersCubit extends Cubit<PendingTransfersState> {
  PendingTransfersCubit({
    required TransferService transferService,
    required OrganizationRepository organizationRepository,
  }) : _transferService = transferService,
       _organizationRepository = organizationRepository,
       super(const PendingTransfersState());

  final TransferService _transferService;
  final OrganizationRepository _organizationRepository;

  /// Cache for organization lookups during a single load operation.
  /// Cleared before each refresh to ensure data freshness.
  final Map<String, Organization?> _organizationCache = {};

  /// Cache for genet lookups during a single load operation.
  /// Cleared before each refresh to ensure data freshness.
  final Map<String, ProvenanceRecord?> _genetCache = {};

  Future<void> loadInitialTransfers() async {
    await _refreshTransfers(showLoadingIndicator: true);
  }

  Future<void> refresh() async {
    await _refreshTransfers(showLoadingIndicator: true);
  }

  Future<ProvenanceRecord> acceptTransfer({
    required PendingTransferEntry entry,
    required String localId,
    required String name,
    required ProvenanceLifeStageSelection provenanceSelection,
    OutplantGeometryInput? geometryInput,
    String? targetUrlPath,
    String? destinationSiteId,
    String? destinationGroupId,
  }) async {
    emit(state.copyWith(isProcessing: true, message: () => null));

    try {
      final createdRecord = await _transferService.acceptTransfer(
        transferEventId: entry.transfer.id,
        localId: localId,
        newGenetName: name,
        provenanceTypeOverride: provenanceSelection.provenanceType,
        lifeStageOverride: provenanceSelection.lifeStage,
        geometryInput: geometryInput,
        targetUrlPath: targetUrlPath,
        destinationSiteId: destinationSiteId,
        destinationGroupId: destinationGroupId,
      );

      await _refreshTransfers();

      emit(
        state.copyWith(
          isProcessing: false,
          message: () => PendingTransfersMessage.success(
            'Transfer accepted successfully.',
          ),
        ),
      );

      // TransferService.acceptTransfer returns ProvenanceRecord
      return createdRecord;
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'Failed to accept transfer',
        error,
        stackTrace,
      );
      emit(
        state.copyWith(
          isProcessing: false,
          message: () => PendingTransfersMessage.error(
            _describeError(prefix: 'Failed to accept transfer', error: error),
          ),
        ),
      );
      rethrow;
    }
  }

  Future<void> rejectTransfer({
    required PendingTransferEntry entry,
    String? reason,
  }) async {
    emit(state.copyWith(isProcessing: true, message: () => null));

    try {
      await _transferService.rejectTransfer(
        transferEventId: entry.transfer.id,
        reason: reason?.isNotEmpty == true ? reason : null,
      );

      await _refreshTransfers();

      emit(
        state.copyWith(
          isProcessing: false,
          message: () => PendingTransfersMessage.warning('Transfer rejected.'),
        ),
      );
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'Failed to reject transfer',
        error,
        stackTrace,
      );
      emit(
        state.copyWith(
          isProcessing: false,
          message: () => PendingTransfersMessage.error(
            _describeError(prefix: 'Failed to reject transfer', error: error),
          ),
        ),
      );
      rethrow;
    }
  }

  void clearMessage() {
    if (state.message != null) {
      emit(state.copyWith(message: () => null));
    }
  }

  Future<void> _refreshTransfers({
    bool showLoadingIndicator = false,
  }) async {
    if (showLoadingIndicator) {
      emit(
        state.copyWith(
          status: PendingTransfersStatus.loading,
          errorMessage: () => null,
          message: () => null,
          isProcessing: false,
        ),
      );
    }

    // Always clear caches before loading to ensure data freshness.
    // Caches are only used within a single load operation to avoid
    // duplicate fetches for the same organization/genet across multiple
    // pending transfers.
    _organizationCache.clear();
    _genetCache.clear();

    try {
      final transfers = await _transferService.getPendingTransfers();
      final entries = <PendingTransferEntry>[];

      for (final transfer in transfers) {
        final organization = await _loadOrganization(
          transfer.fromOrganizationId,
        );
        final genet = await _loadGenet(transfer);
        entries.add(
          PendingTransferEntry(
            transfer: transfer,
            fromOrganization: organization,
            genet: genet,
          ),
        );
      }

      emit(
        state.copyWith(
          status: PendingTransfersStatus.success,
          entries: List.unmodifiable(entries),
          errorMessage: () => null,
          isProcessing: false,
        ),
      );
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'Failed to load pending transfers',
        error,
        stackTrace,
      );
      emit(
        state.copyWith(
          status: PendingTransfersStatus.error,
          entries: const [],
          errorMessage: () => _describeError(
            prefix: 'Failed to load pending transfers',
            error: error,
          ),
          isProcessing: false,
        ),
      );
    }
  }

  Future<Organization?> _loadOrganization(String? organizationId) async {
    if (organizationId == null) {
      return null;
    }

    if (_organizationCache.containsKey(organizationId)) {
      return _organizationCache[organizationId];
    }

    final organization = await _organizationRepository.getById(organizationId);
    _organizationCache[organizationId] = organization;
    return organization;
  }

  Future<ProvenanceRecord?> _loadGenet(TransferEvent transfer) async {
    final genetId = transfer.genetId;
    if (genetId == null) {
      return null;
    }

    if (_genetCache.containsKey(genetId)) {
      return _genetCache[genetId];
    }

    // TransferService.getSourceGenet returns ProvenanceRecord?
    final genet = await _transferService.getSourceGenet(transfer);
    _genetCache[genetId] = genet;
    return genet;
  }

  static String _describeError({required String prefix, Object? error}) {
    final description = error == null ? '' : ': ${error.toString()}';
    return '$prefix$description';
  }
}
