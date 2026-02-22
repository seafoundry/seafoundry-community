// @tier: community
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:path/path.dart' as path;
import 'package:seafoundry_app/cubits/base/safe_cubit.dart';
import 'package:meta/meta.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_bloc.dart';
import 'package:seafoundry_app/blocs/graph_node/graph_node_events.dart';
import 'package:seafoundry_app/models/events/event.dart';
import 'package:seafoundry_app/models/events/structure_maintenance_event.dart';
import 'package:seafoundry_app/repositories/firebase_utils.dart';
import 'package:seafoundry_app/repositories/inventory/activity_event_repository.dart';
import 'package:seafoundry_app/repositories/inventory/event_repository.dart';
import 'package:seafoundry_app/services/event_propagation_service.dart';
import 'package:seafoundry_app/services/connectivity_service.dart';
import 'package:seafoundry_app/services/image_service.dart';
import 'package:seafoundry_app/services/logging_service.dart';
import 'package:seafoundry_app/services/offline/activity_event_offline_handler.dart';

part 'structure_maintenance_event_state.dart';

class StructureMaintenanceEventCubit
    extends SafeCubit<StructureMaintenanceEventState> {
  StructureMaintenanceEventCubit({
    required GraphNode node,
    required EventRepository eventRepository,
    required ImageService imageService,
    StructureMaintenanceEvent? existingEvent,
    SiteEnvironment? siteEnvironment,
    ActivityEventOfflineHandler? offlineHandler,
    ConnectivityService? connectivityService,
  }) : _node = node,
       _eventRepository = eventRepository,
       _imageService = imageService,
       _existingEvent = existingEvent,
       _offlineHandler = offlineHandler,
       _connectivityService = connectivityService,
       super(
         existingEvent != null
             ? StructureMaintenanceEventState(
                 maintenanceTypeId: existingEvent.maintenanceTypeId,
                 duration: existingEvent.durationMinutes?.toString() ?? '',
                 equipment: existingEvent.equipmentName ?? '',
                 comment: existingEvent.comment ?? '',
                  permitId: existingEvent.permitMetadata.permitId ?? '',
                  permitType: existingEvent.permitMetadata.permitType ?? '',
                  issuingAuthority:
                      existingEvent.permitMetadata.issuingAuthority ?? '',
                  permitAttachmentUrls: existingEvent
                          .permitMetadata.attachmentUrls.isEmpty
                      ? ''
                      : existingEvent.permitMetadata.attachmentUrls
                          .join('\n'),
                  permitValidFrom: existingEvent.permitMetadata.validFrom,
                  permitValidTo: existingEvent.permitMetadata.validTo,
                  resolved: existingEvent.resolved,
                  imagePath: existingEvent.imageUrl,
                  isEditing: true,
                )
             : StructureMaintenanceEventState(
                 maintenanceTypeId: _defaultMaintenanceTypeFor(siteEnvironment),
               ),
       );

  /// Get the default maintenance type ID for a given site environment
  static String _defaultMaintenanceTypeFor(SiteEnvironment? environment) {
    if (environment == null) {
      return StructureMaintenanceType.rackRepair.id;
    }
    // Use the first applicable type for the environment
    final applicableTypes = StructureMaintenanceType.valuesFor(environment);
    return applicableTypes.isNotEmpty
        ? applicableTypes.first.id
        : StructureMaintenanceType.rackRepair.id;
  }

  final GraphNode _node;
  final EventRepository _eventRepository;
  final ImageService _imageService;
  final StructureMaintenanceEvent? _existingEvent;
  final ActivityEventOfflineHandler? _offlineHandler;
  final ConnectivityService? _connectivityService;
  File? _imageFile;

  bool get _isOnline =>
      (_connectivityService ?? ConnectivityService.instance).isOnline;
  String get _storageKey =>
      ImageService.resolveOrganizationStorageKeyFromOrganization(
        _eventRepository.organization,
      );

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
          notification: () => StructureMaintenanceEventNotification.error(
            'Unable to read camera permissions. You may need to enable camera access manually.',
          ),
        ),
      );
    }
  }

  void updateMaintenanceType(String value) {
    emit(state.copyWith(maintenanceTypeId: value));
  }

  void updateDuration(String value) {
    emit(state.copyWith(duration: value));
  }

  void updateEquipment(String value) {
    emit(state.copyWith(equipment: value));
  }

  void updateComment(String value) {
    emit(state.copyWith(comment: value));
  }

  void updateResolved(bool value) {
    emit(state.copyWith(resolved: value));
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
          notification: () => StructureMaintenanceEventNotification.error(
            'Unable to request camera permission. Please update permissions in system settings.',
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
            notification: () => StructureMaintenanceEventNotification.info(
              'No photo captured.',
            ),
          ),
        );
        return;
      }

      if (_imageFile != null) {
        try {
          await _imageFile!.delete();
        } catch (error, stackTrace) {
          LoggingService.instance.warning(
            'Failed to delete previous temporary image: $error',
          );
          LoggingService.instance.trace(
            'Temporary image delete stack trace: $stackTrace',
          );
        }
      }
      _imageFile = file;
      emit(state.copyWith(isCapturingImage: false, imagePath: file.path));
    } catch (error, stackTrace) {
      LoggingService.instance.error('Error capturing image', error, stackTrace);
      emit(
        state.copyWith(
          isCapturingImage: false,
          notification: () => StructureMaintenanceEventNotification.error(
            'Failed to capture image: $error',
          ),
        ),
      );
    }
  }

  Future<void> removeImage() async {
    if (_imageFile != null) {
      try {
        await _imageFile!.delete();
      } catch (error, stackTrace) {
        LoggingService.instance.warning(
          'Failed to delete temporary image file: $error',
        );
        LoggingService.instance.trace(
          'Temporary image cleanup stack trace: $stackTrace',
        );
      }
      _imageFile = null;
    }
    emit(state.copyWith(imagePath: null));
  }

  Future<StructureMaintenanceEvent?> submit() async {
    if (state.isSubmitting) {
      return null;
    }

    emit(state.copyWith(isSubmitting: true));

    try {
      final permitMetadata = _buildPermitMetadata();
      // Handle editing existing event
      if (state.isEditing && _existingEvent != null) {
        String? uploadedImageUrl;
        if (_imageFile != null) {
          if (_isOnline) {
            uploadedImageUrl = await _imageService.uploadImage(
              imageFile: _imageFile!,
              organizationId: _storageKey,
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
              organizationId: _storageKey,
            );
            uploadedImageUrl = queuedUpload?.storagePath;
          }
        }

        final removeExistingImage =
            state.imagePath == null &&
            _imageFile == null &&
            _existingEvent.imageUrl != null;

        final now = DateTime.now().toIso8601String();
        final updatedEvent = _existingEvent.copyWith(
          maintenanceTypeId: state.maintenanceTypeId,
          durationMinutes: state.duration.isNotEmpty
              ? int.parse(state.duration)
              : null,
          equipmentName: state.equipment.isNotEmpty
              ? state.equipment.trim()
              : null,
          resolved: state.resolved,
          comment: state.comment.isNotEmpty ? state.comment.trim() : null,
          imageUrl: removeExistingImage
              ? null
              : (uploadedImageUrl ?? _existingEvent.imageUrl),
          updatedAt: now,
          updatedById: _eventRepository.user.id,
          permitMetadata: permitMetadata,
        );

        await _eventRepository.collectionRef
            .doc(_existingEvent.id)
            .update(updatedEvent.toJson());

        _node.add(const GraphNodeReloadRequested());

        await _cleanupImageFile();

        emit(
          state.copyWith(
            isSubmitting: false,
            imagePath: null,
            notification: () => StructureMaintenanceEventNotification.success(
              'Structure maintenance updated successfully.',
            ),
          ),
        );

        return updatedEvent;
      }

      // Handle creating new event
      final eventId = generateId(firestore: _eventRepository.db);
      final eventSlug = await _eventRepository.nextSlugForModelType(
        _node.modelType,
      );

      String? uploadedImageUrl;
      if (_imageFile != null) {
        if (_isOnline) {
          uploadedImageUrl = await _imageService.uploadImage(
            imageFile: _imageFile!,
            organizationId: _storageKey,
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
            organizationId: _storageKey,
          );
          uploadedImageUrl = queuedUpload?.storagePath;
        }
      }

      final now = DateTime.now().toIso8601String();
      final event = StructureMaintenanceEvent(
        id: eventId,
        maintenanceTypeId: state.maintenanceTypeId,
        durationMinutes: state.duration.isNotEmpty
            ? int.parse(state.duration)
            : null,
        equipmentName: state.equipment.isNotEmpty
            ? state.equipment.trim()
            : null,
        resolved: state.resolved,
        comment: state.comment.isNotEmpty ? state.comment.trim() : null,
        imageUrl: uploadedImageUrl,
        base: EventBaseParams(
          permitMetadata: permitMetadata,
        ),
        createdById: _eventRepository.user.id,
        createdAt: now,
        updatedAt: now,
        updatedById: _eventRepository.user.id,
        organizationId: _eventRepository.organization.id,
        recordId: _node.id,
        recordModelType: _node.modelType,
        urlPath: '${_node.urlPath}/$eventSlug',
        internalPath: '${_node.internalPath}/$eventId',
        slug: eventSlug,
      );

      final enrichedEvent = _eventRepository.withOrganismMetadata(event);

      await _eventRepository.collectionRef
          .doc(eventId)
          .set(enrichedEvent.toJson());

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

      try {
        await propagationService.propagateToParents(
          sourceEvent: enrichedEvent,
          sourceNode: _node,
          activityType: 'structure_maintenance',
        );
        LoggingService.instance.info(
          'Structure maintenance event propagated to parent nodes: ${event.id}',
        );
      } catch (error, stackTrace) {
        LoggingService.instance.warning(
          'Failed to propagate structure maintenance event: $error',
        );
        LoggingService.instance.trace(
          'Structure maintenance propagation stack trace: $stackTrace',
        );
      }

      await _cleanupImageFile();
      _requestReload();

      emit(
        state.copyWith(
          isSubmitting: false,
          imagePath: null,
          notification: () => StructureMaintenanceEventNotification.success(
            'Structure maintenance recorded successfully.',
          ),
        ),
      );

      return enrichedEvent;
    } on FormatException catch (error, stackTrace) {
      LoggingService.instance.warning(
        'Invalid structure maintenance form input: $error',
      );
      LoggingService.instance.trace(
        'Structure maintenance form stack trace: $stackTrace',
      );
      emit(
        state.copyWith(
          isSubmitting: false,
          notification: () => StructureMaintenanceEventNotification.error(
            'Please verify numeric fields. ${error.message}',
          ),
        ),
      );
      return null;
    } catch (error, stackTrace) {
      LoggingService.instance.error(
        'Error recording structure maintenance',
        error,
        stackTrace,
      );
      emit(
        state.copyWith(
          isSubmitting: false,
          notification: () => StructureMaintenanceEventNotification.error(
            'Failed to record structure maintenance: $error',
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

  Future<void> _cleanupImageFile() async {
    if (_imageFile != null) {
      try {
        await _imageFile!.delete();
      } catch (error, stackTrace) {
        LoggingService.instance.warning(
          'Failed to delete temporary image file: $error',
        );
        LoggingService.instance.trace(
          'Temporary image cleanup stack trace: $stackTrace',
        );
      }
      _imageFile = null;
    }
  }

  void _requestReload() {
    if (!_node.isClosed) {
      _node.add(const GraphNodeReloadRequested());
    }
  }
}
