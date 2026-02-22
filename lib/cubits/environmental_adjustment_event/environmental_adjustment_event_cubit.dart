// @tier: community
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:path/path.dart' as path;
import 'package:seafoundry_app/cubits/base/safe_cubit.dart';
import 'package:meta/meta.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_events.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_state.dart';
import 'package:seafoundry_app/errors/domain_errors.dart';
import 'package:seafoundry_app/models/events/environmental_adjustment_event.dart';
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/types/model_type.dart';
import 'package:seafoundry_app/repositories/firebase_utils.dart';
import 'package:seafoundry_app/repositories/inventory/activity_event_repository.dart';
import 'package:seafoundry_app/repositories/inventory/event_repository.dart';
import 'package:seafoundry_app/services/connectivity_service.dart';
import 'package:seafoundry_app/services/event_propagation_service.dart';
import 'package:seafoundry_app/services/image_service.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/offline/activity_event_offline_handler.dart';
import 'package:seafoundry_app/services/site_capability_guard.dart';

part 'environmental_adjustment_event_state.dart';

typedef ObservationTargetResolver = Future<List<GraphNode>> Function();

class EnvironmentalAdjustmentEventCubit
    extends SafeCubit<EnvironmentalAdjustmentEventState> {
  EnvironmentalAdjustmentEventCubit({
    required EventRepository eventRepository,
    required ImageService imageService,
    EnvironmentalAdjustmentEvent? existingEvent,
    ActivityEventOfflineHandler? offlineHandler,
    ConnectivityService? connectivityService,
  }) : _eventRepository = eventRepository,
       _imageService = imageService,
       _existingEvent = existingEvent,
       _offlineHandler = offlineHandler,
       _connectivityService = connectivityService,
       super(
         existingEvent != null
             ? EnvironmentalAdjustmentEventState(
                 adjustmentTypeId: existingEvent.adjustmentTypeId,
                 previousValue: existingEvent.previousValue ?? '',
                 newValue: existingEvent.newValue ?? '',
                 amount: existingEvent.amount?.toString() ?? '',
                 unit: existingEvent.unit ?? '',
                 comment: existingEvent.comment ?? '',
                  permitId: existingEvent.permitMetadata.permitId ?? '',
                  permitType: existingEvent.permitMetadata.permitType ?? '',
                  issuingAuthority:
                      existingEvent.permitMetadata.issuingAuthority ?? '',
                  permitAttachmentUrls:
                      existingEvent.permitMetadata.attachmentUrls.isEmpty
                          ? ''
                          : existingEvent.permitMetadata.attachmentUrls
                              .join('\n'),
                  permitValidFrom: existingEvent.permitMetadata.validFrom,
                  permitValidTo: existingEvent.permitMetadata.validTo,
                  imagePath: existingEvent.imageUrl,
                  isEditing: true,
                )
             : EnvironmentalAdjustmentEventState(
                 adjustmentTypeId: EnvironmentalAdjustmentType.lightingChange.id,
               ),
       );

  final EventRepository _eventRepository;
  final ImageService _imageService;
  final EnvironmentalAdjustmentEvent? _existingEvent;
  final ActivityEventOfflineHandler? _offlineHandler;
  final ConnectivityService? _connectivityService;
  File? _imageFile;

  bool get _isOnline =>
      (_connectivityService ?? ConnectivityService.instance).isOnline;

  Future<void> initializeCameraPermission() async {
    try {
      final status = await Permission.camera.status;
      emit(state.copyWith(cameraStatus: status));
    } catch (error, stackTrace) {
      LoggingService.instance.warning(
        'Failed to obtain camera permission status: $error',
      );
      LoggingService.instance.trace(
        'Camera permission status stack trace: $stackTrace',
      );
      emit(
        state.copyWith(
          notification: () => EnvironmentalAdjustmentEventNotification.error(
            'Unable to read camera permissions. Enable camera access manually if needed.',
          ),
        ),
      );
    }
  }

  void updateAdjustmentType(String value) {
    emit(state.copyWith(adjustmentTypeId: value));
  }

  void updatePreviousValue(String value) {
    emit(state.copyWith(previousValue: value));
  }

  void updateNewValue(String value) {
    emit(state.copyWith(newValue: value));
  }

  void updateAmount(String value) {
    emit(state.copyWith(amount: value));
  }

  void updateUnit(String value) {
    emit(state.copyWith(unit: value));
  }

  void updateComment(String value) {
    emit(state.copyWith(comment: value));
  }

  void updatePermitId(String value) {
    emit(state.copyWith(permitId: value));
  }

  void updatePermitType(String value) {
    emit(state.copyWith(permitType: value));
  }

  void updateIssuingAuthority(String value) {
    emit(state.copyWith(issuingAuthority: value));
  }

  void updatePermitAttachmentUrls(String value) {
    emit(state.copyWith(permitAttachmentUrls: value));
  }

  void updatePermitValidFrom(DateTime? value) {
    emit(state.copyWith(permitValidFrom: value));
  }

  void updatePermitValidTo(DateTime? value) {
    emit(state.copyWith(permitValidTo: value));
  }

  Future<void> requestCameraPermission() async {
    try {
      final status = await Permission.camera.request();
      emit(state.copyWith(cameraStatus: status));
    } catch (error, stackTrace) {
      LoggingService.instance.warning(
        'Camera permission request failed: $error',
      );
      LoggingService.instance.trace(
        'Camera permission request stack trace: $stackTrace',
      );
      emit(
        state.copyWith(
          notification: () => EnvironmentalAdjustmentEventNotification.error(
            'Unable to request camera permission. Update permissions in system settings.',
          ),
        ),
      );
    }
  }

  Future<void> captureImage() async {
    if (state.isCapturingImage || state.isSubmitting) {
      return;
    }

    if (state.cameraStatus != PermissionStatus.granted) {
      await requestCameraPermission();
      if (state.cameraStatus != PermissionStatus.granted) {
        return;
      }
    }

    emit(state.copyWith(isCapturingImage: true));

    try {
      final file = await _imageService.captureImage();
      if (file == null) {
        emit(
          state.copyWith(
            isCapturingImage: false,
            notification: () => EnvironmentalAdjustmentEventNotification.info(
              'No photo captured.',
            ),
          ),
        );
        return;
      }

      if (_imageFile != null) {
        await _deleteTempFile(_imageFile!);
      }

      _imageFile = file;
      emit(state.copyWith(isCapturingImage: false, imagePath: file.path));
    } catch (error, stackTrace) {
      LoggingService.instance.error('Error capturing image', error, stackTrace);
      emit(
        state.copyWith(
          isCapturingImage: false,
          notification: () => EnvironmentalAdjustmentEventNotification.error(
            'Failed to capture image: $error',
          ),
        ),
      );
    }
  }

  Future<void> removeImage() async {
    if (_imageFile != null) {
      await _deleteTempFile(_imageFile!);
      _imageFile = null;
    }
    emit(state.copyWith(imagePath: null));
  }

  Future<EnvironmentalAdjustmentEvent?> submit(
    ObservationTargetResolver resolveTargets,
  ) async {
    if (state.isSubmitting) {
      return null;
    }

    emit(state.copyWith(isSubmitting: true));

    try {
      final storageKey =
          ImageService.resolveOrganizationStorageKeyFromOrganization(
            _eventRepository.organization,
          );
      final permitMetadata = _buildPermitMetadata();
      // Handle editing existing event
      if (state.isEditing && _existingEvent != null) {
        String? uploadedImageUrl;
        if (_imageFile != null) {
          if (_isOnline) {
            uploadedImageUrl = await _imageService.uploadImage(
              imageFile: _imageFile!,
              organizationId: storageKey,
              recordType: 'event',
              recordId: _existingEvent.id,
            );

            if (uploadedImageUrl == null) {
              throw Exception('Failed to upload image');
            }
          } else {
            final imageBytes = await _imageFile!.readAsBytes();
            final fileName = path.basename(_imageFile!.path);
            final queuedUpload = await _imageService.queueOfflineUpload(
              imageBytes: imageBytes,
              fileName: fileName,
              recordType: 'event',
              recordId: _existingEvent.id,
              eventId: _existingEvent.id,
              organizationId: storageKey,
            );
            uploadedImageUrl = queuedUpload?.storagePath;
          }
        }

        final removeExistingImage =
            state.imagePath == null && _imageFile == null && _existingEvent.imageUrl != null;

        final now = DateTime.now().toIso8601String();
        final updatedEvent = _existingEvent.copyWith(
          adjustmentTypeId: state.adjustmentTypeId,
          previousValue: state.previousValue.trim().isNotEmpty
              ? state.previousValue.trim()
              : null,
          newValue: state.newValue.trim().isNotEmpty
              ? state.newValue.trim()
              : null,
          amount: _parseAmount(state.amount),
          unit: state.unit.trim().isNotEmpty ? state.unit.trim() : null,
          comment: state.comment.trim().isNotEmpty
              ? state.comment.trim()
              : null,
          imageUrl: removeExistingImage ? null : (uploadedImageUrl ?? _existingEvent.imageUrl),
          updatedAt: now,
          updatedById: _eventRepository.user.id,
          permitMetadata: permitMetadata,
        );

        final enrichedEvent =
            _eventRepository.withOrganismMetadata(updatedEvent);

        await _eventRepository.collectionRef
            .doc(_existingEvent.id)
            .update(enrichedEvent.toJson());

        // Reload the target node
        final targetNodes = await resolveTargets();
        for (final node in targetNodes) {
          _requestReload(node);
        }

        await _cleanupImageFile();

        emit(
          state.copyWith(
            isSubmitting: false,
            imagePath: null,
            notification: () => EnvironmentalAdjustmentEventNotification.success(
              'Environmental adjustment updated successfully.',
            ),
          ),
        );

        return enrichedEvent;
      }

      // Handle creating new event
      final targetNodes = await resolveTargets();
      final activeTargets = targetNodes.where((node) => !node.isClosed).toList();
      if (activeTargets.isEmpty) {
        throw StateError('Unable to determine observation targets');
      }

      final activityRepository = ActivityEventRepository(
        organization: _eventRepository.organization,
        user: _eventRepository.user,
        firestore: _eventRepository.db,
        organismContext: _eventRepository.organismContext,
        offlineHandler: _offlineHandler,
      );
      final propagationService = EventPropagationService(
        activityEventRepository: activityRepository,
        organismContext: _eventRepository.organismContext,
      );
      const guard = SiteCapabilityGuard();

      for (final node in activeTargets) {
        guard.ensureNodeAllows(
          node: node,
          action: SiteCapabilityAction.environmentalAdjustment,
        );
      }

      final primaryNode = activeTargets.first;
      await primaryNode.awaitLoaded();
      final primaryState = primaryNode.state;
      if (primaryState is! GraphLoadedState) {
        throw StateError('Unable to load environmental adjustment target');
      }
      final record = primaryState.record;

      final eventId = generateId(firestore: _eventRepository.db);
      final eventSlug = await _eventRepository.nextSlugForModelType(
        ModelType.event,
      );

      String? uploadedImageUrl;
      if (_imageFile != null) {
        if (_isOnline) {
          uploadedImageUrl = await _imageService.uploadImage(
            imageFile: _imageFile!,
            organizationId: storageKey,
            recordType: 'event',
            recordId: eventId,
          );

          if (uploadedImageUrl == null) {
            throw Exception('Failed to upload image');
          }
        } else {
          final imageBytes = await _imageFile!.readAsBytes();
          final fileName = path.basename(_imageFile!.path);
          final queuedUpload = await _imageService.queueOfflineUpload(
            imageBytes: imageBytes,
            fileName: fileName,
            recordType: 'event',
            recordId: eventId,
            eventId: eventId,
            organizationId: storageKey,
          );
          uploadedImageUrl = queuedUpload?.storagePath;
        }
      }

      final now = DateTime.now().toIso8601String();
      final event = EnvironmentalAdjustmentEvent(
        id: eventId,
        adjustmentTypeId: state.adjustmentTypeId,
        previousValue: state.previousValue.trim().isNotEmpty
            ? state.previousValue.trim()
            : null,
        newValue:
            state.newValue.trim().isNotEmpty ? state.newValue.trim() : null,
        amount: _parseAmount(state.amount),
        unit: state.unit.trim().isNotEmpty ? state.unit.trim() : null,
        comment:
            state.comment.trim().isNotEmpty ? state.comment.trim() : null,
        imageUrl: uploadedImageUrl,
        base: EventBaseParams(
          permitMetadata: permitMetadata,
        ),
        createdById: _eventRepository.user.id,
        createdAt: now,
        updatedAt: now,
        updatedById: _eventRepository.user.id,
        organizationId: _eventRepository.organization.id,
        recordId: record.id,
        recordModelType: record.modelType,
        urlPath: '${record.urlPath}/$eventSlug',
        internalPath: '${record.internalPath}/$eventId',
        slug: eventSlug,
      );

      final enrichedEvent = _eventRepository.withOrganismMetadata(event);

      await _eventRepository.collectionRef
          .doc(eventId)
          .set(enrichedEvent.toJson());

      final nodesToReload = <GraphNode>{primaryNode};
      nodesToReload.addAll(activeTargets.skip(1));

      try {
        await propagationService.propagateToParents(
          sourceEvent: enrichedEvent,
          sourceNode: primaryNode,
          activityType: 'environmental_adjustment',
        );
        LoggingService.instance.info(
          'Environmental adjustment event propagated to parent nodes: ${event.id}',
        );
      } catch (error, stackTrace) {
        LoggingService.instance.warning(
          'Failed to propagate environmental adjustment event: $error',
        );
        LoggingService.instance.trace(
          'Environmental adjustment propagation stack trace: $stackTrace',
        );
      }

      if (activeTargets.length > 1) {
        try {
          await propagationService.propagateToTargetNodes(
            sourceEvent: enrichedEvent,
            targetNodes: activeTargets.skip(1),
            activityType: 'environmental_adjustment',
          );
        } catch (error, stackTrace) {
          LoggingService.instance.warning(
            'Failed to create environmental adjustment references: $error',
          );
          LoggingService.instance.trace(
            'Environmental adjustment reference stack trace: $stackTrace',
          );
        }
      }

      final createdEvent = enrichedEvent;

      await _cleanupImageFile();
      for (final node in nodesToReload) {
        _requestReload(node);
      }

      emit(
        state.copyWith(
          isSubmitting: false,
          imagePath: null,
          notification: () => EnvironmentalAdjustmentEventNotification.success(
            'Environmental adjustment recorded successfully.',
          ),
        ),
      );

      return createdEvent;
    } on CapabilityConstraintError catch (error, stackTrace) {
      LoggingService.instance.warning(
        'Capability guard prevented environmental adjustment',
        error,
      );
      LoggingService.instance.trace(
        'Capability guard stack trace: $stackTrace',
      );
      emit(
        state.copyWith(
          isSubmitting: false,
          notification: () =>
              EnvironmentalAdjustmentEventNotification.error(error.message),
        ),
      );
      return null;
    } on FormatException catch (error, stackTrace) {
      LoggingService.instance.warning(
        'Invalid environmental adjustment amount: $error',
      );
      LoggingService.instance.trace(
        'Environmental adjustment amount stack trace: $stackTrace',
      );
      emit(
        state.copyWith(
          isSubmitting: false,
          notification: () => EnvironmentalAdjustmentEventNotification.error(
            'Please enter a valid numeric amount. ${error.message}',
          ),
        ),
      );
      return null;
    } on StateError catch (error, stackTrace) {
      LoggingService.instance.warning(
        'Environmental adjustment submission blocked: $error',
      );
      LoggingService.instance.trace(
        'Environmental adjustment submission stack trace: $stackTrace',
      );
      emit(
        state.copyWith(
          isSubmitting: false,
          notification: () =>
              EnvironmentalAdjustmentEventNotification.error(error.message),
        ),
      );
      return null;
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'Error recording environmental adjustment',
        error,
        stackTrace,
      );
      emit(
        state.copyWith(
          isSubmitting: false,
          notification: () => EnvironmentalAdjustmentEventNotification.error(
            'Failed to record environmental adjustment: $error',
          ),
        ),
      );
      return null;
    }
  }

  void clearNotification() {
    if (state.notification != null) {
      emit(state.copyWith(notification: () => null));
    }
  }

  @visibleForTesting
  void setCameraStatusForTesting(PermissionStatus status) {
    emit(state.copyWith(cameraStatus: status));
  }

  @visibleForTesting
  void setImageFileForTesting(File? file) {
    _imageFile = file;
    emit(state.copyWith(imagePath: file?.path));
  }

  EventPermitMetadata? _buildPermitMetadata() {
    final hadInitialPermit =
        _existingEvent?.permitMetadata.isEmpty == false;
    return buildPermitMetadataFromTextInputs(
      permitIdText: state.permitId,
      permitTypeText: state.permitType,
      issuingAuthorityText: state.issuingAuthority,
      attachmentsText: state.permitAttachmentUrls,
      validFrom: state.permitValidFrom,
      validTo: state.permitValidTo,
      hadInitialPermit: hadInitialPermit,
      isEditMode: state.isEditing,
    );
  }

  double? _parseAmount(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return double.parse(trimmed);
  }

  Future<void> _cleanupImageFile() async {
    if (_imageFile != null) {
      await _deleteTempFile(_imageFile!);
      _imageFile = null;
    }
  }

  Future<void> _deleteTempFile(File file) async {
    try {
      await file.delete();
    } catch (error, stackTrace) {
      LoggingService.instance.warning(
        'Failed to delete temporary image file: $error',
      );
      LoggingService.instance.trace(
        'Temporary image cleanup stack trace: $stackTrace',
      );
    }
  }

  void _requestReload(GraphNode node) {
    if (!node.isClosed) {
      node.add(const GraphNodeReloadRequested());
    }
  }
}
