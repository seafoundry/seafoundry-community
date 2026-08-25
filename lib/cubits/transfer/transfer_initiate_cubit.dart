import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_community/models/models.dart';
import 'package:seafoundry_community/models/transfer_manifest.dart';
import 'package:seafoundry_community/repositories/organization_repository.dart';
import 'package:seafoundry_community/services/logging_service.dart';
import 'package:seafoundry_community/services/transfer_service.dart';
import 'package:seafoundry_community/utils/validation_utils.dart';

class TransferInitiateState extends Equatable {
  TransferInitiateState({
    this.recipientMode = RecipientMode.organization,
    this.selectedOrganization,
    this.recipientEmail = '',
    this.selectingOrganization = false,
    this.transferEvent,
    this.manifest,
    this.geometryText = '',
    this.geometryInput,
    this.geometryValidationMessage,
    ProvenanceLifeStageSelection? provenanceSelection,
    this.selectedPhysicalFormId = 'fragment',
    this.sizeSpec = const SizeSpec(),
  }) : provenanceSelection = provenanceSelection ?? ProvenanceLifeStageSelection.fallback();

  /// How the recipient is specified (organization lookup vs direct email)
  final RecipientMode recipientMode;

  /// Selected organization (used in organization mode)
  final Organization? selectedOrganization;

  /// Recipient email address (used in email mode)
  final String recipientEmail;

  final bool selectingOrganization;
  final TransferEvent? transferEvent;
  final TransferManifest? manifest;
  final String geometryText;
  final OutplantGeometryInput? geometryInput;
  final String? geometryValidationMessage;

  /// Provenance/life stage selection for the transfer.
  final ProvenanceLifeStageSelection provenanceSelection;

  /// Physical form ID (e.g., 'fragment', 'colony').
  final String selectedPhysicalFormId;

  /// Size specification for the transferred organisms.
  final SizeSpec sizeSpec;

  bool get hasTransfer => transferEvent != null;

  /// Whether the recipient is valid based on current mode
  bool get hasValidRecipient {
    return switch (recipientMode) {
      RecipientMode.organization => selectedOrganization != null,
      RecipientMode.email => ValidationUtils.isValidEmail(recipientEmail),
    };
  }

  /// Display name for the recipient based on current mode
  String? get recipientDisplayName {
    return switch (recipientMode) {
      RecipientMode.organization => selectedOrganization?.name,
      RecipientMode.email =>
        recipientEmail.isNotEmpty ? recipientEmail : null,
    };
  }

  static const _sentinel = Object();

  TransferInitiateState copyWith({
    RecipientMode? recipientMode,
    Object? selectedOrganization = _sentinel,
    String? recipientEmail,
    bool? selectingOrganization,
    Object? transferEvent = _sentinel,
    Object? manifest = _sentinel,
    Object? geometryText = _sentinel,
    Object? geometryInput = _sentinel,
    Object? geometryValidationMessage = _sentinel,
    ProvenanceLifeStageSelection? provenanceSelection,
    String? selectedPhysicalFormId,
    SizeSpec? sizeSpec,
  }) {
    return TransferInitiateState(
      recipientMode: recipientMode ?? this.recipientMode,
      selectedOrganization: selectedOrganization == _sentinel
          ? this.selectedOrganization
          : selectedOrganization as Organization?,
      recipientEmail: recipientEmail ?? this.recipientEmail,
      selectingOrganization:
          selectingOrganization ?? this.selectingOrganization,
      transferEvent: transferEvent == _sentinel
          ? this.transferEvent
          : transferEvent as TransferEvent?,
      manifest: manifest == _sentinel
          ? this.manifest
          : manifest as TransferManifest?,
      geometryText: geometryText == _sentinel
          ? this.geometryText
          : geometryText as String,
      geometryInput: geometryInput == _sentinel
          ? this.geometryInput
          : geometryInput as OutplantGeometryInput?,
      geometryValidationMessage:
          geometryValidationMessage == _sentinel
              ? this.geometryValidationMessage
              : geometryValidationMessage as String?,
      provenanceSelection: provenanceSelection ?? this.provenanceSelection,
      selectedPhysicalFormId:
          selectedPhysicalFormId ?? this.selectedPhysicalFormId,
      sizeSpec: sizeSpec ?? this.sizeSpec,
    );
  }

  @override
  List<Object?> get props => [
        recipientMode,
        selectedOrganization,
        recipientEmail,
        selectingOrganization,
        transferEvent,
        manifest,
        geometryText,
        geometryInput,
        geometryValidationMessage,
        provenanceSelection,
        selectedPhysicalFormId,
        sizeSpec,
      ];
}

class TransferInitiateCubit extends Cubit<TransferInitiateState> {
  TransferInitiateCubit({
    required this.transferService,
    required this.organizationRepository,
    this.sourceStructureUrlPath,
    this.originalEvent,
    ProvenanceLifeStageSelection? initialProvenanceSelection,
    String? initialPhysicalFormId,
    SizeSpec? initialSizeSpec,
  }) : super(
         TransferInitiateState(
           recipientMode: _initialRecipientMode(originalEvent),
           recipientEmail: originalEvent?.toOrganizationEmail ?? '',
           geometryText: _initialGeometryText(originalEvent),
           geometryInput: _initialGeometryInput(originalEvent),
           provenanceSelection: _initialProvenanceSelection(
             originalEvent,
             initialProvenanceSelection,
           ),
           selectedPhysicalFormId: _initialPhysicalFormId(
             originalEvent,
             initialPhysicalFormId,
           ),
           sizeSpec: _initialSizeSpec(originalEvent, initialSizeSpec),
         ),
       ) {
    if (originalEvent != null && originalEvent!.toOrganizationId != null) {
      _hydrateOrganization(originalEvent!.toOrganizationId!);
    }
  }

  final TransferService transferService;
  final OrganizationRepository organizationRepository;
  final String? sourceStructureUrlPath;
  final TransferEvent? originalEvent;

  /// Sets the recipient mode (organization lookup vs email)
  void setRecipientMode(RecipientMode mode) {
    emit(state.copyWith(recipientMode: mode));
  }

  /// Sets the recipient email address (for email mode)
  void setRecipientEmail(String email) {
    emit(state.copyWith(recipientEmail: email));
  }

  void setSelectedOrganization(Organization organization) {
    emit(state.copyWith(selectedOrganization: organization));
  }

  void setSelectingOrganization(bool selecting) {
    emit(state.copyWith(selectingOrganization: selecting));
  }

  /// Update the provenance/life stage selection.
  void updateProvenanceSelection(ProvenanceLifeStageSelection selection) {
    emit(state.copyWith(provenanceSelection: selection));
  }

  /// Update the physical form ID.
  void updatePhysicalForm(String physicalFormId) {
    emit(state.copyWith(selectedPhysicalFormId: physicalFormId));
  }

  /// Update the size specification.
  void updateSizeSpec(SizeSpec sizeSpec) {
    emit(state.copyWith(sizeSpec: sizeSpec));
  }

  Future<void> _hydrateOrganization(String organizationId) async {
    try {
      final org = await organizationRepository.getById(organizationId);
      if (isClosed) return;
      if (org != null) {
        emit(state.copyWith(selectedOrganization: org));
      }
    } on FirebaseException catch (e, stackTrace) {
      LoggingService.instance.error(
        'Firebase error loading organization $organizationId: ${e.message}',
        e,
        stackTrace,
      );
    } catch (e, stackTrace) {
      LoggingService.instance.warning(
        'Failed to load organization $organizationId: $e',
        {'stackTrace': stackTrace.toString()},
      );
    }
  }

  /// Submits the transfer based on current recipient mode.
  /// For organization mode, uses the selected organization.
  /// For email mode, uses the recipient email address.
  Future<TransferEvent> submitTransfer({
    required String genetRecordId,
    required int quantity,
    required ProvenanceLifeStageSelection provenanceSelection,
    required String physicalFormId,
    required SizeSpec sizeSpec,
    String? comment,
    OutplantGeometryInput? geometryInput,
    Map<String, int>? inventorySelection,
  }) async {
    // Handle edit mode - updates always go through updatePendingTransfer
    if (originalEvent != null) {
      final transfer = await transferService.updatePendingTransfer(
        transferEventId: originalEvent!.id,
        quantity: quantity,
        comment: comment?.isEmpty == true ? null : comment,
        provenanceTypeOverride: provenanceSelection.provenanceType,
        lifeStageOverride: provenanceSelection.lifeStage,
        physicalFormOverride: physicalFormId,
        sizeSpecOverride: sizeSpec,
        geometryInput: geometryInput,
      );
      _emitSuccess(transfer);
      LoggingService.instance.info('Transfer updated: ${transfer.id}');
      return transfer;
    }

    // Handle new transfers based on recipient mode
    final TransferEvent transfer;

    switch (state.recipientMode) {
      case RecipientMode.organization:
        final destination = state.selectedOrganization;
        if (destination == null) {
          throw StateError(
            'Destination organization required for organization mode',
          );
        }
        transfer = await transferService.initiateTransfer(
          genetRecordId: genetRecordId,
          toOrganizationId: destination.id,
          quantity: quantity,
          sourceStructureUrlPath: sourceStructureUrlPath,
          comment: comment?.isEmpty == true ? null : comment,
          provenanceTypeOverride: provenanceSelection.provenanceType,
          lifeStageOverride: provenanceSelection.lifeStage,
          physicalFormOverride: physicalFormId,
          sizeSpecOverride: sizeSpec,
          geometryInput: geometryInput,
          inventorySelection: inventorySelection,
        );
        if (isClosed) return transfer;
        _emitSuccess(transfer);
        LoggingService.instance.info(
          'Transfer initiated: ${transfer.id} to ${destination.name}',
        );

      case RecipientMode.email:
        final email = state.recipientEmail.trim();
        if (email.isEmpty) {
          throw StateError('Recipient email required for email mode');
        }
        transfer = await transferService.initiateTransferToEmail(
          genetRecordId: genetRecordId,
          toOrganizationEmail: email,
          quantity: quantity,
          sourceStructureUrlPath: sourceStructureUrlPath,
          comment: comment?.isEmpty == true ? null : comment,
          provenanceTypeOverride: provenanceSelection.provenanceType,
          lifeStageOverride: provenanceSelection.lifeStage,
          physicalFormOverride: physicalFormId,
          sizeSpecOverride: sizeSpec,
          geometryInput: geometryInput,
          inventorySelection: inventorySelection,
        );
        if (isClosed) return transfer;
        _emitSuccess(transfer);
        LoggingService.instance.info(
          'Email transfer initiated: ${transfer.id} to $email',
        );
    }

    return transfer;
  }

  static RecipientMode _initialRecipientMode(TransferEvent? event) {
    if (event == null) return RecipientMode.organization;
    // If event has email but no org ID, it's email mode
    if (event.toOrganizationEmail != null &&
        event.toOrganizationEmail!.isNotEmpty &&
        event.toOrganizationId == null) {
      return RecipientMode.email;
    }
    return RecipientMode.organization;
  }

  void _emitSuccess(TransferEvent transfer) {
    emit(
      state.copyWith(
        transferEvent: transfer,
        manifest: _extractManifest(transfer),
      ),
    );
  }

  TransferManifest? _extractManifest(TransferEvent transfer) {
    try {
      if (transfer.manifest != null) {
        return TransferManifest.fromJson(transfer.manifest!);
      }
      return null;
    } catch (e, stackTrace) {
      LoggingService.instance.error(
        'Failed to decode transfer manifest for ${transfer.id}',
        e,
        stackTrace,
      );
      return null;
    }
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
      final coordinates = _parseManualCoordinates(value);
      final input = OutplantGeometryInput(
        type: coordinates.length == 1
            ? OutplantGeometryType.point
            : OutplantGeometryType.polygon,
        coordinates: coordinates,
        source: OutplantGeometrySource.manual,
      );
      emit(
        state.copyWith(
          geometryText: value,
          geometryInput: input,
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

  /// Parses manually entered coordinate text (one lat,lng pair per line).
  static List<GeoCoordinate> _parseManualCoordinates(String text) {
    final lines = text
        .split(RegExp(r'[\n\r]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      throw const FormatException('No coordinate pairs found.');
    }
    final coordinates = <GeoCoordinate>[];
    for (final line in lines) {
      final parts = line.split(RegExp(r'[,\s]+'));
      if (parts.length < 2) {
        throw FormatException('Invalid coordinate pair: "$line"');
      }
      final lat = double.tryParse(parts[0]);
      final lng = double.tryParse(parts[1]);
      if (lat == null || lng == null) {
        throw FormatException('Non-numeric coordinate: "$line"');
      }
      coordinates.add(GeoCoordinate(latitude: lat, longitude: lng));
    }
    return coordinates;
  }

  static String _initialGeometryText(TransferEvent? event) {
    final geometry = event?.geometry;
    if (geometry == null || geometry.coordinates.isEmpty) {
      return '';
    }
    return geometry.coordinates
        .map((coord) => '${coord.latitude},${coord.longitude}')
        .join('\n');
  }

  static OutplantGeometryInput? _initialGeometryInput(TransferEvent? event) {
    final geometry = event?.geometry;
    if (geometry == null || geometry.coordinates.isEmpty) return null;
    return OutplantGeometryInput(
      type: geometry.type,
      coordinates: List<GeoCoordinate>.from(geometry.coordinates),
      source: geometry.source,
    );
  }

  static ProvenanceLifeStageSelection _initialProvenanceSelection(
    TransferEvent? event,
    ProvenanceLifeStageSelection? fallback,
  ) {
    if (event != null) {
      final metadata = event.metadata;
      if (metadata != null && metadata.isNotEmpty) {
        return ProvenanceLifeStageSelection.fromCanonicalSources(
          sources: [Map<String, dynamic>.from(metadata)],
        );
      }
    }
    return fallback ?? ProvenanceLifeStageSelection.fallback();
  }

  static String _initialPhysicalFormId(
    TransferEvent? event,
    String? fallback,
  ) {
    final metadata = event?.metadata;
    final raw = metadata?['physicalFormId'];
    if (raw is String && raw.isNotEmpty) {
      return raw;
    }
    return fallback ?? 'fragment';
  }

  static SizeSpec _initialSizeSpec(
    TransferEvent? event,
    SizeSpec? fallback,
  ) {
    final metadata = event?.metadata;
    final raw = metadata?['size'];
    if (raw is Map<String, dynamic>) {
      return SizeSpec.fromJson(Map<String, dynamic>.from(raw));
    }
    return fallback ?? const SizeSpec();
  }
}
