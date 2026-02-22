// @tier: community
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:seafoundry_app/models/public_read_models/media_asset.dart';
import 'package:seafoundry_app/services/feature_access_service.dart';
import 'package:seafoundry_app/services/public_read_models_service.dart';

/// Horizontal gallery of profile/tagged media that mirrors the public org strip.
class ProfileGalleryRail extends StatefulWidget {
  const ProfileGalleryRail({
    super.key,
    required this.orgId,
    this.maxItems = 6,
    this.readModelsService,
  });

  final String orgId;
  final int maxItems;
  final PublicReadModelsService? readModelsService;

  /// Filters the incoming media stream for profile/avatar tags and caps results.
  @visibleForTesting
  static List<MediaAsset> selectAvatars(List<MediaAsset> source, int maxItems) {
    if (source.isEmpty || maxItems <= 0) {
      return const [];
    }
    final tagged = source.where(_isProfileTagged).toList(growable: false);
    final candidates = tagged.isNotEmpty ? tagged : source;
    final limit = math.min(maxItems, candidates.length);
    return candidates.take(limit).toList(growable: false);
  }

  static bool _isProfileTagged(MediaAsset asset) {
    for (final tag in asset.tags) {
      final normalized = tag.toLowerCase();
      if (normalized == 'profile' || normalized == 'avatar') {
        return true;
      }
    }
    return false;
  }

  @override
  State<ProfileGalleryRail> createState() => _ProfileGalleryRailState();
}

class _ProfileGalleryRailState extends State<ProfileGalleryRail> {
  // Cache the service to prevent creating a new stream on every rebuild.
  // CRITICAL: Creating PublicReadModelsService in build() causes infinite
  // rebuilds on web because each new instance creates a new Firestore stream,
  // which emits initial data, triggering a rebuild, creating another stream...
  late final PublicReadModelsService _service;
  late final Stream<List<MediaAsset>> _mediaStream;

  @override
  void initState() {
    super.initState();
    _service = widget.readModelsService ?? PublicReadModelsService();
    _mediaStream = _service.streamPublicMedia(widget.orgId);
  }

  FeatureAccessService? _maybeReadFeatureAccess(BuildContext context) {
    try {
      return context.read<FeatureAccessService>();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = _maybeReadFeatureAccess(context);
    if (access == null || !access.supportsVisualEngagementPhaseD) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<List<MediaAsset>>(
      stream: _mediaStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final avatars = ProfileGalleryRail.selectAvatars(
          snapshot.data ?? const [],
          widget.maxItems,
        );
        if (avatars.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'Faces of this organization',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            SizedBox(
              height: 72,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  final asset = avatars[index];
                  return _AvatarChip(asset: asset);
                },
                separatorBuilder: (_, unused) => const SizedBox(width: 12),
                itemCount: avatars.length,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AvatarChip extends StatelessWidget {
  const _AvatarChip({required this.asset});

  final MediaAsset asset;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipOval(
          child: Image.network(
            asset.url,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
          ),
        ),
        if (asset.altText != null && asset.altText!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              asset.altText!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
      ],
    );
  }
}
