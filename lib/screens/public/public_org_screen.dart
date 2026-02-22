// @tier: community
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seafoundry_app/cubits/public_org/public_org_cubit.dart';
import 'package:seafoundry_app/models/public_read_models/brand_profile.dart';
import 'package:seafoundry_app/models/public_read_models/media_asset.dart';
import 'package:seafoundry_app/navigation/public_route.dart';
import 'package:seafoundry_app/providers/brand_theme_provider.dart';
import 'package:seafoundry_app/screens/auth/auth_screen.dart';
import 'package:seafoundry_app/screens/public/kiosk_entry.dart';
import 'package:seafoundry_app/screens/public/public_holdings_map_screen.dart';
import 'package:seafoundry_app/services/public/public_preview_access_service.dart';
import 'package:seafoundry_app/services/public_read_models_service.dart';
import 'package:seafoundry_app/widgets/public/public_impact_map_section.dart';
import 'package:seafoundry_app/widgets/visual/brand_logo.dart';

class PublicOrganizationScreen extends StatelessWidget {
  const PublicOrganizationScreen({
    super.key,
    required this.orgId,
    this.initialView = PublicOrgView.highlights,
    this.kioskMode = false,
    this.previewMode = false,
    this.enableSampleImpactData = false,
    this.readModelsService,
  });

  final String orgId;
  final PublicOrgView initialView;
  final bool kioskMode;
  final bool previewMode;
  final bool enableSampleImpactData;
  final PublicReadModelsService? readModelsService;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PublicOrgCubit(
        orgId: orgId,
        previewMode: previewMode,
        readModelsService: readModelsService,
        initialView: _viewModeFromPublicOrgView(initialView),
      )..initialize(),
      child: _PublicOrganizationContent(
        orgId: orgId,
        kioskMode: kioskMode,
        previewMode: previewMode,
        enableSampleImpactData: enableSampleImpactData,
      ),
    );
  }

  static PublicOrgViewMode _viewModeFromPublicOrgView(PublicOrgView view) {
    switch (view) {
      case PublicOrgView.highlights:
        return PublicOrgViewMode.highlights;
      case PublicOrgView.impactMap:
        return PublicOrgViewMode.impactMap;
    }
  }
}

class _PublicOrganizationContent extends StatelessWidget {
  const _PublicOrganizationContent({
    required this.orgId,
    required this.kioskMode,
    required this.previewMode,
    required this.enableSampleImpactData,
  });

  final String orgId;
  final bool kioskMode;
  final bool previewMode;
  final bool enableSampleImpactData;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PublicOrgCubit, PublicOrgState>(
      builder: (context, state) {
        return switch (state) {
          PublicOrgInitial() || PublicOrgLoading() => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          PublicOrgError(:final message) => Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(message),
              ),
            ),
          ),
          PublicOrgLoaded() => _buildLoadedContent(context, state),
        };
      },
    );
  }

  Widget _buildLoadedContent(BuildContext context, PublicOrgLoaded state) {
    if (previewMode && state.isPreviewPending) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (previewMode && state.isPreviewBlocked) {
      return _PreviewDeniedView(reason: state.previewAccess.reason);
    }

    final previewEnabled = previewMode && state.isPreviewAllowed;

    return StreamBuilder<BrandProfile?>(
      stream: state.brandStream,
      builder: (context, snapshot) {
        final brand = snapshot.data;
        final theme = brand != null
            ? BrandTheme.fromProfile(brand)
            : const BrandTheme(accentColor: Color(0xFF00BCD4));
        return BrandThemeProvider(
          theme: theme,
          child: Scaffold(
            body: kioskMode
                ? _KioskBody(brand: brand, previewEnabled: previewEnabled)
                : _PublicBody(
                    orgId: orgId,
                    state: state,
                    brand: brand,
                    previewEnabled: previewEnabled,
                    enableSampleImpactData: enableSampleImpactData,
                  ),
          ),
        );
      },
    );
  }
}

class _PreviewDeniedView extends StatelessWidget {
  const _PreviewDeniedView({required this.reason});

  final PreviewAccessBlockReason? reason;

  @override
  Widget build(BuildContext context) {
    final message = reason == PreviewAccessBlockReason.unauthenticated
        ? 'Sign in as an organization admin to preview unpublished pages.'
        : 'Preview is limited to organization admins. Publish to share this page.';

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.https_outlined, size: 48),
              const SizedBox(height: 12),
              Text(
                'Preview unavailable',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KioskBody extends StatelessWidget {
  const _KioskBody({required this.brand, required this.previewEnabled});

  final BrandProfile? brand;
  final bool previewEnabled;

  @override
  Widget build(BuildContext context) {
    final kioskEnabled = brand?.kioskEnabled == true;
    if (!kioskEnabled && !previewEnabled) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            '${brand?.brandName ?? 'This organization'} has not enabled kiosk mode.',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return const BrandAwareKioskEntry();
  }
}

class _PublicBody extends StatelessWidget {
  const _PublicBody({
    required this.orgId,
    required this.state,
    required this.brand,
    required this.previewEnabled,
    required this.enableSampleImpactData,
  });

  final String orgId;
  final PublicOrgLoaded state;
  final BrandProfile? brand;
  final bool previewEnabled;
  final bool enableSampleImpactData;

  @override
  Widget build(BuildContext context) {
    if (brand != null && brand!.published != true && !previewEnabled) {
      return _UnpublishedMessage(brand: brand!);
    }

    final theme = BrandThemeProvider.of(context);
    final hasLogo = theme.logoUrl != null && theme.logoUrl!.isNotEmpty;
    final cubit = context.read<PublicOrgCubit>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: FilledButton.tonal(
                onPressed: () => _navigateToLogin(context),
                child: const Text('Sign In'),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              if (hasLogo) ...[
                const BrandLogo(height: 32),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  brand?.brandName ?? 'Organization',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            brand?.metadata?['tagline'] as String? ??
                'Explore the latest highlights and restoration impact.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: 8),
        _ViewSelector(
          activeView: state.activeView,
          onViewChanged: cubit.setActiveView,
        ),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PublicHoldingsMapScreen(
                      orgId: orgId,
                      previewMode: previewEnabled,
                      enableSampleImpactData: enableSampleImpactData,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.map_outlined),
              label: const Text('Open full map'),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: state.activeView == PublicOrgViewMode.highlights
                ? _HighlightsView(mediaStream: state.mediaStream)
                : PublicImpactMapSection(
                    key: ValueKey('impact-$orgId'),
                    orgId: orgId,
                    stream: state.impactStream,
                    previewMode: previewEnabled,
                    enableSampleData: enableSampleImpactData,
                  ),
          ),
        ),
      ],
    );
  }

  void _navigateToLogin(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AuthScreen(showBackButton: true),
      ),
    );
  }
}

class _ViewSelector extends StatelessWidget {
  const _ViewSelector({required this.activeView, required this.onViewChanged});

  final PublicOrgViewMode activeView;
  final ValueChanged<PublicOrgViewMode> onViewChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SegmentedButton<PublicOrgViewMode>(
        segments: const [
          ButtonSegment(
            value: PublicOrgViewMode.highlights,
            label: Text('Highlights'),
            icon: Icon(Icons.collections),
          ),
          ButtonSegment(
            value: PublicOrgViewMode.impactMap,
            label: Text('Impact Map'),
            icon: Icon(Icons.travel_explore),
          ),
        ],
        selected: {activeView},
        onSelectionChanged: (selection) {
          if (selection.isNotEmpty) {
            onViewChanged(selection.first);
          }
        },
      ),
    );
  }
}

class _HighlightsView extends StatelessWidget {
  const _HighlightsView({required this.mediaStream});

  final Stream<List<MediaAsset>> mediaStream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MediaAsset>>(
      stream: mediaStream,
      initialData: const [],
      builder: (context, snapshot) {
        final items = snapshot.data ?? const [];
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (items.isEmpty) {
          return const Center(child: Text('No public media yet.'));
        }
        final avatarSources = _profileCandidates(items);
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            if (avatarSources.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _ProfileGallery(avatars: avatarSources),
              ),
            _MediaGrid(items: items),
          ],
        );
      },
    );
  }

  List<MediaAsset> _profileCandidates(List<MediaAsset> items) {
    final tagged = items
        .where(
          (asset) => asset.tags.any((tag) {
            final normalized = tag.toLowerCase();
            return normalized == 'profile' || normalized == 'avatar';
          }),
        )
        .toList();
    final source = tagged.isNotEmpty ? tagged : items;
    return source.take(6).toList();
  }
}

class _ProfileGallery extends StatelessWidget {
  const _ProfileGallery({required this.avatars});

  final List<MediaAsset> avatars;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: avatars.length,
        separatorBuilder: (_, unused) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final asset = avatars[index];
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipOval(
                child: Image.network(
                  asset.url,
                  width: 72,
                  height: 72,
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
        },
      ),
    );
  }
}

class _MediaGrid extends StatelessWidget {
  const _MediaGrid({required this.items});

  final List<MediaAsset> items;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final asset = items[index];
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(asset.url, fit: BoxFit.cover),
              if (asset.altText != null && asset.altText!.isNotEmpty)
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Container(
                    color: Colors.black54,
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      asset.altText!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _UnpublishedMessage extends StatelessWidget {
  const _UnpublishedMessage({required this.brand});

  final BrandProfile brand;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.visibility_off_outlined, size: 48),
            const SizedBox(height: 16),
            Text(
              '${brand.brandName} is preparing this public page.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Check back soon or request a preview link from the team.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
