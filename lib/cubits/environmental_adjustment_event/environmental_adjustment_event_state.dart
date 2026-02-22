// @tier: community
part of 'environmental_adjustment_event_cubit.dart';

const Object _unset = Object();

class EnvironmentalAdjustmentEventState extends Equatable {
  const EnvironmentalAdjustmentEventState({
    required this.adjustmentTypeId,
    this.previousValue = '',
    this.newValue = '',
    this.amount = '',
    this.unit = '',
    this.comment = '',
    this.permitId = '',
    this.permitType = '',
    this.issuingAuthority = '',
    this.permitAttachmentUrls = '',
    this.permitValidFrom,
    this.permitValidTo,
    this.isSubmitting = false,
    this.isCapturingImage = false,
    this.isEditing = false,
    this.imagePath,
    this.cameraStatus,
    this.notification,
  });

  final String adjustmentTypeId;
  final String previousValue;
  final String newValue;
  final String amount;
  final String unit;
  final String comment;
  final String permitId;
  final String permitType;
  final String issuingAuthority;
  final String permitAttachmentUrls;
  final DateTime? permitValidFrom;
  final DateTime? permitValidTo;
  final bool isSubmitting;
  final bool isCapturingImage;
  final bool isEditing;
  final String? imagePath;
  final PermissionStatus? cameraStatus;
  final EnvironmentalAdjustmentEventNotification? notification;

  EnvironmentalAdjustmentEventState copyWith({
    String? adjustmentTypeId,
    String? previousValue,
    String? newValue,
    String? amount,
    String? unit,
    String? comment,
    String? permitId,
    String? permitType,
    String? issuingAuthority,
    String? permitAttachmentUrls,
    DateTime? permitValidFrom,
    DateTime? permitValidTo,
    bool? isSubmitting,
    bool? isCapturingImage,
    bool? isEditing,
    Object? imagePath = _unset,
    Object? cameraStatus = _unset,
    EnvironmentalAdjustmentEventNotification? Function()? notification,
  }) {
    return EnvironmentalAdjustmentEventState(
      adjustmentTypeId: adjustmentTypeId ?? this.adjustmentTypeId,
      previousValue: previousValue ?? this.previousValue,
      newValue: newValue ?? this.newValue,
      amount: amount ?? this.amount,
      unit: unit ?? this.unit,
      comment: comment ?? this.comment,
      permitId: permitId ?? this.permitId,
      permitType: permitType ?? this.permitType,
      issuingAuthority: issuingAuthority ?? this.issuingAuthority,
      permitAttachmentUrls:
          permitAttachmentUrls ?? this.permitAttachmentUrls,
      permitValidFrom: permitValidFrom ?? this.permitValidFrom,
      permitValidTo: permitValidTo ?? this.permitValidTo,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isCapturingImage: isCapturingImage ?? this.isCapturingImage,
      isEditing: isEditing ?? this.isEditing,
      imagePath: identical(imagePath, _unset)
          ? this.imagePath
          : imagePath as String?,
      cameraStatus: identical(cameraStatus, _unset)
          ? this.cameraStatus
          : cameraStatus as PermissionStatus?,
      notification: notification != null ? notification() : this.notification,
    );
  }

  @override
  List<Object?> get props => [
    adjustmentTypeId,
    previousValue,
    newValue,
    amount,
    unit,
    comment,
    permitId,
    permitType,
    issuingAuthority,
    permitAttachmentUrls,
    permitValidFrom,
    permitValidTo,
    isSubmitting,
    isCapturingImage,
    isEditing,
    imagePath,
    cameraStatus,
    notification,
  ];
}

class EnvironmentalAdjustmentEventNotification extends Equatable {
  const EnvironmentalAdjustmentEventNotification._(this.message, this._kind);

  factory EnvironmentalAdjustmentEventNotification.success(String message) =>
      EnvironmentalAdjustmentEventNotification._(
        message,
        _NotificationKind.success,
      );

  factory EnvironmentalAdjustmentEventNotification.error(String message) =>
      EnvironmentalAdjustmentEventNotification._(
        message,
        _NotificationKind.error,
      );

  factory EnvironmentalAdjustmentEventNotification.info(String message) =>
      EnvironmentalAdjustmentEventNotification._(
        message,
        _NotificationKind.info,
      );

  final String message;
  final _NotificationKind _kind;

  bool get isError => _kind == _NotificationKind.error;
  bool get isSuccess => _kind == _NotificationKind.success;

  @override
  List<Object?> get props => [message, _kind];
}

enum _NotificationKind { success, error, info }
