// @tier: community
part of 'structure_maintenance_event_cubit.dart';

class StructureMaintenanceEventState extends Equatable {
  const StructureMaintenanceEventState({
    required this.maintenanceTypeId,
    this.duration = '',
    this.equipment = '',
    this.comment = '',
    this.permitId = '',
    this.permitType = '',
    this.issuingAuthority = '',
    this.permitAttachmentUrls = '',
    this.permitValidFrom,
    this.permitValidTo,
    this.resolved = true,
    this.isSubmitting = false,
    this.isCapturingImage = false,
    this.isEditing = false,
    this.imagePath,
    this.cameraStatus,
    this.notification,
  });

  final String maintenanceTypeId;
  final String duration;
  final String equipment;
  final String comment;
  final String permitId;
  final String permitType;
  final String issuingAuthority;
  final String permitAttachmentUrls;
  final DateTime? permitValidFrom;
  final DateTime? permitValidTo;
  final bool resolved;
  final bool isSubmitting;
  final bool isCapturingImage;
  final bool isEditing;
  final String? imagePath;
  final PermissionStatus? cameraStatus;
  final StructureMaintenanceEventNotification? notification;

  StructureMaintenanceEventState copyWith({
    String? maintenanceTypeId,
    String? duration,
    String? equipment,
    String? comment,
    String? permitId,
    String? permitType,
    String? issuingAuthority,
    String? permitAttachmentUrls,
    DateTime? permitValidFrom,
    DateTime? permitValidTo,
    bool? resolved,
    bool? isSubmitting,
    bool? isCapturingImage,
    bool? isEditing,
    String? imagePath,
    PermissionStatus? cameraStatus,
    StructureMaintenanceEventNotification? Function()? notification,
  }) {
    return StructureMaintenanceEventState(
      maintenanceTypeId: maintenanceTypeId ?? this.maintenanceTypeId,
      duration: duration ?? this.duration,
      equipment: equipment ?? this.equipment,
      comment: comment ?? this.comment,
      permitId: permitId ?? this.permitId,
      permitType: permitType ?? this.permitType,
      issuingAuthority: issuingAuthority ?? this.issuingAuthority,
      permitAttachmentUrls:
          permitAttachmentUrls ?? this.permitAttachmentUrls,
      permitValidFrom: permitValidFrom ?? this.permitValidFrom,
      permitValidTo: permitValidTo ?? this.permitValidTo,
      resolved: resolved ?? this.resolved,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isCapturingImage: isCapturingImage ?? this.isCapturingImage,
      isEditing: isEditing ?? this.isEditing,
      imagePath: imagePath ?? this.imagePath,
      cameraStatus: cameraStatus ?? this.cameraStatus,
      notification: notification != null ? notification() : this.notification,
    );
  }

  @override
  List<Object?> get props => [
    maintenanceTypeId,
    duration,
    equipment,
    comment,
    permitId,
    permitType,
    issuingAuthority,
    permitAttachmentUrls,
    permitValidFrom,
    permitValidTo,
    resolved,
    isSubmitting,
    isCapturingImage,
    isEditing,
    imagePath,
    cameraStatus,
    notification,
  ];
}

class StructureMaintenanceEventNotification extends Equatable {
  const StructureMaintenanceEventNotification._(this.message, this._kind);

  factory StructureMaintenanceEventNotification.success(String message) =>
      StructureMaintenanceEventNotification._(
        message,
        _NotificationKind.success,
      );

  factory StructureMaintenanceEventNotification.error(String message) =>
      StructureMaintenanceEventNotification._(message, _NotificationKind.error);

  factory StructureMaintenanceEventNotification.info(String message) =>
      StructureMaintenanceEventNotification._(message, _NotificationKind.info);

  final String message;
  final _NotificationKind _kind;

  bool get isError => _kind == _NotificationKind.error;
  bool get isSuccess => _kind == _NotificationKind.success;

  @override
  List<Object?> get props => [message, _kind];
}

enum _NotificationKind { success, error, info }
