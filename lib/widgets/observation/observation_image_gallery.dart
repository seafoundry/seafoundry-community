// @tier: community
import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../models/monitoring/image_attachment.dart';
import '../../theme/spacing.dart';
import '../optimized/optimized_network_image.dart';

class ObservationImageGallery extends StatelessWidget {
  const ObservationImageGallery({super.key, required this.images});

  final List<ObservationImageItem> images;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 900
            ? 4
            : width >= 640
                ? 3
                : 2;
        return GridView.builder(
          padding: const EdgeInsets.all(Spacing.md),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: Spacing.sm,
            mainAxisSpacing: Spacing.sm,
          ),
          itemCount: images.length,
          itemBuilder: (context, index) {
            return _ImageTile(item: images[index]);
          },
        );
      },
    );
  }
}

class ObservationImageItem {
  const ObservationImageItem({
    required this.imageUrl,
    required this.isOrthomosaic,
  });

  final String imageUrl;
  final bool isOrthomosaic;
}

List<ObservationImageItem> collectObservationImages({
  required List<Event> events,
  required String organismId,
}) {
  if (events.isEmpty) return const <ObservationImageItem>[];

  final sorted = List<Event>.from(events)
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final seen = <String>{};
  final items = <ObservationImageItem>[];

  void addImage(String imageUrl, {bool isOrthomosaic = false}) {
    if (imageUrl.isEmpty) return;
    if (!seen.add(imageUrl)) return;
    items.add(
      ObservationImageItem(
        imageUrl: imageUrl,
        isOrthomosaic: isOrthomosaic,
      ),
    );
  }

  for (final event in sorted) {
    if (!_isObservationEvent(event)) {
      continue;
    }

    if (event is MonitoringEventRecord) {
      for (final attachment in event.imageAttachments) {
        if (_isAttachmentForOrganism(attachment, organismId)) {
          addImage(
            attachment.imageUrl,
            isOrthomosaic: attachment.isOrthomosaic,
          );
        }
      }
      if (event.imageUrl != null && event.imageUrl!.isNotEmpty) {
        addImage(event.imageUrl!);
      }
      continue;
    }

    if (event is ObservationEvent) {
      if (event.imageUrl != null && event.imageUrl!.isNotEmpty) {
        addImage(event.imageUrl!);
      }
    }
  }

  return items;
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({required this.item});

  final ObservationImageItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overlayColor = theme.colorScheme.surface.withValues(alpha: 0.72);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          OptimizedNetworkImage(
            imageUrl: item.imageUrl,
            fit: BoxFit.cover,
          ),
          if (item.isOrthomosaic)
            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: overlayColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Orthomosaic',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

bool _isObservationEvent(Event event) {
  if (event is ObservationEvent) return true;
  if (event is MonitoringEventRecord) return true;
  return event.eventTypeId.contains('observation');
}

bool _isAttachmentForOrganism(ImageAttachment attachment, String organismId) {
  if (attachment.imageUrl.isEmpty) return false;
  if (attachment.organismIds.isEmpty) return true;
  return attachment.organismIds.contains(organismId);
}
