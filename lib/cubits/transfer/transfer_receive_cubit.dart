// @tier: community
import 'package:equatable/equatable.dart';
import 'package:seafoundry_app/cubits/base/safe_cubit.dart';
import 'package:seafoundry_app/models/models.dart';
import 'package:seafoundry_app/models/transfer_manifest.dart';
import 'package:seafoundry_app/models/transfer_status.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/outplant_geometry_parser.dart';
import 'package:seafoundry_app/services/transfer_service.dart';

class TransferReceiveState extends Equatable {
  const TransferReceiveState({
    this.manifest,
    this.createdGenet,
    this.errorMessage,
    this.validating = false,
    this.accepting = false,
    this.geometryText = '',
    this.geometryInput,
    this.geometryValidationMessage,
    this.crosswalkWarning,
  });

  final TransferManifest? manifest;
  final ProvenanceRecord? createdGenet;
  final String? errorMessage;
  final bool validating;
  final bool accepting;
  final String geometryText;
  final OutplantGeometryInput? geometryInput;
  final String? geometryValidationMessage;

  /// Warning message if crosswalk registration failed during acceptance.
  /// The transfer was still successful, but provenance linking may be incomplete.
  final String? crosswalkWarning;

  /// Whether the transfer was accepted but crosswalk registration failed.
  bool get hasCrosswalkWarning => crosswalkWarning != null;

  TransferReceiveState copyWith({
    TransferManifest? manifest,
    bool clearManifest = false,
    ProvenanceRecord? createdGenet,
    bool clearCreatedGenet = false,
    String? errorMessage,
    bool clearError = false,
    bool? validating,
    bool? accepting,
    String? geometryText,
    Object? geometryInput = _unset,
    Object? geometryValidationMessage = _unset,
    Object? crosswalkWarning = _unset,
  }) {
    return TransferReceiveState(
      manifest: clearManifest ? null : manifest ?? this.manifest,
      createdGenet: clearCreatedGenet
          ? null
          : createdGenet ?? this.createdGenet,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      validating: validating ?? this.validating,
      accepting: accepting ?? this.accepting,
      geometryText: geometryText ?? this.geometryText,
      geometryInput: geometryInput == _unset
          ? this.geometryInput
          : geometryInput as OutplantGeometryInput?,
      geometryValidationMessage: geometryValidationMessage == _unset
          ? this.geometryValidationMessage
          : geometryValidationMessage as String?,
      crosswalkWarning: crosswalkWarning == _unset
          ? this.crosswalkWarning
          : crosswalkWarning as String?,
    );
  }

  @override
  List<Object?> get props => [
    manifest,
    createdGenet,
    errorMessage,
    validating,
    accepting,
    geometryText,
    geometryInput,
    geometryValidationMessage,
    crosswalkWarning,
  ];

  static const _unset = Object();
}

class TransferReceiveCubit extends SafeCubit<TransferReceiveState> {
  TransferReceiveCubit({required this.transferService})
    : super(const TransferReceiveState());

  final TransferService transferService;
  final OutplantGeometryParser _geometryParser = const OutplantGeometryParser();

  /// Hydrates the current state with a validated manifest (non-QR entrypoint).
  void setManifest(TransferManifest manifest) {
    emit(
      state.copyWith(
        manifest: manifest,
        validating: false,
        clearError: true,
        clearCreatedGenet: true,
      ),
    );
  }

  Future<void> validatePayload(String rawPayload) async {
    emit(
      state.copyWith(
        validating: true,
        clearError: true,
        clearManifest: true,
        clearCreatedGenet: true,
        geometryText: '',
        geometryInput: null,
        geometryValidationMessage: null,
      ),
    );
    try {
      final scannedManifest = transferService.decodeManifestPayload(rawPayload);
      final verifiedManifest = await transferService.getTransferManifest(
        scannedManifest.transferId,
      );

      if (verifiedManifest.checksum != scannedManifest.checksum) {
        throw Exception(
          'Manifest checksum mismatch. Please re-scan the QR code.',
        );
      }

      if (verifiedManifest.status == TransferStatus.received ||
          verifiedManifest.status == TransferStatus.rejected) {
        throw Exception(
          'Transfer already marked as ${verifiedManifest.status.name}.',
        );
      }

      emit(state.copyWith(manifest: verifiedManifest, validating: false));
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to validate manifest',
        e,
        stackTrace,
      );
      emit(
        state.copyWith(
          errorMessage: 'Failed to validate manifest: $e',
          validating: false,
          clearManifest: true,
        ),
      );
    }
  }

  /// Surfaces inline validation errors (e.g., missing form input) without
  /// mutating manifest/genet state.
  void surfaceError(String message) {
    emit(state.copyWith(errorMessage: message));
  }

  void updateGeometryText(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      emit(
        state.copyWith(
          geometryText: '',
          geometryInput: null,
          geometryValidationMessage: null,
        ),
      );
      return;
    }

    try {
      final parsed = _geometryParser.parseManual(value);
      emit(
        state.copyWith(
          geometryText: value,
          geometryInput: parsed.input,
          geometryValidationMessage: null,
        ),
      );
    } on FormatException catch (error) {
      emit(
        state.copyWith(
          geometryText: value,
          geometryInput: null,
          geometryValidationMessage: error.message,
        ),
      );
    }
  }

  Future<void> acceptTransfer({
    required String genetName,
    String? localId,
    required ProvenanceType provenanceType,
    required LifeStage lifeStage,
    String? targetUrlPath,
    String? destinationSiteId,
    String? destinationGroupId,
    String? ownerOrganizationId,
    String? managingOrganizationId,
  }) async {
    final manifest = state.manifest;
    if (manifest == null) {
      emit(
        state.copyWith(
          errorMessage: 'Validate a manifest before accepting.',
          clearCreatedGenet: true,
        ),
      );
      return;
    }

    emit(state.copyWith(accepting: true, clearError: true));

    try {
      final genet = await transferService.acceptTransfer(
        transferEventId: manifest.transferId,
        newGenetName: genetName,
        localId: localId?.isEmpty == true ? null : localId,
        provenanceTypeOverride: provenanceType,
        lifeStageOverride: lifeStage,
        geometryInput: state.geometryInput,
        targetUrlPath: targetUrlPath,
        destinationSiteId: destinationSiteId,
        destinationGroupId: destinationGroupId,
        ownerOrganizationId: ownerOrganizationId,
        managingOrganizationId: managingOrganizationId,
      );

      // Check if crosswalk registration failed (best-effort, non-blocking)
      String? crosswalkWarning;
      try {
        final hasCrosswalkFailure = await transferService
            .hasCrosswalkRegistrationFailure(manifest.transferId);
        if (hasCrosswalkFailure) {
          crosswalkWarning =
              'Transfer accepted, but provenance linking failed. '
              'You may need to manually link this genet to the community crosswalk.';
        }
      } catch (e) {
        LoggingService.instance.debug(
          'Error checking crosswalk status: $e',
        );
      }

      emit(state.copyWith(
        createdGenet: genet,
        accepting: false,
        crosswalkWarning: crosswalkWarning,
      ));
    } catch (e, stackTrace) {
      LoggingService.instance.error('Failed to accept transfer', e, stackTrace);
      emit(
        state.copyWith(
          errorMessage: 'Failed to accept transfer: $e',
          accepting: false,
        ),
      );
    }
  }
}
