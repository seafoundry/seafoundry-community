// @tier: community
part of 'public_org_cubit.dart';

/// View modes for the public organization screen
enum PublicOrgViewMode {
  highlights,
  impactMap,
}

sealed class PublicOrgState extends Equatable {
  const PublicOrgState();

  @override
  List<Object?> get props => [];
}

final class PublicOrgInitial extends PublicOrgState {
  const PublicOrgInitial();
}

final class PublicOrgLoading extends PublicOrgState {
  const PublicOrgLoading();
}

final class PublicOrgLoaded extends PublicOrgState {
  const PublicOrgLoaded({
    required this.previewAccess,
    required this.activeView,
    required this.brandStream,
    required this.mediaStream,
    required this.impactStream,
  });

  final PreviewAccessDecision previewAccess;
  final PublicOrgViewMode activeView;
  final Stream<BrandProfile?> brandStream;
  final Stream<List<MediaAsset>> mediaStream;
  final Stream<List<PublicImpactPoint>> impactStream;

  bool get isPreviewPending => previewAccess.pending;
  bool get isPreviewBlocked => !previewAccess.pending && !previewAccess.allowed;
  bool get isPreviewAllowed => previewAccess.allowed;

  PublicOrgLoaded copyWith({
    PreviewAccessDecision? previewAccess,
    PublicOrgViewMode? activeView,
    Stream<BrandProfile?>? brandStream,
    Stream<List<MediaAsset>>? mediaStream,
    Stream<List<PublicImpactPoint>>? impactStream,
  }) {
    return PublicOrgLoaded(
      previewAccess: previewAccess ?? this.previewAccess,
      activeView: activeView ?? this.activeView,
      brandStream: brandStream ?? this.brandStream,
      mediaStream: mediaStream ?? this.mediaStream,
      impactStream: impactStream ?? this.impactStream,
    );
  }

  @override
  List<Object?> get props => [
        previewAccess,
        activeView,
        brandStream,
        mediaStream,
        impactStream,
      ];
}

final class PublicOrgError extends PublicOrgState {
  const PublicOrgError({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
