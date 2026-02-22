// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nested/nested.dart';
import 'package:seafoundry_app/blocs/auth/auth.dart';
import 'package:seafoundry_app/cubits/current_user/current_user.dart';
import 'package:seafoundry_app/cubits/navigation/navigation_cubit.dart';
import 'package:seafoundry_app/widgets/dialogs/base/dialog_base.dart';

import '../../../models/models.dart';
import '../../../theme/spacing.dart';
import '../../observation/observation_image_gallery.dart';
import '../components/safe_dialog.dart';
import '../../common/organism_reference_links.dart';

class OrganismObservationImagesDialog extends StatelessWidget {
  const OrganismObservationImagesDialog({
    super.key,
    required this.organism,
    required this.events,
    this.onGenetTap,
  });

  final OrganismRecord organism;
  final List<Event> events;
  final OrganismLinkTapHandler? onGenetTap;

  static Future<void> show(
    BuildContext context, {
    required OrganismRecord organism,
    required List<Event> events,
    OrganismLinkTapHandler? onGenetTap,
  }) {
    final providers = _captureDialogProviders(context);
    if (providers.isEmpty) {
      return context.showSafeDialog<void>(
        builder: (_) => OrganismObservationImagesDialog(
          organism: organism,
          events: events,
          onGenetTap: onGenetTap,
        ),
      );
    }
    return DialogBase.showDialogWithProviders<void>(
      context: context,
      providers: providers,
      dialog: OrganismObservationImagesDialog(
        organism: organism,
        events: events,
        onGenetTap: onGenetTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final images = collectObservationImages(
      events: events,
      organismId: organism.id,
    );

    return Dialog(
      insetPadding: const EdgeInsets.all(Spacing.md),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DialogHeader(
              title: 'Observation Images',
              subtitle: OrganismReferenceLinks(
                recordName: organism.recordName,
                localId: organism.localId,
                urlPath: organism.urlPath,
                genetId: organism.genetId,
                showUnderline: true,
                onGenetTap: onGenetTap,
              ),
              imageCount: images.length,
            ),
            const Divider(height: 1),
            Expanded(
              child: images.isEmpty
                  ? const _EmptyState()
                  : ObservationImageGallery(images: images),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({
    required this.title,
    required this.subtitle,
    required this.imageCount,
  });

  final String title;
  final Widget subtitle;
  final int imageCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.md,
        Spacing.md,
        Spacing.sm,
        Spacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: Spacing.xs),
                DefaultTextStyle(
                  style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ) ??
                      const TextStyle(),
                  child: subtitle,
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  imageCount == 1
                      ? '1 image'
                      : '$imageCount images',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              'No observation images yet.',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              'Images from observation events will appear here.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

List<SingleChildWidget> _captureDialogProviders(BuildContext context) {
  final providers = <SingleChildWidget>[];

  void addBloc<T extends BlocBase<dynamic>>() {
    try {
      final bloc = context.read<T>();
      providers.add(BlocProvider<T>.value(value: bloc));
    } on ProviderNotFoundException {
      // Dialog can still render without this provider.
    }
  }

  addBloc<AuthBloc>();
  addBloc<CurrentUser>();
  addBloc<NavigationCubit>();

  return providers;
}
