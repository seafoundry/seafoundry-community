// @tier: community
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:seafoundry_app/models/public_read_models/brand_profile.dart';
import 'package:seafoundry_app/providers/brand_theme_provider.dart';
import 'package:seafoundry_app/repositories/graph_repository.dart';
import 'package:seafoundry_app/services/public_read_models_service.dart';

/// Provides brand theming context for child widgets.
///
/// Previously wrapped children in a hero background image, now just provides
/// the [BrandThemeProvider] context for accent colors and branding.
class VisualIdentityHero extends StatefulWidget {
  const VisualIdentityHero({
    super.key,
    this.height = 120,
    this.child,
    this.fallbackAccentColor = const Color(0xFF00BCD4),
  });

  final double height;
  final Widget? child;
  final Color fallbackAccentColor;

  @override
  State<VisualIdentityHero> createState() => _VisualIdentityHeroState();
}

class _VisualIdentityHeroState extends State<VisualIdentityHero> {
  // Cache the service to prevent creating a new stream on every rebuild.
  // CRITICAL: Creating PublicReadModelsService in build() causes infinite
  // rebuilds on web because each new instance creates a new Firestore stream,
  // which emits initial data, triggering a rebuild, creating another stream...
  late final PublicReadModelsService _brandService;
  Stream<BrandProfile?>? _brandProfileStream;
  String? _orgId;

  static GraphRepository? _maybeGraphRepository(BuildContext context) {
    try {
      return context.read<GraphRepository>();
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _brandService = PublicReadModelsService();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final graphRepository = _maybeGraphRepository(context);
    if (graphRepository != null) {
      final newOrgId = graphRepository.organization.id;
      if (_orgId != newOrgId) {
        _orgId = newOrgId;
        _brandProfileStream = _brandService.streamBrandProfile(newOrgId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final heroChild = widget.child ?? const SizedBox.shrink();

    Widget buildContent(BrandProfile? profile) {
      final theme = profile != null
          ? BrandTheme.fromProfile(profile)
          : BrandTheme(accentColor: widget.fallbackAccentColor);
      return BrandThemeProvider(
        theme: theme,
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: heroChild,
        ),
      );
    }

    if (_brandProfileStream == null) {
      return buildContent(null);
    }

    return StreamBuilder<BrandProfile?>(
      stream: _brandProfileStream,
      builder: (_, snapshot) => buildContent(snapshot.data),
    );
  }
}
